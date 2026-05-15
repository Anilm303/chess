import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/backend_config.dart';
import '../models/user_model.dart';

class ApiService {
  /// Base URL for the API.
  static String get baseUrl {
    return BackendConfig.apiBaseUrl;
  }

  /// Base URL for Socket.IO (strips the /api suffix).
  static String get socketBaseUrl => BackendConfig.socketBaseUrl;

  static const Duration timeout = Duration(seconds: 10);

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static Map<String, dynamic>? _decodeJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      return null;
    }
    return null;
  }

  static String _responseMessage(
    http.Response response, {
    String fallback = 'Request failed',
  }) {
    final decoded = _decodeJsonMap(response.body);
    final message = decoded?['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    final body = response.body.trim();
    if (body.isEmpty) return fallback;

    final snippet = body.replaceAll(RegExp(r'\s+'), ' ');
    if (snippet.length <= 180) return snippet;
    return '${snippet.substring(0, 180)}...';
  }

  static Future<void> initialize() async {
    await BackendConfig.initialize();
    BackendConfig.logResolution();
  }

  static Future<http.Response> _post(
    String path,
    Map<String, String> headers,
    Object? body,
  ) async {
    if (baseUrl.isEmpty) {
      throw StateError(
        'Backend URL is not configured. Open the backend URL setup prompt and save your API base URL.',
      );
    }
    final url = '$baseUrl$path';
    try {
      if (kDebugMode) print('📤 POST $url');
      return await http
          .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(timeout);
    } catch (e) {
      if (kDebugMode) print('❌ POST $url failed: $e');
      rethrow;
    }
  }

  static Future<http.Response> _get(
    String path,
    Map<String, String> headers,
  ) async {
    if (baseUrl.isEmpty) {
      throw StateError(
        'Backend URL is not configured. Open the backend URL setup prompt and save your API base URL.',
      );
    }
    final url = '$baseUrl$path';
    try {
      if (kDebugMode) print('📥 GET $url');
      return await http.get(Uri.parse(url), headers: headers).timeout(timeout);
    } catch (e) {
      if (kDebugMode) print('❌ GET $url failed: $e');
      rethrow;
    }
  }

  // Legacy helper for manual testing if needed
  static Future<bool> testBaseUrl(String url) async {
    final normalized = _normalizeBaseUrl(url);
    try {
      final response = await http
          .get(Uri.parse('$normalized/ping'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<AuthResponse> register({
    required String username,
    required String email,
    required String firstName,
    required String lastName,
    required String password,
  }) async {
    try {
      final body = {
        'username': username,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'password': password,
      };
      if (kDebugMode) print('📤 Body: $body');

      final response = await _post('/auth/register', {
        'Content-Type': 'application/json',
      }, body);

      if (kDebugMode) {
        print('📥 Response Status: ${response.statusCode}');
        print('📥 Response Body: ${response.body}');
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        final json = _decodeJsonMap(response.body);
        if (json != null) {
          return AuthResponse.fromJson(json);
        }
        return AuthResponse(
          success: false,
          message: 'Backend returned an unexpected response while registering.',
        );
      } else {
        return AuthResponse(
          success: false,
          message: _responseMessage(response, fallback: 'Registration failed'),
        );
      }
    } on TimeoutException {
      final msg =
          'Connection timed out. Pass BACKEND_BASE_URL or API_BASE_URL via --dart-define.';
      if (kDebugMode) print(msg);
      return AuthResponse(success: false, message: msg);
    } on http.ClientException catch (e) {
      final msg =
          'Network error: ${e.message}. Ensure your backend is running at $baseUrl';
      if (kDebugMode) print(msg);
      return AuthResponse(success: false, message: msg);
    } on StateError catch (e) {
      return AuthResponse(success: false, message: e.message);
    } catch (e) {
      if (kDebugMode) print('❌ Register error: $e');
      return AuthResponse(success: false, message: 'Error: $e');
    }
  }

  static Future<AuthResponse> login({
    required String username,
    required String password,
  }) async {
    try {
      final body = {'username': username, 'password': password};
      if (kDebugMode) print('📤 Body: $body');

      final response = await _post('/auth/login', {
        'Content-Type': 'application/json',
      }, body);

      if (kDebugMode) {
        print('📥 Response Status: ${response.statusCode}');
        print('📥 Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final json = _decodeJsonMap(response.body);
        if (json != null) {
          return AuthResponse.fromJson(json);
        }
        return AuthResponse(
          success: false,
          message: 'Backend returned an unexpected response while logging in.',
        );
      } else {
        return AuthResponse(
          success: false,
          message: _responseMessage(response, fallback: 'Login failed'),
        );
      }
    } on TimeoutException {
      final msg = 'Login timed out. Check server status at $baseUrl';
      if (kDebugMode) print(msg);
      return AuthResponse(success: false, message: msg);
    } on http.ClientException catch (e) {
      final msg = 'Network error during login: ${e.message}';
      if (kDebugMode) print(msg);
      return AuthResponse(success: false, message: msg);
    } on StateError catch (e) {
      return AuthResponse(success: false, message: e.message);
    } catch (e) {
      if (kDebugMode) print('❌ Login error: $e');
      return AuthResponse(success: false, message: 'Error: $e');
    }
  }

  static Future<AuthResponse> validateToken(String token) async {
    try {
      if (kDebugMode) print('📡 Validate Token (trying candidates)');
      final response = await _get('/auth/validate-token', {
        'Authorization': 'Bearer $token',
      });

      if (kDebugMode) {
        print('📥 Response Status: ${response.statusCode}');
        print('📥 Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final json = _decodeJsonMap(response.body);
        if (json != null) {
          return AuthResponse.fromJson(json);
        }
        return AuthResponse(
          success: false,
          message:
              'Backend returned an unexpected response while validating the token.',
        );
      } else {
        return AuthResponse(success: false, message: 'Token validation failed');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Token validation error: $e');
      return AuthResponse(success: false, message: 'Token validation failed');
    }
  }

  static Future<AuthResponse> refreshAccessToken(String refreshToken) async {
    try {
      if (kDebugMode) print('♻️ Refreshing access token');
      final response = await _post('/auth/refresh', {
        'Authorization': 'Bearer $refreshToken',
        'Content-Type': 'application/json',
      }, null);

      if (kDebugMode) {
        print('📥 Refresh Status: ${response.statusCode}');
        print('📥 Refresh Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final json = _decodeJsonMap(response.body);
        if (json != null) {
          return AuthResponse.fromJson(json);
        }
        return AuthResponse(
          success: false,
          message:
              'Backend returned an unexpected response while refreshing the token.',
        );
      }

      return AuthResponse(success: false, message: 'Token refresh failed');
    } catch (e) {
      if (kDebugMode) print('❌ Refresh token error: $e');
      return AuthResponse(success: false, message: 'Token refresh failed');
    }
  }

  // Logout: POST /auth/logout (requires Bearer token)
  static Future<void> logout(String token, {String? refreshToken}) async {
    if (kDebugMode) print('📡 Logout Request (trying candidates)');
    try {
      final response = await _post(
        '/auth/logout',
        {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        {if (refreshToken != null) 'refresh_token': refreshToken},
      );

      if (kDebugMode) {
        print('📥 Response Status: ${response.statusCode}');
        print('📥 Response Body: ${response.body}');
      }

      if (response.statusCode != 200) {
        throw Exception('Logout failed: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Logout error: $e');
      rethrow;
    }
  }

  // Update FCM Token: POST /auth/update-fcm-token
  static Future<void> updateFcmToken(
    String fcmToken,
    String accessToken,
  ) async {
    try {
      await _post(
        '/auth/update-fcm-token',
        {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        {'fcm_token': fcmToken},
      );
    } catch (e) {
      if (kDebugMode) print('❌ Update FCM Token error: $e');
      rethrow;
    }
  }
}
