import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'theme/colors.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/call_service.dart';
import 'services/message_service.dart';
import 'services/note_service.dart';
import 'services/story_service.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'services/fcm_service.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/call_screen.dart';
import 'screens/chess_board_screen.dart';
import 'screens/notifications_screen.dart';
import 'navigation/app_navigator.dart';
import 'widgets/incoming_call_toast_host.dart';

const bool _enablePushNotifications = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.initialize();
  if (!kIsWeb && _enablePushNotifications) {
    await FCMService().initialize();
  }
  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthService()),
        ChangeNotifierProvider(create: (context) => CallService()),
        ChangeNotifierProvider(create: (context) => MessageService()),
        ChangeNotifierProvider(create: (context) => NoteService()),
        ChangeNotifierProvider(create: (context) => StoryService()),
        ChangeNotifierProvider(create: (context) => ThemeService()),
        ChangeNotifierProvider(
          create: (context) => NotificationService(
            authService: context.read<AuthService>(),
            callService: context.read<CallService>(),
          ),
        ),
      ],
      child: Builder(
        builder: (builderContext) {
          return MaterialApp(
            navigatorKey: rootNavigatorKey,
            title: 'Flutter Chess',
            debugShowCheckedModeBanner: false,
            theme: MessengerTheme.getLightTheme(),
            darkTheme: MessengerTheme.getDarkTheme(),
            themeMode: builderContext.watch<ThemeService>().themeMode,
            builder: (context, child) {
              return IncomingCallToastHost(
                child: Stack(
                  children: [
                    ...((child != null) ? [child] : const []),
                    const _CallBootstrapHost(),
                  ],
                ),
              );
            },
            home: const AuthGate(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/chess': (context) => const ChessBoardScreen(),
              '/notifications': (context) => const NotificationsScreen(),
            },
          );
        },
      ),
    );
  }
}

/// AuthGate handles route protection based on authentication status
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        // If authenticated, show chess board
        if (authService.isAuthenticated) {
          return const ChessBoardScreen();
        }

        // Otherwise show login screen
        return const LoginScreen();
      },
    );
  }
}

class _CallBootstrapHost extends StatefulWidget {
  const _CallBootstrapHost();

  @override
  State<_CallBootstrapHost> createState() => _CallBootstrapHostState();
}

class _CallBootstrapHostState extends State<_CallBootstrapHost> {
  String? _connectedFor;
  String? _lastBaseUrl;
  StreamSubscription? _callKitSubscription;

  @override
  void initState() {
    super.initState();
    _initCallKit();
  }

  void _initCallKit() {
    if (kIsWeb) return;

    try {
      _callKitSubscription = FlutterCallkitIncoming.onEvent.listen((
        CallEvent? event,
      ) async {
        if (event == null) return;

        debugPrint('📱 CallKit Event: ${event.event}');

        try {
          final authService = context.read<AuthService>();
          final callService = context.read<CallService>();

          if (!authService.isAuthenticated) {
            debugPrint('❌ Not authenticated for call event');
            return;
          }

          switch (event.event) {
            case Event.actionCallAccept:
              debugPrint('✅ User accepted call from CallKit');
              // Navigate to call screen
              if (mounted && rootNavigatorKey.currentState != null) {
                rootNavigatorKey.currentState!.push(
                  MaterialPageRoute(builder: (_) => const CallScreen()),
                );
              }
              // Accept the call
              try {
                await callService.acceptIncomingCall();
              } catch (e) {
                debugPrint('❌ Error accepting call: $e');
              }
              break;

            case Event.actionCallDecline:
              debugPrint('❌ User declined call from CallKit');
              try {
                await callService.rejectIncomingCall();
              } catch (e) {
                debugPrint('❌ Error rejecting call: $e');
              }
              break;

            case Event.actionCallEnded:
              debugPrint('📞 Call ended from CallKit');
              try {
                await callService.endCall();
              } catch (e) {
                debugPrint('❌ Error ending call: $e');
              }
              break;

            default:
              debugPrint('ℹ️ Other CallKit event: ${event.event}');
          }
        } catch (e) {
          debugPrint('❌ Error handling CallKit event: $e');
        }
      });
    } catch (e) {
      debugPrint('❌ CallKit initialization error: $e');
    }
  }

  @override
  void dispose() {
    _callKitSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final callService = context.read<CallService>();

    if (!authService.isAuthenticated || authService.accessToken == null) {
      _connectedFor = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        callService.disconnect();
      });
      return const SizedBox.shrink();
    }

    final username = authService.currentUser?.username ?? '';
    final baseUrl = ApiService.baseUrl;
    final displayName =
        authService.currentUser?.fullName.trim().isNotEmpty == true
        ? authService.currentUser!.fullName.trim()
        : username;

    if (_connectedFor != username || _lastBaseUrl != baseUrl) {
      _connectedFor = username;
      _lastBaseUrl = baseUrl;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        callService.disconnect();
        callService.connect(
          accessToken: authService.accessToken!,
          username: username,
          displayName: displayName,
        );
        if (_enablePushNotifications) {
          // Sync FCM token only when Firebase is configured.
          FCMService().updateTokenOnBackend(authService.accessToken!);
        }
      });
    }

    return const SizedBox.shrink();
  }
}
