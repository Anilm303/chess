import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceBootstrap {
  static Future<void> initializeFirebaseIfAvailable() async {
    if (Firebase.apps.isNotEmpty) {
      return;
    }

    try {
      await Firebase.initializeApp();
      if (kDebugMode) {
        print('🔥 Firebase initialized');
      }
    } catch (error) {
      if (kDebugMode) {
        print('⚠️ Firebase not initialized on this build: $error');
      }
    }
  }

  static Future<void> requestStartupPermissions() async {
    if (kIsWeb) {
      return;
    }

    final permissions = <Permission>[];

    if (Platform.isAndroid) {
      permissions.addAll(<Permission>[
        Permission.camera,
        Permission.microphone,
        Permission.notification,
        Permission.photos,
        Permission.videos,
        Permission.audio,
        Permission.storage,
      ]);
    } else if (Platform.isIOS) {
      permissions.addAll(<Permission>[
        Permission.camera,
        Permission.microphone,
        Permission.photos,
        Permission.videos,
        Permission.mediaLibrary,
      ]);
    }

    final uniquePermissions = <Permission>{...permissions}.toList();
    if (uniquePermissions.isEmpty) {
      return;
    }

    try {
      final result = await uniquePermissions.request();
      if (kDebugMode) {
        print('🔐 Startup permissions: $result');
      }
    } catch (error) {
      if (kDebugMode) {
        print('⚠️ Permission bootstrap failed: $error');
      }
    }
  }
}
