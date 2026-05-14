// Ludo Multiplayer Socket Service
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/ludo_models.dart';

class LudoSocketService {
  late IO.Socket socket;
  String? userId;
  String? roomId;
  bool isConnected = false;

  // Event callbacks
  Function(dynamic)? onDiceRollReceived;
  Function(dynamic)? onTokenMoveReceived;
  Function(dynamic)? onTurnChanged;
  Function(dynamic)? onStateSync;
  Function(dynamic)? onPlayerJoined;
  Function(dynamic)? onPlayerLeft;
  Function(dynamic)? onGameStarted;
  Function(dynamic)? onGameEnded;
  Function(dynamic)? onActionRejected;
  Function(dynamic)? onError;

  // Legacy event names (kept for compatibility)
  Function(dynamic)? onDiceRolled;
  Function(dynamic)? onMoveReceived;

  /// Connect to server
  Future<void> connect(String serverUrl, String userId) async {
    this.userId = userId;

    try {
      socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .setReconnectionAttempts(10)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .build(),
      );

      socket.on('connect', (_) {
        isConnected = true;
        print('Connected to Ludo server');
      });

      socket.on('disconnect', (_) {
        isConnected = false;
        print('Disconnected from Ludo server');
      });

      socket.on('ludo_dice_roll', (data) {
        onDiceRollReceived?.call(data);
        onDiceRolled?.call(data);
      });

      socket.on('ludo_token_move', (data) {
        onTokenMoveReceived?.call(data);
        onMoveReceived?.call(data);
      });

      socket.on('ludo_turn_change', (data) {
        onTurnChanged?.call(data);
      });

      socket.on('ludo_state_sync', (data) {
        onStateSync?.call(data);
      });

      socket.on('ludo_player_joined', (data) {
        onPlayerJoined?.call(data);
      });

      socket.on('ludo_player_left', (data) {
        onPlayerLeft?.call(data);
      });

      socket.on('ludo_game_started', (data) {
        onGameStarted?.call(data);
      });

      socket.on('ludo_game_ended', (data) {
        onGameEnded?.call(data);
      });

      socket.on('ludo_action_rejected', (data) {
        onActionRejected?.call(data);
      });

      socket.on('error', (data) {
        onError?.call(data);
      });
    } catch (e) {
      print('Socket connection error: $e');
      onError?.call(e);
    }
  }

  /// Join room
  void joinRoom(String roomId, String username) {
    this.roomId = roomId;
    socket.emit('ludo_join_room', {
      'roomId': roomId,
      'username': username,
      'userId': userId,
    });
  }

  /// Request game state
  void requestState(String roomId) {
    socket.emit('ludo_request_state', {'roomId': roomId});
  }

  /// Sync game state
  void syncGameState(
    String roomId,
    Map<String, dynamic> state, {
    int? stateVersion,
  }) {
    socket.emit('ludo_state_sync', {
      'roomId': roomId,
      'state': state,
      'stateVersion': stateVersion ?? 0,
    });
  }

  /// Send dice roll
  void sendDiceRoll(String roomId, int playerId, int diceValue) {
    socket.emit('ludo_dice_roll', {
      'roomId': roomId,
      'playerId': playerId,
      'diceValue': diceValue,
    });
  }

  /// Send token move
  void sendTokenMove(
    String roomId,
    int playerId,
    int tokenId,
    int fromPos,
    int toPos,
    bool inWinningPath,
    bool isInHome,
    bool isSafe,
  ) {
    socket.emit('ludo_token_move', {
      'roomId': roomId,
      'playerId': playerId,
      'tokenId': tokenId,
      'from': fromPos,
      'to': toPos,
      'inWinningPath': inWinningPath,
      'isInHome': isInHome,
      'isSafe': isSafe,
    });
  }

  /// Send dice roll request (let server roll)
  void sendDiceRollRequest(String roomId, int playerId) {
    socket.emit('ludo_dice_roll_request', {
      'roomId': roomId,
      'playerId': playerId,
    });
  }

  /// Send token move request (let server validate)
  void sendTokenMoveRequest(
    String roomId,
    int playerId,
    int tokenId,
    int fromPos,
    int toPos,
    int diceValue,
    bool inWinningPath,
    bool isInHome,
    bool isSafe,
  ) {
    socket.emit('ludo_token_move_request', {
      'roomId': roomId,
      'playerId': playerId,
      'tokenId': tokenId,
      'from': fromPos,
      'to': toPos,
      'diceValue': diceValue,
      'inWinningPath': inWinningPath,
      'isInHome': isInHome,
      'isSafe': isSafe,
    });
  }

  /// Send turn change notification
  void sendTurnChange(String roomId, int currentPlayerId) {
    socket.emit('ludo_turn_change', {
      'roomId': roomId,
      'currentPlayerId': currentPlayerId,
    });
  }

  /// Disconnect
  void disconnect() {
    socket.disconnect();
    isConnected = false;
  }

  /// Check connection status
  bool isConnectedToServer() {
    return isConnected && socket.connected;
  }
}

/// Room manager for multiplayer
class RoomManager {
  static const String _prefix = 'ludo_room_';

  /// Generate room ID
  static String generateRoomId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (DateTime.now().microsecond % 10000).toString().padLeft(
      4,
      '0',
    );
    return _prefix + timestamp.toString() + random;
  }

  /// Validate room ID format
  static bool isValidRoomId(String roomId) {
    return roomId.startsWith(_prefix) && roomId.length > _prefix.length;
  }
}
