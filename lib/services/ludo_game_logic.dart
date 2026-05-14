// Ludo Game Logic Engine
import 'dart:math';
import 'dart:ui' show Offset;
import 'package:uuid/uuid.dart';
import '../models/ludo_models.dart';

class LudoGameLogic {
  static const int boardSize = 52;
  static const int homePathSize = 6;
  static final Random _random = Random();

  /// Roll dice (1-6)
  static int rollDice() {
    return _random.nextInt(6) + 1;
  }

  /// Get starting position for a player color
  static int getPlayerStartPosition(PlayerColor color) {
    return BoardConfig.playerStartPositions[color] ?? 0;
  }

  /// Check if a position is a safe zone
  static bool isSafePosition(int position, PlayerColor playerColor) {
    if (position == -1 || position >= boardSize + homePathSize) {
      return true; // Home is safe
    }
    return BoardConfig.safePositions.contains(position);
  }

  /// Get home entry position for a player
  static int getHomeEntryPosition(PlayerColor color) {
    return BoardConfig.homeEntryPositions[color] ?? 0;
  }

  /// Get all board position coordinates for rendering
  static Map<int, Offset> getBoardPositionCoordinates() {
    // This creates a circular board layout
    // Position 0 is top-right (red start)
    // Positions increase clockwise
    final Map<int, Offset> coords = {};
    const double centerX = 300;
    const double centerY = 300;
    const double radius = 250;

    for (int i = 0; i < boardSize; i++) {
      final angle = (i * 360 / boardSize - 90) * (pi / 180);
      coords[i] = Offset(
        centerX + radius * cos(angle),
        centerY + radius * sin(angle),
      );
    }

    return coords;
  }

  /// Check if token can be moved
  static bool canTokenBeMoved(Token token, int diceValue) {
    if (token.isKilled) return false;

    // Token must be opened first
    if (token.position == -1) {
      return diceValue == 6; // Can open token only on 6
    }

    // Token in home path needs exact dice
    if (token.isInHome) {
      final remainingSteps = homePathSize - (token.position - boardSize);
      return diceValue == remainingSteps;
    }

    return true;
  }

  /// Calculate new position after dice roll
  static int calculateNewPosition(
    Token token,
    int diceValue,
    PlayerColor playerColor,
  ) {
    // Token opening
    if (token.position == -1) {
      if (diceValue == 6) {
        return getPlayerStartPosition(playerColor);
      }
      return -1;
    }

    // Token in home path
    if (token.isInHome) {
      final newPos = token.position + diceValue;
      if (newPos >= boardSize + homePathSize) {
        return boardSize + homePathSize; // Reached home
      }
      return newPos;
    }

    // Token in main board
    final int startPos = getPlayerStartPosition(playerColor);
    final int currentSteps = (token.position - startPos + boardSize) % boardSize;

    if (currentSteps + diceValue > 51) {
      // Token would pass the entry point to the home path
      final int stepsIntoHome = (currentSteps + diceValue) - 51;

      // Check if it reaches or stays within the home path (including center at 6)
      if (stepsIntoHome <= homePathSize) {
        return boardSize + stepsIntoHome - 1; // Maps to 52, 53, 54, 55, 56, 57
      }
      // If it exceeds the center, it cannot move (needs exact dice)
      return token.position;
    }

    // Normal move around the board
    return (token.position + diceValue) % boardSize;
  }

  /// Get all movable tokens for current player
  static List<Token> getMovableTokens(Player player, int diceValue) {
    return player.tokens.where((token) {
      return canTokenBeMoved(token, diceValue);
    }).toList();
  }

  /// Check if there are opponent tokens at position to kill
  static List<Token> getTokensAtPosition(
    List<Player> players,
    int position,
    PlayerColor excludeColor,
  ) {
    final tokens = <Token>[];

    for (final player in players) {
      if (player.color == excludeColor) continue;

      for (final token in player.tokens) {
        if (token.position == position && !token.isKilled) {
          tokens.add(token);
        }
      }
    }

    return tokens;
  }

  /// Kill opponent tokens at position
  static void killTokensAtPosition(
    List<Player> players,
    int position,
    PlayerColor excludeColor,
  ) {
    for (final player in players) {
      if (player.color == excludeColor) continue;

      for (final token in player.tokens) {
        if (token.position == position && !token.isKilled) {
          token.isKilled = true;
          token.position = -1; // Reset to start
        }
      }
    }
  }

  /// Execute a move
  static void executeMove(GameState gameState, Token token, int diceValue) {
    final player = gameState.currentPlayer;
    final oldPosition = token.position;
    final newPosition = calculateNewPosition(token, diceValue, player.color);

    // Move token
    token.position = newPosition;

    // Check if entered home
    if (newPosition >= BoardConfig.totalPositions) {
      token.isInHome = true;
      if (newPosition >= BoardConfig.totalPositions + homePathSize) {
        token.isKilled = false; // Token reached home (victory)
        player.tokensReachedHome++;
      }
    }

    // Check for kills (only on main board and not on safe zones)
    if (!token.isInHome && !isSafePosition(newPosition, player.color)) {
      final killedTokens = getTokensAtPosition(
        gameState.players,
        newPosition,
        player.color,
      );

      if (killedTokens.isNotEmpty) {
        for (final killedToken in killedTokens) {
          killedToken.isKilled = true;
          killedToken.position = -1;
        }
      }
    }
  }

