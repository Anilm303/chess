import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class ApiService {
  static const String _prefsKeyBaseUrlOverride = 'api_base_url_override';

  // Override this when building for a physical device, for example:
  // flutter run --dart-define=API_BASE_URL=http://192.168.1.100:5000/api
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String? _runtimeBaseUrlOverride;
  static String? _cachedSuccessfulBaseUrl;

  // Default to local backend for development
  // For Real Device on WiFi: 192.168.1.3:7860 (primary)
  // For Android Emulator: 10.0.2.2:7860 (fallback)
  static const String _defaultPhysicalDeviceBaseUrl =
      'http://192.168.1.3:7860/api'; // Real device on local WiFi

  static String _webDefaultBaseUrl() {
    final host = Uri.base.host.trim();
    if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
      return 'http://$host:7860/api';
    }
    return 'http://localhost:7860/api';
  }

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = _normalizeBaseUrl(
      prefs.getString(_prefsKeyBaseUrlOverride) ?? '',
    );
    _runtimeBaseUrlOverride = stored.isEmpty ? null : stored;
  }

  static Future<void> setBaseUrlOverride(String? url) async {
    final normalized = _normalizeBaseUrl(url ?? '');
    _runtimeBaseUrlOverride = normalized.isEmpty ? null : normalized;

    final prefs = await SharedPreferences.getInstance();
    if (_runtimeBaseUrlOverride == null) {
      await prefs.remove(_prefsKeyBaseUrlOverride);
    } else {
      await prefs.setString(_prefsKeyBaseUrlOverride, _runtimeBaseUrlOverride!);
    }
  }

  static String get baseUrl {
    if (_cachedSuccessfulBaseUrl != null) {
      return _cachedSuccessfulBaseUrl!;
    }

    if (_runtimeBaseUrlOverride != null) {
      return _runtimeBaseUrlOverride!;
    }

    final configured = _normalizeBaseUrl(_configuredBaseUrl);
    if (configured.isNotEmpty) {
      return configured;
    }

    if (kIsWeb) {
      // Prefer a configured or saved backend, otherwise fall back to the deployed API.
      return _webDefaultBaseUrl();
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _defaultPhysicalDeviceBaseUrl;
      default:
        return _defaultPhysicalDeviceBaseUrl;
    }
  }

  static const Duration timeout = Duration(seconds: 10);

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  // Candidate base URLs we try in order. This helps physical devices and
  // emulator setups work without manually editing the code every time.
  static List<String> _candidateBaseUrls() {
    final candidates = <String>[
      ...(_runtimeBaseUrlOverride == null
          ? const <String>[]
          : <String>[_runtimeBaseUrlOverride!]),
      _configuredBaseUrl,
      if (kIsWeb) ...[
        _webDefaultBaseUrl(),
        'http://localhost:7860/api',
        'http://127.0.0.1:7860/api',
      ] else ...[
        // Try WiFi IP first (for real devices)
        'http://192.168.1.3:7860/api',
        // Then try emulator IP (for Android emulator)
        'http://10.0.2.2:7860/api',
      ],
    ];

    final normalized = <String>[];
    for (final candidate in candidates) {
      final value = _normalizeBaseUrl(candidate);
      if (value.isNotEmpty && !normalized.contains(value)) {
        normalized.add(value);
      }
    }
    _cachedSuccessfulBaseUrl = null;
    return normalized;
  }

  static String _candidateUrlsMessage() {
    final urls = _candidateBaseUrls();
    if (urls.isEmpty) {
      return '- none';
    }

    return urls.map((url) => '- $url').join('\n');
  }

  static String _networkErrorMessage(String action, Object error) {
    final details = error is TimeoutException
        ? 'Request timed out'
        : error is http.ClientException
        ? error.message
        : error.toString();

    return '❌ $action Network Error: $details\n'
        'URL: $baseUrl\n'
        'Tried:\n${_candidateUrlsMessage()}\n'
        'Make sure:\n'
        '1. Backend is running and reachable from the phone\n'
        '2. The Android device is on the same WiFi as the backend\n'
        '3. API_BASE_URL points to the correct machine IP or use the in-app backend URL setting\n'
        '4. If the phone is USB-connected, run: adb reverse tcp:5000 tcp:5000 and use http://127.0.0.1:5000/api';
  }

  static Future<http.Response> _tryPost(
    String path,
    Map<String, String> headers,
    Object? body,
  ) async {
    List<String> triedUrls = [];
    Exception? lastError;

    final candidates = _candidateBaseUrls();
    for (final base in candidates) {
      final url = '$base$path';
      triedUrls.add(url);
      if (kDebugMode) print('Trying POST $url');
      try {
        final response = await http
            .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
            .timeout(timeout);

        // If we got here, it's a success or a server error (which is still a response)
        if (kDebugMode) {
          print('✅ POST $url succeeded with status ${response.statusCode}');
        }
        _cachedSuccessfulBaseUrl = base;
        return response;
      } on TimeoutException catch (e) {
        lastError = e;
        if (kDebugMode) {
          print('⏳ POST $url timed out after ${timeout.inSeconds}s');
        }
      } catch (e) {
        lastError = e as Exception? ?? Exception('$e');
        if (kDebugMode) print('❌ POST $url failed: $e');
      }
    }

    if (kDebugMode) {
      print(
        '🚫 All POST attempts failed for $path. Tried:\n${triedUrls.join('\n')}',
      );
    }
    throw lastError ??
        Exception(
          'POST failed for $path after trying ${candidates.length} URLs',
        );
  }

  static Future<http.Response> _tryGet(
    String path,
    Map<String, String> headers,
  ) async {
    List<String> triedUrls = [];
    Exception? lastError;

    final candidates = _candidateBaseUrls();
    for (final base in candidates) {
      final url = '$base$path';
      triedUrls.add(url);
      if (kDebugMode) print('Trying GET $url');
      try {
        final response = await http
            .get(Uri.parse(url), headers: headers)
            .timeout(timeout);

        if (kDebugMode) {
          print('✅ GET $url succeeded with status ${response.statusCode}');
        }
        _cachedSuccessfulBaseUrl = base;
        return response;
      } on TimeoutException catch (e) {
        lastError = e;
        if (kDebugMode) {
          print('⏳ GET $url timed out after ${timeout.inSeconds}s');
        }
      } catch (e) {
        lastError = e as Exception? ?? Exception('$e');
        if (kDebugMode) print('❌ GET $url failed: $e');
      }
    }

    if (kDebugMode) {
      print(
        '🚫 All GET attempts failed for $path. Tried:\n${triedUrls.join('\n')}',
      );
    }
    throw lastError ??
        Exception(
          'GET failed for $path after trying ${candidates.length} URLs',
        );
  }

  static Future<bool> testBaseUrl(String baseUrl) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    if (normalized.isEmpty) return false;

    try {
      final response = await http
          .get(Uri.parse('$normalized/auth/health'))
          .timeout(const Duration(seconds: 5));
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

      final response = await _tryPost('/auth/register', {
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
      final msg = _networkErrorMessage('Register', e);
      if (kDebugMode) print(msg);
      return AuthResponse(success: false, message: msg);
    } on http.ClientException catch (e) {
      final msg = _networkErrorMessage('Register', e);
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

      final response = await _tryPost('/auth/login', {
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
      final msg = _networkErrorMessage('Login', e);
      if (kDebugMode) print(msg);
      return AuthResponse(success: false, message: msg);
    } on http.ClientException catch (e) {
      final msg = _networkErrorMessage('Login', e);
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
      final response = await _tryGet('/auth/validate-token', {
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
      final response = await _tryPost('/auth/logout', {
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
      await _tryPost(
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
