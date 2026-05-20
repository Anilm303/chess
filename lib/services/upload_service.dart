import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

/// Web/mobile compatible chunked uploader that works with `XFile` and raw
/// bytes. Returns a backend-served path on success (e.g. '/uploads/files/<id>').
class UploadService {
  /// Uploads [media] (XFile) using chunked upload endpoints.
  Future<String?> uploadFile(
    XFile media,
    String accessToken, {
    void Function(double progress)? onProgress,
  }) async {
    final bytes = await media.readAsBytes();
    final fileSize = bytes.length;
    final md5Hash = md5.convert(bytes).toString();

    // Start session
    final startUrl = '${ApiService.baseUrl}/upload/start';
    final startResp = await http
        .post(
          Uri.parse(startUrl),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'filename': media.name,
            'file_size': fileSize,
            'md5_hash': md5Hash,
          }),
        )
        .timeout(ApiService.timeout);

    if (startResp.statusCode != 200) return null;
    final startJson = jsonDecode(startResp.body) as Map<String, dynamic>;
    final sessionId = startJson['session_id'] as String?;
    final chunkSize = (startJson['chunk_size'] as int?) ?? (1024 * 1024);
    final totalChunks =
        (startJson['total_chunks'] as int?) ??
        ((fileSize + chunkSize - 1) ~/ chunkSize);
    if (sessionId == null) return null;

    final received = (startJson['chunks_received'] as int?) ?? 0;
    for (int chunkNum = received; chunkNum < totalChunks; chunkNum++) {
      final start = chunkNum * chunkSize;
      final end = ((chunkNum + 1) * chunkSize).clamp(0, fileSize);
      final chunkBytes = bytes.sublist(start, end);

      final chunkUrl = '${ApiService.baseUrl}/upload/chunk';
      final request = http.MultipartRequest('POST', Uri.parse(chunkUrl));
      request.headers['Authorization'] = 'Bearer $accessToken';
      request.fields['session_id'] = sessionId;
      request.fields['chunk_num'] = chunkNum.toString();
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          chunkBytes,
          filename: '${media.name}.part',
        ),
      );

      final streamed = await request.send().timeout(ApiService.timeout);
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode != 200) {
        if (kDebugMode)
          print('Chunk upload failed: ${resp.statusCode} ${resp.body}');
        return null;
      }

      if (onProgress != null) {
        onProgress((chunkNum + 1) / totalChunks);
      }
    }

    // Complete
    final completeUrl = '${ApiService.baseUrl}/upload/complete';
    final completeResp = await http
        .post(
          Uri.parse(completeUrl),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'session_id': sessionId, 'md5_hash': md5Hash}),
        )
        .timeout(ApiService.timeout);

    if (completeResp.statusCode != 200) {
      if (kDebugMode)
        print(
          'Complete failed: ${completeResp.statusCode} ${completeResp.body}',
        );
      return null;
    }
    final completeJson = jsonDecode(completeResp.body) as Map<String, dynamic>;
    final fileId = completeJson['file_id'] as String?;
    if (fileId == null) return null;

    return '/uploads/files/$fileId';
  }
}
