import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import 'backend_platform_stub.dart'
    if (dart.library.io) 'backend_platform_io.dart';

/// Local-dev backend configuration.
///
/// Defaults:
/// - Desktop: `http://127.0.0.1:7860/api`
/// - Android emulator: `http://10.0.2.2:7860/api`
/// - Android physical device: `http://192.168.1.19:7860/api` for the current
///   LAN. Change this if your PC gets a different IP, or override with
///   `--dart-define=API_BASE_URL=...`.
class BackendConfig {
  static const String _productionApiBase =
      'https://anil1515-chess-backend.hf.space/api';
  static const String _productionSocketBase =
      'https://anil1515-chess-backend.hf.space';
  static const String _lanApiBase = 'http://192.168.1.19:7860/api';

  static const String _apiDefine = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String _socketDefine = String.fromEnvironment(
    'SOCKET_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    final explicit = _normalize(_apiDefine);
    if (explicit.isNotEmpty) return explicit;

    if (kReleaseMode) {
      return _productionApiBase;
    }

    switch (detectBackendDeviceType()) {
      case BackendDeviceType.web:
        final origin = _webOrigin();
        return origin.isEmpty ? 'http://127.0.0.1:7860/api' : '$origin/api';
      case BackendDeviceType.androidEmulator:
        return 'http://10.0.2.2:7860/api';
      case BackendDeviceType.androidPhysical:
        return _lanApiBase;
      case BackendDeviceType.ios:
        return 'http://127.0.0.1:7860/api';
      case BackendDeviceType.desktop:
        return 'http://127.0.0.1:7860/api';
      case BackendDeviceType.unknown:
        return _lanApiBase;
    }
  }

  static String get socketBaseUrl {
    final explicit = _normalize(_socketDefine);
    if (explicit.isNotEmpty) return explicit;

    if (kReleaseMode) {
      return _productionSocketBase;
    }

    final apiUrl = apiBaseUrl;
    if (apiUrl.endsWith('/api')) {
      return apiUrl.substring(0, apiUrl.length - 4);
    }
    return apiUrl;
  }

  static Future<void> initialize() async {}

  static bool get hasExplicitBaseUrl => _normalize(_apiDefine).isNotEmpty;
  static bool get hasStoredBaseUrl => false;
  static bool get needsUserConfiguredBaseUrl => false;

  static String get environmentLabel {
    switch (detectBackendDeviceType()) {
      case BackendDeviceType.web:
        return 'web';
      case BackendDeviceType.androidEmulator:
        return 'android-emulator';
      case BackendDeviceType.androidPhysical:
        return 'android-physical';
      case BackendDeviceType.ios:
        return 'ios';
      case BackendDeviceType.desktop:
        return 'desktop';
      case BackendDeviceType.unknown:
        return 'unknown';
    }
  }

  static String _webOrigin() {
    if (!kIsWeb) return '';
    final host = Uri.base.host.trim();
    if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
      return '';
    }
    return '${Uri.base.scheme}://$host${Uri.base.hasPort ? ':${Uri.base.port}' : ''}';
  }

  static String _normalize(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static void logResolution() {
    if (!kDebugMode) return;
    debugPrint('BackendConfig: environment=$environmentLabel');
    debugPrint('BackendConfig: apiBaseUrl=$apiBaseUrl');
    debugPrint('BackendConfig: socketBaseUrl=$socketBaseUrl');
  }
}
