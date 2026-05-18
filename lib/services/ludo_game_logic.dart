// Ludo Game Logic Engine
import 'dart:math';
import 'dart:ui' show Offset;
import 'package:uuid/uuid.dart';
import '../models/ludo_models.dart';

class LudoGameLogic {
  static final Random _random = Random();

  /// Roll dice (1-6)
  static int rollDice() => _random.nextInt(6) + 1;

  /// Convenience getters from BoardConfig
  static int get mainBoardSize => BoardConfig.totalPositions; // 52
  static int get homePathSize => BoardConfig.homePositions; // 6

  static int getPlayerStartPosition(PlayerColor color) {
    return BoardConfig.playerStartPositions[color] ?? 0;
  }

  static bool isSafePosition(int position, PlayerColor playerColor) {
    if (position < 0) return true; // off-board/start is safe
    if (position >= mainBoardSize)
      return true; // any home-path position is safe
    return BoardConfig.safePositions.contains(position);
  }

  static int getHomeEntryPosition(PlayerColor color) {
    return BoardConfig.homeEntryPositions[color] ?? 0;
  }

  static Map<int, Offset> getBoardPositionCoordinates() {
    final Map<int, Offset> coords = {};
    const double centerX = 300;
    const double centerY = 300;
    const double radius = 250;

    for (int i = 0; i < mainBoardSize; i++) {
      final angle = (i * 360 / mainBoardSize - 90) * (pi / 180);
      coords[i] = Offset(
        centerX + radius * cos(angle),
        centerY + radius * sin(angle),
      );
    }

    return coords;
  }

  /// Check if token can be moved by given dice
  static bool canTokenBeMoved(Token token, int diceValue) {
    // If token was killed (sent back to home), allow it to be moved out
    // when the player rolls a 6 so it can spawn back onto the board.
    if (token.isKilled) return diceValue == 6;

    // token not opened
    if (token.position == -1) {
      return diceValue == 6;
    }

    // token in home path: allow move only if it doesn't overshoot final cell
    if (token.isInHome) {
      final finalIndex = mainBoardSize + homePathSize - 1;
      final remainingSteps = finalIndex - token.position;
      return diceValue <= remainingSteps && remainingSteps > 0;
    }

    // on main board always allowed (subject to other game rules)
    return true;
  }

  /// Calculate new absolute position for a token, or return current position if move not allowed.
  static int calculateNewPosition(
    Token token,
    int diceValue,
    PlayerColor playerColor,
  ) {
    // opening token
    if (token.position == -1) {
      if (diceValue == 6) return getPlayerStartPosition(playerColor);
      return -1;
    }

    // token already in home path
    if (token.isInHome) {
      final finalIndex = mainBoardSize + homePathSize - 1;
      final newPos = token.position + diceValue;
      if (newPos > finalIndex) return token.position; // cannot overshoot
      return newPos;
    }

    // token on main board
    final int startPos = getPlayerStartPosition(playerColor);
    final int stepsFromStart =
        (token.position - startPos + mainBoardSize) % mainBoardSize;
    final int totalSteps = stepsFromStart + diceValue;

    if (totalSteps > mainBoardSize - 1) {
      final int stepsIntoHome = totalSteps - (mainBoardSize - 1);
      if (stepsIntoHome <= homePathSize) {
        return mainBoardSize +
            stepsIntoHome -
            1; // first home cell = mainBoardSize
      }
      return token.position; // overshoots home
    }

    return (token.position + diceValue) % mainBoardSize;
  }

  static List<Token> getMovableTokens(Player player, int diceValue) {
    return player.tokens.where((t) => canTokenBeMoved(t, diceValue)).toList();
  }

  static List<Token> getTokensAtPosition(
    List<Player> players,
    int position,
    PlayerColor excludeColor,
  ) {
    final tokens = <Token>[];
    for (final player in players) {
      if (player.color == excludeColor) continue;
      for (final token in player.tokens) {
        if (!token.isKilled && token.position == position) tokens.add(token);
      }
    }
    return tokens;
  }

