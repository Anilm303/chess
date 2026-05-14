import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  /// Base URL for the API, fetched from the .env file.
  static String get baseUrl {
    final url = dotenv.env['API_BASE_URL'] ?? '';
    if (url.isEmpty) {
      if (kDebugMode) {
        print('⚠️ API_BASE_URL is not set in .env! Falling back to localhost.');
      }
      return 'http://127.0.0.1:8000/api';
    }
    return _normalizeBaseUrl(url);
  }

  /// Base URL for Socket.IO (strips the /api suffix).
  static String get socketBaseUrl => _stripApiSuffix(baseUrl);

  static const Duration timeout = Duration(seconds: 10);

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static String _stripApiSuffix(String url) {
    final normalized = _normalizeBaseUrl(url);
    if (normalized.endsWith('/api')) {
      return normalized.substring(0, normalized.length - 4);
    }
    return normalized;
  }

  static Future<void> initialize() async {
    // No longer needs complex probing. Initialized via dotenv in main.dart.
    if (kDebugMode) {
      print('🌐 ApiService initialized with baseUrl: $baseUrl');
    }
  }

  static Future<http.Response> _post(
    String path,
    Map<String, String> headers,
    Object? body,
  ) async {
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
        return AuthResponse.fromJson(jsonDecode(response.body));
      } else {
        final json = jsonDecode(response.body);
        return AuthResponse(
          success: false,
          message: json['message'] ?? 'Registration failed',
        );
      }
    } on TimeoutException catch (e) {
      final msg = 'Connection timed out. Please check your internet and BASE_URL in .env';
      if (kDebugMode) print(msg);
      return AuthResponse(success: false, message: msg);
    } on http.ClientException catch (e) {
      final msg = 'Network error: ${e.message}. Ensure your backend is running at $baseUrl';
      if (kDebugMode) print(msg);
      return AuthResponse(success: false, message: msg);
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
        return AuthResponse.fromJson(jsonDecode(response.body));
      } else {
        final json = jsonDecode(response.body);
        return AuthResponse(
          success: false,
          message: json['message'] ?? 'Login failed',
        );
      }
    } on TimeoutException catch (e) {
      final msg = 'Login timed out. Check server status at $baseUrl';
      if (kDebugMode) print(msg);
      return AuthResponse(success: false, message: msg);
    } on http.ClientException catch (e) {
      final msg = 'Network error during login: ${e.message}';
      if (kDebugMode) print(msg);
      return AuthResponse(success: false, message: msg);
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
        return AuthResponse.fromJson(jsonDecode(response.body));
      } else {
        return AuthResponse(success: false, message: 'Token validation failed');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Token validation error: $e');
      return AuthResponse(success: false, message: 'Token validation failed');
    }
  }

  // Logout: POST /auth/logout (requires Bearer token)
  static Future<void> logout(String token) async {
    if (kDebugMode) print('📡 Logout Request (trying candidates)');
    try {
      final response = await _post('/auth/logout', {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      }, null);

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
