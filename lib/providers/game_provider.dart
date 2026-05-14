// Game State Provider
import 'package:flutter/material.dart';
import '../models/ludo_models.dart';
import '../services/ludo_game_logic.dart';
import '../services/ai_player.dart';
import '../services/ludo_socket_service.dart';

class GameProvider extends ChangeNotifier {
  GameController? _gameController;
  AIPlayer? _aiPlayer;
  LudoSocketService? _socketService;

  GameState? get gameState => _gameController?.gameState;
  bool get isGamePlaying => gameState?.isPlaying ?? false;
  bool get hasGameEnded => gameState?.hasGameEnded ?? false;
  Player? get currentPlayer => gameState?.currentPlayer;
  Player? get winner => gameState?.winner;
  int get diceValue => gameState?.diceValue ?? 0;
  bool get diceRolled => gameState?.diceRolled ?? false;
  bool get canMove => gameState?.canMove ?? false;

  /// Initialize offline game
  void initializeOfflineGame({
    required List<Player> players,
    required GameMode gameMode,
  }) {
    _gameController = GameController();
    _gameController!.initializeGame(players: players, gameMode: gameMode);
    _gameController!.onGameStateChanged = () => notifyListeners();
    _gameController!.onTurnChanged = (_) => notifyListeners();
    _gameController!.onTokenMoved = (_) => notifyListeners();
    _gameController!.onGameEnded = (_) => notifyListeners();

    // Initialize AI if needed
    if (players.any((p) => p.type == PlayerType.ai)) {
      _aiPlayer = AIPlayer(
        difficulty:
            players.firstWhere((p) => p.type == PlayerType.ai).difficulty ??
            DifficultyLevel.medium,
      );
    }

    notifyListeners();
  }

  /// Initialize online game
  void initializeOnlineGame({
    required List<Player> players,
    required String serverUrl,
    required String userId,
  }) {
    _gameController = GameController();
    _gameController!.initializeGame(
      players: players,
      gameMode: GameMode.online,
    );
    _gameController!.onGameStateChanged = () => notifyListeners();
    _gameController!.onTurnChanged = (_) => notifyListeners();
    _gameController!.onTokenMoved = (_) => notifyListeners();
    _gameController!.onGameEnded = (_) => notifyListeners();

    // Initialize socket service
    _socketService = LudoSocketService();
    _socketService!.onDiceRollReceived = _handleRemoteDiceRoll;
    _socketService!.onTokenMoveReceived = _handleRemoteTokenMove;
    _socketService!.onTurnChanged = _handleRemoteTurnChange;
    _socketService!.onStateSync = _handleRemoteStateSync;

    notifyListeners();
  }

  /// Start game
  void startGame() {
    _gameController?.startGame();
    notifyListeners();
  }

  /// Roll dice
  int rollDice() {
    final diceValue = _gameController?.rollDice() ?? 0;
    notifyListeners();
    return diceValue;
  }

  /// Move token
  bool moveToken(Token token) {
    if (_gameController == null) return false;

    final result = _gameController!.moveToken(
      token,
      _gameController!.gameState.diceValue,
    );

    if (result && _socketService != null) {
      // Send move to server
      _sendMoveToServer(token);
    }

    notifyListeners();
    return result;
  }

  /// Get movable tokens
  List<Token> getMovableTokens() {
    if (gameState == null) return [];
    return LudoGameLogic.getMovableTokens(
      gameState!.currentPlayer,
      gameState!.diceValue,
    );
  }

  /// Auto play AI turn
  Future<void> autoPlayAITurn() async {
    if (_gameController == null || _aiPlayer == null) return;
    if (!isGamePlaying) return;

    // Wait for player to see dice
    await Future.delayed(const Duration(milliseconds: 1500));

    final aiPlayer = gameState!.currentPlayer;
    final movableTokens = LudoGameLogic.getMovableTokens(aiPlayer, diceValue);

    if (movableTokens.isNotEmpty) {
      final selectedToken = _aiPlayer!.getBestMove(
        aiPlayer,
        diceValue,
        gameState!.players,
      );

      if (selectedToken != null) {
        await Future.delayed(const Duration(milliseconds: 800));
        moveToken(selectedToken);
      }
    } else {
      // No movable token, end turn
      _gameController!.endTurn();
      notifyListeners();
    }
  }

  /// Pause game
  void pauseGame() {
    _gameController?.pauseGame();
    notifyListeners();
  }

  /// Resume game
  void resumeGame() {
    _gameController?.resumeGame();
    notifyListeners();
  }

  /// Reset game
  void resetGame() {
    _gameController?.resetGame();
    notifyListeners();
  }

  /// Connect to online server
  Future<void> connectToServer(
    String serverUrl,
    String userId,
    String roomId,
    String username,
  ) async {
    if (_socketService == null) return;

    try {
      await _socketService!.connect(serverUrl, userId);
      _socketService!.joinRoom(roomId, username);
    } catch (e) {
      print('Connection error: $e');
    }
  }

  /// Disconnect from server
  void disconnectFromServer() {
    _socketService?.disconnect();
  }

  void _sendMoveToServer(Token token) {
    if (_socketService == null || gameState == null) return;

    _socketService!.sendTokenMove(
      gameState!.id,
      gameState!.currentPlayer.hashCode,
      token.id,
      token.position,
      token.position,
      token.isInHome,
      token.isInHome,
      LudoGameLogic.isSafePosition(token.position, token.playerColor),
    );
  }

  void _handleRemoteDiceRoll(dynamic data) {
    // Handle incoming dice roll from opponent
    notifyListeners();
  }

  void _handleRemoteTokenMove(dynamic data) {
    // Handle incoming token move from opponent
    notifyListeners();
  }

  void _handleRemoteTurnChange(dynamic data) {
    // Handle turn change from server
    notifyListeners();
  }

  void _handleRemoteStateSync(dynamic data) {
    // Sync game state from server
    notifyListeners();
  }

  @override
  void dispose() {
    _socketService?.disconnect();
    super.dispose();
  }
}