  /// Check if player has won
  static bool checkWin(Player player) {
    return player.tokensReachedHome == 4;
  }

  /// Check if dice is 6 (extra turn)
  static bool isDiceSix(int diceValue) {
    return diceValue == 6;
  }

  /// Validate if a move is legal
  static bool isMoveLegal(
    Token token,
    int diceValue,
    int fromPosition,
    int toPosition,
  ) {
    if (!canTokenBeMoved(token, diceValue)) {
      return false;
    }

    final newPos = calculateNewPosition(token, diceValue, token.playerColor);
    return newPos == toPosition;
  }

  /// Get relative progress of token (0-51)
  static int getRelativeProgress(Token token) {
    if (token.position == -1) return -1;
    return token.position;
  }

  /// Get projected progress after move
  static int getProjectedProgress(Token token, int diceValue) {
    if (token.position == -1 && diceValue != 6) {
      return -1;
    }

    final startPos = getPlayerStartPosition(token.playerColor);
    final projected = calculateNewPosition(token, diceValue, token.playerColor);

    if (token.position == -1 && diceValue == 6) {
      return startPos;
    }

    return projected;
  }

  /// Get next position
  static int getNextPosition(Token token, int diceValue) {
    return calculateNewPosition(token, diceValue, token.playerColor);
  }

  /// Check if token will enter winning path
  static bool willEnterWinningPath(Token token, int diceValue) {
    final newPos = calculateNewPosition(token, diceValue, token.playerColor);
    return newPos >= boardSize;
  }

  /// Get safe positions list
  static List<int> get safePositions => BoardConfig.safePositions;
}

/// Game controller for managing game state
class GameController {
  late GameState gameState;
  Function? onGameStateChanged;
  Function? onTurnChanged;
  Function? onGameEnded;
  Function? onTokenMoved;

  void initializeGame({
    required List<Player> players,
    required GameMode gameMode,
  }) {
    gameState = GameState(
      id: const Uuid().v4(),
      players: players,
      createdAt: DateTime.now(),
      gameMode: gameMode,
      currentPlayerIndex: 0,
    );
  }

  void startGame() {
    gameState.status = GameStatus.playing;
    gameState.startedAt = DateTime.now();
    onGameStateChanged?.call();
  }

  int rollDice() {
    if (!gameState.isPlaying) return 0;

    gameState.diceValue = LudoGameLogic.rollDice();
    gameState.diceRolled = true;

    // Enable move if there are movable tokens
    final movableTokens = LudoGameLogic.getMovableTokens(
      gameState.currentPlayer,
      gameState.diceValue,
    );

    gameState.canMove = movableTokens.isNotEmpty;

    onGameStateChanged?.call();
    return gameState.diceValue;
  }

  bool moveToken(Token token, int diceValue) {
    if (!gameState.isPlaying || !gameState.diceRolled) {
      return false;
    }

    if (!LudoGameLogic.canTokenBeMoved(token, diceValue)) {
      return false;
    }

    // Execute move
    LudoGameLogic.executeMove(gameState, token, diceValue);

    onTokenMoved?.call(token);

    // Check for win
    if (LudoGameLogic.checkWin(gameState.currentPlayer)) {
      gameState.winner = gameState.currentPlayer;
      gameState.status = GameStatus.finished;
      gameState.endedAt = DateTime.now();
      onGameEnded?.call(gameState.winner);
      return true;
    }

    // Handle turns
    if (!LudoGameLogic.isDiceSix(diceValue)) {
      endTurn();
    } else {
      // Extra turn on 6
      gameState.currentPlayer.consecutiveSixes++;

      // Cancel turn after 3 consecutive 6s
      if (gameState.currentPlayer.consecutiveSixes >= 3) {
        gameState.currentPlayer.consecutiveSixes = 0;
        endTurn();
      }
    }

    gameState.diceRolled = false;
    gameState.canMove = false;
    onGameStateChanged?.call();

    return true;
  }

  void endTurn() {
    gameState.currentPlayer.consecutiveSixes = 0;
    gameState.currentPlayerIndex =
        (gameState.currentPlayerIndex + 1) % gameState.players.length;
    gameState.diceValue = 0;
    gameState.diceRolled = false;
    gameState.canMove = false;

    onTurnChanged?.call(gameState.currentPlayer);
    onGameStateChanged?.call();
  }

  void pauseGame() {
    gameState.status = GameStatus.paused;
    onGameStateChanged?.call();
  }

  void resumeGame() {
    gameState.status = GameStatus.playing;
    onGameStateChanged?.call();
  }

  void resetGame() {
    gameState.status = GameStatus.waiting;
    gameState.diceValue = 0;
    gameState.diceRolled = false;
    gameState.canMove = false;
    gameState.winner = null;
    gameState.currentPlayerIndex = 0;

    for (final player in gameState.players) {
      player.isCurrentTurn = false;
      player.consecutiveSixes = 0;
      player.tokensReachedHome = 0;

      for (final token in player.tokens) {
        token.position = -1;
        token.isKilled = false;
        token.isInHome = false;
      }
    }

    onGameStateChanged?.call();
  }
}
