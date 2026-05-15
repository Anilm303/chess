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
  return BackendDeviceType.unknown;
}