  static void killTokensAtPosition(
    List<Player> players,
    int position,
    PlayerColor excludeColor,
  ) {
    // Group tokens by player color to detect blocks
    final Map<PlayerColor, List<Token>> groups = {};
    for (final player in players) {
      if (player.color == excludeColor) continue;
      for (final token in player.tokens) {
        if (!token.isKilled && token.position == position) {
          groups.putIfAbsent(player.color, () => []).add(token);
        }
      }
    }

    // If a color has 2 or more tokens here, it's a block and is protected
    for (final entry in groups.entries) {
      if (entry.value.length >= 2) continue; // protected block
      for (final t in entry.value) {
        t.isKilled = true;
        t.position = -1;
        t.isInHome = false;
      }
    }
  }

  static void executeMove(GameState gameState, Token token, int diceValue) {
    final player = gameState.currentPlayer;
    final oldPos = token.position;
    final newPos = calculateNewPosition(token, diceValue, player.color);

    // no-op if cannot move
    if (newPos == token.position) return;

    token.position = newPos;
    token.isKilled = false; // revived by moving
    token.isInHome = newPos >= mainBoardSize;

    // check if token reached final home cell
    final finalIndex = mainBoardSize + homePathSize - 1;
    if (token.isInHome && token.position == finalIndex) {
      // increment finished counter for player
      player.tokensReachedHome++;
    }

    // handle kills: only on main board and only if landed on non-safe cell
    if (!token.isInHome && !isSafePosition(newPos, player.color)) {
      final victims = getTokensAtPosition(
        gameState.players,
        newPos,
        player.color,
      );
      if (victims.isNotEmpty) {
        killTokensAtPosition(gameState.players, newPos, player.color);
      }
    }
  }

  static bool checkWin(Player player) => player.tokensReachedHome == 4;

  static bool isDiceSix(int diceValue) => diceValue == 6;

  static bool isMoveLegal(
    Token token,
    int diceValue,
    int fromPosition,
    int toPosition,
  ) {
    if (!canTokenBeMoved(token, diceValue)) return false;
    final newPos = calculateNewPosition(token, diceValue, token.playerColor);
    return newPos == toPosition;
  }

  static int getRelativeProgress(Token token) {
    if (token.position == -1) return -1;
    if (token.position >= mainBoardSize)
      return mainBoardSize + (token.position - mainBoardSize);
    return token.position;
  }

  static int getProjectedProgress(Token token, int diceValue) {
    if (token.position == -1 && diceValue != 6) return -1;
    final projected = calculateNewPosition(token, diceValue, token.playerColor);
    if (token.position == -1 && diceValue == 6)
      return getPlayerStartPosition(token.playerColor);
    return projected;
  }

  static int getNextPosition(Token token, int diceValue) =>
      calculateNewPosition(token, diceValue, token.playerColor);

  static bool willEnterWinningPath(Token token, int diceValue) {
    final newPos = calculateNewPosition(token, diceValue, token.playerColor);
    return newPos >= mainBoardSize;
  }

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
    // Prevent rolling multiple times before resolving current roll
    if (gameState.diceRolled) return gameState.diceValue;

    gameState.diceValue = LudoGameLogic.rollDice();
    gameState.diceRolled = true;

    // Enable move if there are movable tokens
    final movableTokens = LudoGameLogic.getMovableTokens(
      gameState.currentPlayer,
      gameState.diceValue,
    );

    gameState.canMove = movableTokens.isNotEmpty;

    // If no movable tokens but dice is 6, allow extra roll later (UI/AI handles)
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

    final n = gameState.players.length;
    if (n == 0) return;

    final start = gameState.currentPlayerIndex;
    bool found = false;

    for (int i = 1; i <= n; i++) {
      final nextIndex = (start + i) % n;
      final candidate = gameState.players[nextIndex];

      // skip players who already finished
      if (candidate.tokensReachedHome >= 4) continue;

      // found next player
      gameState.currentPlayerIndex = nextIndex;
      found = true;
      break;
    }

    if (!found) {
      // no eligible players left -> finish game
      gameState.status = GameStatus.finished;
      gameState.endedAt = DateTime.now();
      onGameEnded?.call(gameState.winner);
      onGameStateChanged?.call();
      return;
    }

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
