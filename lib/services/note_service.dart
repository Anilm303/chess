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

  Future<bool> fetchNotes(String accessToken) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http
          .get(
            Uri.parse('${ApiService.baseUrl}/notes/active'),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(ApiService.timeout);

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
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error fetching notes: $e';
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
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/notes/upload'),
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

      if (response.statusCode == 201) {
        await fetchNotes(accessToken);
        return true;
      }

      _error = 'Failed to upload note';
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error uploading note: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> markNoteViewed(String noteId, String accessToken) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/notes/$noteId/view'),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(ApiService.timeout);

      return response.statusCode == 200;
    } catch (e) {
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
