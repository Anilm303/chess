import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

enum BackendDeviceType {
  web,
  androidEmulator,
  androidPhysical,
  ios,
  desktop,
  unknown,
}

BackendDeviceType detectBackendDeviceType() {
  if (kIsWeb) return BackendDeviceType.web;

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      final version = Platform.operatingSystemVersion.toLowerCase();
      final emulatorHints = <String>[
        'sdk_gphone',
        'emulator',
        'generic',
        'google_sdk',
        'x86',
        'ranchu',
        'goldfish',
      ];
      if (emulatorHints.any(version.contains)) {
        return BackendDeviceType.androidEmulator;
      }
      return BackendDeviceType.androidPhysical;
    case TargetPlatform.iOS:
      return BackendDeviceType.ios;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return BackendDeviceType.desktop;
    case TargetPlatform.fuchsia:
      return BackendDeviceType.unknown;
  }
}
