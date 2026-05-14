// Ludo Game Models
import 'package:flutter/material.dart';

enum PlayerColor { red, green, yellow, blue }

enum PlayerType { human, ai }

enum GameMode { offline, online, vsComputer }

enum DifficultyLevel { easy, medium, hard }

enum GameStatus { waiting, playing, paused, finished }

/// Represents a single token in the game
class Token {
  int id; // 0-3 (4 tokens per player)
  PlayerColor playerColor;
  int position; // 0-51 (board positions)
  bool isInHome; // true when token is in home zone
  bool isKilled; // true when token is captured

  Token({
    required this.id,
    required this.playerColor,
    this.position = -1, // -1 means not yet opened
    this.isInHome = false,
    this.isKilled = false,
  });

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      id: json['id'],
      playerColor: PlayerColor.values[json['playerColor']],
      position: json['position'],
      isInHome: json['isInHome'],
      isKilled: json['isKilled'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playerColor': playerColor.index,
      'position': position,
      'isInHome': isInHome,
      'isKilled': isKilled,
    };
  }

  Token copy() {
    return Token(
      id: id,
      playerColor: playerColor,
      position: position,
      isInHome: isInHome,
      isKilled: isKilled,
    );
  }
}

/// Represents a player in the game
class Player {
  String id;
  String name;
  PlayerColor color;
  PlayerType type;
  DifficultyLevel? difficulty;
  List<Token> tokens;
  bool isCurrentTurn;
  int consecutiveSixes;
  int tokensReachedHome;

  Player({
    required this.id,
    required this.name,
    required this.color,
    this.type = PlayerType.human,
    this.difficulty,
    List<Token>? tokens,
    this.isCurrentTurn = false,
    this.consecutiveSixes = 0,
    this.tokensReachedHome = 0,
  }) : tokens = tokens ?? _createTokens(color);

  static List<Token> _createTokens(PlayerColor color) {
    return List.generate(4, (index) => Token(id: index, playerColor: color));
  }

  bool get hasWon => tokensReachedHome == 4;
  bool get hasOpenedToken => tokens.any((t) => t.position >= 0);

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'],
      name: json['name'],
      color: PlayerColor.values[json['color']],
      type: PlayerType.values[json['type']],
      difficulty: json['difficulty'] != null
          ? DifficultyLevel.values[json['difficulty']]
          : null,
      tokens: (json['tokens'] as List<dynamic>?)
          ?.map((t) => Token.fromJson(t as Map<String, dynamic>))
          .toList(),
      isCurrentTurn: json['isCurrentTurn'],
      consecutiveSixes: json['consecutiveSixes'],
      tokensReachedHome: json['tokensReachedHome'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color.index,
      'type': type.index,
      'difficulty': difficulty?.index,
      'tokens': tokens.map((t) => t.toJson()).toList(),
      'isCurrentTurn': isCurrentTurn,
      'consecutiveSixes': consecutiveSixes,
      'tokensReachedHome': tokensReachedHome,
    };
  }

  Player copy() {
    return Player(
      id: id,
      name: name,
      color: color,
      type: type,
      difficulty: difficulty,
      tokens: tokens.map((t) => t.copy()).toList(),
      isCurrentTurn: isCurrentTurn,
      consecutiveSixes: consecutiveSixes,
      tokensReachedHome: tokensReachedHome,
    );
  }
}

/// Board configuration
class BoardConfig {
  static const int totalPositions = 52; // Main board positions
  static const int homePositions = 6; // Home path positions
  static const int boardSize = totalPositions + homePositions;

  // Starting positions for each player (clockwise)
  static const Map<PlayerColor, int> playerStartPositions = {
    PlayerColor.red: 0,
    PlayerColor.green: 13,
    PlayerColor.yellow: 26,
    PlayerColor.blue: 39,
  };

  // Safe star positions (cannot be killed)
  static const List<int> safePositions = [0, 8, 13, 21, 26, 34, 39, 47];

  // Home entry positions (must have exact dice)
  static const Map<PlayerColor, int> homeEntryPositions = {
    PlayerColor.red: 0,
    PlayerColor.green: 13,
    PlayerColor.yellow: 26,
    PlayerColor.blue: 39,
  };

  // Home path start (after reaching position 51)
  static const int homePathStart = 52;
}

/// Game state
class GameState {
  String id;
  List<Player> players;
  int currentPlayerIndex;
  int diceValue;
  bool diceRolled;
  bool canMove;
  GameStatus status;
  Player? winner;
  DateTime createdAt;
  DateTime? startedAt;
  DateTime? endedAt;
  GameMode gameMode;
  int? selectedTokenId; // -1 if no token selected

