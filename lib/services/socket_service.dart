import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class SocketService {
  io.Socket? _socket;
  Timer? _reconnectTimer;
  final Duration _reconnectDelay = const Duration(seconds: 2);
  final Duration _maxReconnectDelay = const Duration(seconds: 30);
  Duration _currentDelay = const Duration(seconds: 2);

  void connect({
    required String token,
    required void Function(dynamic) onMessage,
    required void Function() onConnected,
    required void Function() onDisconnected,
  }) {
    final base = ApiService.socketBaseUrl;
    final url = base; // socketBaseUrl already strips /api

    if (_socket != null && _socket!.connected) {
      if (kDebugMode) {
        print('Socket already connected');
      }
      return;
    }

    if (kDebugMode) print('Connecting to socket: $url');

    _socket = io.io(url, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'extraHeaders': {'Authorization': 'Bearer $token'},
    });

    _socket!.on('connect', (_) {
      if (kDebugMode) print('Socket connected');
      _currentDelay = _reconnectDelay;
      onConnected();
    });

    _socket!.on('disconnect', (_) {
      if (kDebugMode) print('Socket disconnected');
      onDisconnected();
      _scheduleReconnect(
        token: token,
        onMessage: onMessage,
        onConnected: onConnected,
        onDisconnected: onDisconnected,
      );
    });

    _socket!.on('message', (data) => onMessage(data));

    _socket!.connect();
  }

  void _scheduleReconnect({
    required String token,
    required void Function(dynamic) onMessage,
    required void Function() onConnected,
    required void Function() onDisconnected,
  }) {
    _reconnectTimer?.cancel();
    if (kDebugMode) {
      print('Scheduling reconnect in ${_currentDelay.inSeconds}s');
    }
    _reconnectTimer = Timer(_currentDelay, () {
      if (kDebugMode) print('Attempting socket reconnect');
      connect(
        token: token,
        onMessage: onMessage,
        onConnected: onConnected,
        onDisconnected: onDisconnected,
      );
      _currentDelay = Duration(
        seconds: (_currentDelay.inSeconds * 2).clamp(
          _reconnectDelay.inSeconds,
          _maxReconnectDelay.inSeconds,
        ),
      );
    });
  }

  void send(String event, dynamic data) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit(event, data);
    } else {
      if (kDebugMode) print('Socket not connected — cannot send $event');
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _socket?.dispose();
    _socket = null;
  }
}
