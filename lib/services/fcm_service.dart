import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'api_service.dart';
import 'device_bootstrap.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  String? _token;
  String? get token => _token;

  Future<void> initialize() async {
    try {
      await DeviceBootstrap.initializeFirebaseIfAvailable();

      final messaging = FirebaseMessaging.instance;

      // Request permissions (especially for iOS)
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // Get the token
      _token = await messaging.getToken();
      if (kDebugMode) {
        print('🔥 FCM Token: $_token');
      }

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('📩 Foreground FCM Message: ${message.data}');
        }
        _handleMessage(message);
      });

      // Handle message when app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('🖱️ App opened from FCM: ${message.data}');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM Initialization Error: $e');
      }
    }
  }

  Future<void> updateTokenOnBackend(String accessToken) async {
    if (_token == null) return;

    try {
      await ApiService.updateFcmToken(_token!, accessToken);
      if (kDebugMode) {
        print('✅ FCM Token updated on backend');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to update FCM token on backend: $e');
      }
    }
  }

  void _handleMessage(RemoteMessage message) {
    final type = message.data['type'];
    if (type == 'call' || type == 'incoming_call') {
      _showIncomingCallUi(message.data);
    }
  }

  static Future<void> _showIncomingCallUi(Map<String, dynamic> data) async {
    final callId = data['call_id'] ?? const Uuid().v4();
    final callerName =
        data['caller_display_name'] ??
        data['caller_username'] ??
        'Unknown Caller';
    final isVideo = data['call_type'] == 'video';

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'Chess Messenger',
      avatar: data['caller_profile_image'],
      handle: data['caller_username'] ?? '',
      type: isVideo ? 1 : 0, // 0: audio, 1: video
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      extra: <String, dynamic>{'room_id': data['room_id'], 'call_id': callId},
      headers: <String, dynamic>{'apiKey': 'Abc@123!', 'platform': 'flutter'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#075E54',
        backgroundUrl: 'https://i.pravatar.cc/500',
        actionColor: '#4CAF50',
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: true,
        supportsUngrouping: true,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }
}

// Global background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await DeviceBootstrap.initializeFirebaseIfAvailable();
  if (kDebugMode) {
    print('🌙 Handling background message: ${message.messageId}');
  }

  final type = message.data['type'];
  if (type == 'call' || type == 'incoming_call') {
    await FCMService._showIncomingCallUi(message.data);
  }
}