  GameState({
    required this.id,
    required this.players,
    this.currentPlayerIndex = 0,
    this.diceValue = 0,
    this.diceRolled = false,
    this.canMove = false,
    this.status = GameStatus.waiting,
    this.winner,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    required this.gameMode,
    this.selectedTokenId,
  });

  Player get currentPlayer => players[currentPlayerIndex];

  bool get hasGameEnded => status == GameStatus.finished;
  bool get isPlaying => status == GameStatus.playing;

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      id: json['id'],
      players: (json['players'] as List<dynamic>)
          .map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList(),
      currentPlayerIndex: json['currentPlayerIndex'],
      diceValue: json['diceValue'],
      diceRolled: json['diceRolled'],
      canMove: json['canMove'],
      status: GameStatus.values[json['status']],
      winner: json['winner'] != null
          ? Player.fromJson(json['winner'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'])
          : null,
      endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt']) : null,
      gameMode: GameMode.values[json['gameMode']],
      selectedTokenId: json['selectedTokenId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'players': players.map((p) => p.toJson()).toList(),
      'currentPlayerIndex': currentPlayerIndex,
      'diceValue': diceValue,
      'diceRolled': diceRolled,
      'canMove': canMove,
      'status': status.index,
      'winner': winner?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'gameMode': gameMode.index,
      'selectedTokenId': selectedTokenId,
    };
  }

  GameState copy() {
    return GameState(
      id: id,
      players: players.map((p) => p.copy()).toList(),
      currentPlayerIndex: currentPlayerIndex,
      diceValue: diceValue,
      diceRolled: diceRolled,
      canMove: canMove,
      status: status,
      winner: winner?.copy(),
      createdAt: createdAt,
      startedAt: startedAt,
      endedAt: endedAt,
      gameMode: gameMode,
      selectedTokenId: selectedTokenId,
    );
  }
}

/// Represents a move action
class Move {
  int tokenId;
  int fromPosition;
  int toPosition;
  int diceValue;
  bool killsOpponent;

  Move({
    required this.tokenId,
    required this.fromPosition,
    required this.toPosition,
    required this.diceValue,
    this.killsOpponent = false,
  });

  factory Move.fromJson(Map<String, dynamic> json) {
    return Move(
      tokenId: json['tokenId'],
      fromPosition: json['fromPosition'],
      toPosition: json['toPosition'],
      diceValue: json['diceValue'],
      killsOpponent: json['killsOpponent'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tokenId': tokenId,
      'fromPosition': fromPosition,
      'toPosition': toPosition,
      'diceValue': diceValue,
      'killsOpponent': killsOpponent,
    };
  }
}

/// Room for online multiplayer
class GameRoom {
  String id;
  String name;
  String creatorId;
  List<String> playerIds;
  int maxPlayers;
  GameMode gameMode;
  bool isStarted;
  bool get isFull => playerIds.length >= maxPlayers;

  GameRoom({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.playerIds,
    this.maxPlayers = 4,
    this.gameMode = GameMode.online,
    this.isStarted = false,
  });

  factory GameRoom.fromJson(Map<String, dynamic> json) {
    return GameRoom(
      id: json['id'],
      name: json['name'],
      creatorId: json['creatorId'],
      playerIds: List<String>.from(json['playerIds']),
      maxPlayers: json['maxPlayers'],
      gameMode: GameMode.values[json['gameMode']],
      isStarted: json['isStarted'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'creatorId': creatorId,
      'playerIds': playerIds,
      'maxPlayers': maxPlayers,
      'gameMode': gameMode.index,
      'isStarted': isStarted,
    };
  }
}

/// Player profile
class PlayerProfile {
  String id;
  String username;
  String? avatarUrl;
  int totalGamesPlayed;
  int totalWins;
  int totalLosses;
  double winRate;
  int ranking;

  PlayerProfile({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.totalGamesPlayed = 0,
    this.totalWins = 0,
    this.totalLosses = 0,
    this.winRate = 0,
    this.ranking = 0,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'],
      username: json['username'],
      avatarUrl: json['avatarUrl'],
      totalGamesPlayed: json['totalGamesPlayed'],
      totalWins: json['totalWins'],
      totalLosses: json['totalLosses'],
      winRate: json['winRate'],
      ranking: json['ranking'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatarUrl': avatarUrl,
      'totalGamesPlayed': totalGamesPlayed,
      'totalWins': totalWins,
      'totalLosses': totalLosses,
      'winRate': winRate,
      'ranking': ranking,
    };
  }
}
