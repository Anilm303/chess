import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../models/story_model.dart';
import 'api_service.dart';

class StoryService extends ChangeNotifier {
  List<StoryGroup> _stories = [];
  bool _isLoading = false;
  String? _error;

  List<StoryGroup> get stories => _stories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _log(String message) {
    debugPrint('📖 StoryService: $message');
  }

  void _logResponse(String action, http.Response response) {
    final body = response.body;
    final preview = body.length > 300 ? '${body.substring(0, 300)}...' : body;
    debugPrint('📖 StoryService: $action -> ${response.statusCode}');
    debugPrint('📖 StoryService: $action body: $preview');
  }

  /// Fetch all active stories
  Future<bool> fetchStories(String accessToken) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final url = Uri.parse('${ApiService.baseUrl}/stories/active');
      _log('GET $url');
      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));
      _logResponse('GET /stories/active', response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final storiesList =
              (data['stories'] as List?)
                  ?.map((s) => StoryGroup.fromJson(s as Map<String, dynamic>))
                  .toList() ??
              [];
          _stories = storiesList;
          _error = null;
          notifyListeners();
          return true;
        }
      }

      _error = 'Failed to fetch stories';
      _log(_error!);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error: $e';
      _log(_error!);
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Upload a new story
  Future<bool> uploadStory(
    String mediaBase64,
    String mediaType,
    String accessToken,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final url = Uri.parse('${ApiService.baseUrl}/stories/upload');
      _log('POST $url mediaType=$mediaType');
      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'media_base64': mediaBase64,
              'media_type': mediaType,
            }),
          )
          .timeout(const Duration(seconds: 60));
      _logResponse('POST /stories/upload', response);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _error = null;
          // Refresh stories after uploading
          await fetchStories(accessToken);
          notifyListeners();
          return true;
        }
      }

      _error = 'Failed to upload story';
      _log(_error!);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error: $e';
      _log(_error!);
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Upload a file via multipart/form-data (preferred for large videos)
  Future<bool> uploadStoryFile(
    XFile file,
    String mediaType,
    String accessToken,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/stories/upload');
      _log('POST $uri mediaType=$mediaType file=${file.name}');
      _log('File size: ${await file.length()} bytes');

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $accessToken';
      request.fields['media_type'] = mediaType;

      final bytes = await file.readAsBytes();
      _log('File read: ${bytes.length} bytes');

      final multipartFile = http.MultipartFile.fromBytes(
        'media',
        bytes,
        filename: file.name,
      );
      request.files.add(multipartFile);

      _log('Sending multipart request...');
      final streamed = await request.send().timeout(
        const Duration(seconds: 120),
      );
      final response = await http.Response.fromStream(streamed);

      _logResponse('MULTIPART POST /stories/upload', response);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _log('Story uploaded successfully');
          _error = null;
          await fetchStories(accessToken);
          notifyListeners();
          return true;
        } else {
          _error = data['message'] ?? 'Upload failed';
          _log('Server error: $_error');
        }
      } else {
        try {
          final data = jsonDecode(response.body);
          _error =
              data['message'] ??
              'Failed to upload story (${response.statusCode})';
        } catch (_) {
          if (response.statusCode == 413) {
            _error = 'File too large. Max video size is typically 100MB';
          } else if (response.statusCode == 401) {
            _error = 'Authentication failed. Please login again';
          } else {
            _error =
                'Server error (${response.statusCode}). ${response.body.length > 100 ? response.body.substring(0, 100) + '...' : response.body}';
          }
        }
        _log('Upload error: $_error');
      }
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Network error: $e';
      _log('Exception: $e');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark story as viewed
  Future<bool> markStoryViewed(String storyId, String accessToken) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/stories/$storyId/view'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Toggle an emoji reaction on a story
  Future<bool> reactToStory(
    String storyId,
    String emoji,
    String accessToken,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/stories/$storyId/react'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'emoji': emoji}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Optimistically update the UI by fetching stories again
        fetchStories(accessToken);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Fetch story analytics (views + reactions)
  Future<Map<String, dynamic>?> fetchStoryAnalytics(
    String storyId,
    String accessToken,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiService.baseUrl}/stories/$storyId/analytics'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Pick media from gallery
  Future<XFile?> pickMedia(String type) async {
    try {
      final picker = ImagePicker();
      if (type == 'image') {
        return await picker.pickImage(source: ImageSource.gallery);
      } else if (type == 'video') {
        return await picker.pickVideo(source: ImageSource.gallery);
      }
      return null;
    } catch (e) {
      _error = 'Failed to pick media: $e';
      notifyListeners();
      return null;
    }
  }

  /// Convert file to base64
  static Future<String?> fileToBase64(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
