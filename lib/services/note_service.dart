import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/note_model.dart';
import 'api_service.dart';

class NoteService extends ChangeNotifier {
  List<NoteGroup> _notes = [];
  bool _isLoading = false;
  String? _error;

  List<NoteGroup> get notes => _notes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _log(String message) {
    debugPrint('📝 NoteService: $message');
  }

  void _logResponse(String action, http.Response response) {
    final body = response.body;
    final preview = body.length > 300 ? '${body.substring(0, 300)}...' : body;
    debugPrint('📝 NoteService: $action -> ${response.statusCode}');
    debugPrint('📝 NoteService: $action body: $preview');
  }

  Future<bool> fetchNotes(String accessToken) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final url = Uri.parse('${ApiService.baseUrl}/notes/active');
      _log('GET $url');
      final response = await http
          .get(url, headers: {'Authorization': 'Bearer $accessToken'})
          .timeout(ApiService.timeout);
      _logResponse('GET /notes/active', response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _notes = (data['notes'] as List? ?? [])
              .map((n) => NoteGroup.fromJson(n as Map<String, dynamic>))
              .toList();
          notifyListeners();
          return true;
        }
      }

      _error = 'Failed to fetch notes';
      _log(_error!);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error fetching notes: $e';
      _log(_error!);
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> uploadNote({
    required String accessToken,
    String noteType = 'text',
    String textContent = '',
    String? mediaBase64,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final url = Uri.parse('${ApiService.baseUrl}/notes/upload');
      _log('POST $url noteType=$noteType');
      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'note_type': noteType,
              'text_content': textContent,
              if (mediaBase64 != null) 'media_base64': mediaBase64,
            }),
          )
          .timeout(const Duration(seconds: 60));
      _logResponse('POST /notes/upload', response);

      if (response.statusCode == 201) {
        await fetchNotes(accessToken);
        return true;
      }

      _error = 'Failed to upload note';
      _log(_error!);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error uploading note: $e';
      _log(_error!);
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> markNoteViewed(String noteId, String accessToken) async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/notes/$noteId/view');
      _log('POST $url');
      final response = await http
          .post(url, headers: {'Authorization': 'Bearer $accessToken'})
          .timeout(ApiService.timeout);
      _logResponse('POST /notes/$noteId/view', response);

      return response.statusCode == 200;
    } catch (e) {
      _log('Error marking note viewed: $e');
      return false;
    }
  }

  static Future<String?> fileToBase64(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      return null;
    }
  }
}
