// Ludo Game Screen
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../models/ludo_models.dart';
import '../providers/game_provider.dart';
import '../services/sound_service.dart';
import '../widgets/ludo_painters.dart';

class LudoGameScreen extends StatefulWidget {
  final List<Player> players;
  final GameMode gameMode;

  const LudoGameScreen({
    Key? key,
    required this.players,
    required this.gameMode,
  }) : super(key: key);

  @override
  State<LudoGameScreen> createState() => _LudoGameScreenState();
}

class _LudoGameScreenState extends State<LudoGameScreen>
    with TickerProviderStateMixin {
  late AnimationController _diceAnimationController;
  late AnimationController _tokenAnimationController;
  late AnimationController _spawnAnimationController;
  late AnimationController _extraTurnController;
  late GameProvider gameProvider;
  bool _undoDialogVisible = false;
  bool _debugOverlay = false;
  List<Map<String, dynamic>> _activeKilledTokens = [];
  List<Map<String, dynamic>> _activeSpawnedTokens = [];

  @override
  void initState() {
    super.initState();
    _diceAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _tokenAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _spawnAnimationController = AnimationController(
      duration: const Duration(milliseconds: 520),
      vsync: this,
    );
    _extraTurnController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _extraTurnController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _extraTurnController.reverse();
      }
    });

    // Initialize game in provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      gameProvider = context.read<GameProvider>();
      gameProvider.initializeOfflineGame(
        players: widget.players,
        gameMode: widget.gameMode,
      );
      gameProvider.startGame();
      // listen for lastMove events to trigger kill animation
      gameProvider.addListener(_onGameProviderChanged);
    });
  }

  @override
  void dispose() {
    _diceAnimationController.dispose();
    _tokenAnimationController.dispose();
    try {
      gameProvider.removeListener(_onGameProviderChanged);
    } catch (e) {
      // ignore
    }
    _spawnAnimationController.dispose();
    _extraTurnController.dispose();
    super.dispose();
  }

  void _onGameProviderChanged() {
    final prov = context.read<GameProvider>();
    final lm = prov.lastMoveEvent;

    // Play dice animation when server rolled dice
    if (lm != null && lm['diceRoll'] != null) {
      try {
        final dr = lm['diceRoll'] as Map<String, dynamic>;
        final int val = dr['diceValue'] as int? ?? 0;
        // play dice animation and sound
        _diceAnimationController.forward(from: 0);
        context.read<SoundService>().playSound(GameSound.diceRoll);
      } catch (e) {}
    }

    if (lm != null && lm['killedTokens'] != null) {
      try {
        final List<dynamic> kt = lm['killedTokens'] as List<dynamic>;
        _activeKilledTokens = [];
        for (final k in kt) {
          final Map<String, dynamic> km = Map<String, dynamic>.from(k as Map);
          // find player color from current game state
          String pid = km['playerId'] as String? ?? '';
          PlayerColor col = PlayerColor.red;
          try {
            final p = prov.gameState?.players.firstWhere((p) => p.id == pid);
            if (p != null) col = p.color;
          } catch (e) {}
          _activeKilledTokens.add({
            'playerId': pid,
            'tokenId': km['tokenId'],
            'from': km['from'],
            'to': km['to'],
            'color': col,
          });
        }
        // start token animation
        _tokenAnimationController.forward(from: 0);
      } catch (e) {
        // ignore
      }
    }

    if (lm != null && lm['penalties'] != null) {
      try {
        final List<dynamic> pt = lm['penalties'] as List<dynamic>;
        for (final p in pt) {
          final Map<String, dynamic> pm = Map<String, dynamic>.from(p as Map);
          final String pid = pm['playerId'] as String? ?? '';
          final String type = pm['type'] as String? ?? '';
          if (type == 'three_consecutive_sixes') {
            final playerName =
                prov.gameState?.players.firstWhere((x) => x.id == pid).name ??
                'Player';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '$playerName lost extra turn due to three consecutive 6s',
                ),
              ),
            );
          }
        }
      } catch (e) {
        // ignore
      }
    }

    if (lm != null && lm['spawnedTokens'] != null) {
      try {
        final List<dynamic> st = lm['spawnedTokens'] as List<dynamic>;
        _activeSpawnedTokens = [];
        for (final s in st) {
          final Map<String, dynamic> sm = Map<String, dynamic>.from(s as Map);
          String pid = sm['playerId'] as String? ?? '';
          PlayerColor col = PlayerColor.red;
          try {
            final p = prov.gameState?.players.firstWhere((p) => p.id == pid);
            if (p != null) col = p.color;
          } catch (e) {}
          _activeSpawnedTokens.add({
            'playerId': pid,
            'tokenId': sm['tokenId'],
            'from': sm['from'],
            'to': sm['to'],
            'color': col,
          });
        }
        _spawnAnimationController.forward(from: 0);
      } catch (e) {
        // ignore
      }
    }

    if (lm != null && lm['extraTurn'] != null && lm['extraTurn'] == true) {
      try {
        final playerName = prov.gameState?.currentPlayer.name ?? 'Player';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$playerName earned an extra turn!')),
        );
        _extraTurnController.forward(from: 0);
      } catch (e) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ludo Game'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.pause),
            onPressed: () {
              context.read<GameProvider>().pauseGame();
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Consumer<GameProvider>(
        builder: (context, gameProvider, _) {
          // Show undo/vote dialog when server signals a pending undo
          if (gameProvider.pendingUndoRequest != null && !_undoDialogVisible) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              _undoDialogVisible = true;
              final pending =
                  gameProvider.pendingUndoRequest as Map<String, dynamic>;
              await showModalBottomSheet(
                context: context,
                isDismissible: false,
                builder: (ctx) {
                  // build vote UI with live counts if provided
                  final requester = pending['playerId'] ?? 'Someone';
                  final votes = pending['votes'] as Map<String, dynamic>?;
                  final acceptCount = votes != null
                      ? (votes['accept'] ?? 0)
                      : 0;
                  final rejectCount = votes != null
                      ? (votes['reject'] ?? 0)
                      : 0;
                  final expiresAt = pending['expiresAt'];

                  return Container(
                    padding: const EdgeInsets.all(12),
                    height: 220,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Undo requested by $requester'),
                        const SizedBox(height: 8),
                        Text('Accept: $acceptCount  Reject: $rejectCount'),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                              },
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
              // sheet closed
              _undoDialogVisible = false;
            });
          }

          if (gameProvider.gameState == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return gameProvider.hasGameEnded
              ? _buildGameOverScreen(gameProvider)
              : Stack(
                  children: [
                    _buildGameScreen(gameProvider),
                    if (_debugOverlay) _buildDebugOverlay(gameProvider),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildDebugOverlay(GameProvider gameProvider) {
    final gs = gameProvider.gameState!;
    final tokenLines = <String>[];
    for (final p in gs.players) {
      for (final t in p.tokens) {
        final coord = LudoBoardPainter.gridCoordinateForToken(t);
        tokenLines.add(
          '${p.name}:${t.id} color=${p.color.index} pos=${t.position} -> grid=(${coord.dx.toStringAsFixed(1)},${coord.dy.toStringAsFixed(1)})',
        );
      }
    }

    // show expected start indices per color
    final startLines = <String>[];
    for (final color in PlayerColor.values) {
      final startIndex = BoardConfig.playerStartPositions[color] ?? -1;
      final tmpToken = Token(id: 0, playerColor: color, position: startIndex);
      final coord = LudoBoardPainter.gridCoordinateForToken(tmpToken);
      startLines.add(
        'Start ${color.toString().split('.').last}: idx=$startIndex grid=(${coord.dx.toStringAsFixed(1)},${coord.dy.toStringAsFixed(1)})',
      );
    }

    // safe positions
    final safeLine = 'Safe positions: ${BoardConfig.safePositions.join(', ')}';

    return Positioned(
      left: 8,
      top: 80,
      child: Container(
        width: 340,
        height: 240,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white, fontSize: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DEBUG: Raw gameState'),
                const SizedBox(height: 6),
                Text(gs.toJson().toString()),
                const Divider(color: Colors.white54),
                const Text('Token positions -> grid coords'),
                const SizedBox(height: 6),
                ...tokenLines.map((s) => Text(s)).toList(),
                const Divider(color: Colors.white54),
                const Text('Start indices per color'),
                const SizedBox(height: 6),
                ...startLines.map((s) => Text(s)).toList(),
                const SizedBox(height: 6),
                Text(safeLine),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameScreen(GameProvider gameProvider) {
    return Column(
      children: [
        // Game board
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                height: 450,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      painter: LudoBoardPainter(
                        gameState: gameProvider.gameState!,
                        boardSize: 400,
                        lastMove: gameProvider.lastMoveEvent,
                      ),
                      size: const Size(400, 450),
                    ),
                    // Kill animation overlay
                    AnimatedBuilder(
                      animation: _tokenAnimationController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: KillAnimationPainter(
                            progress: _tokenAnimationController.value,
                            killedTokens: _activeKilledTokens,
                            gameState: gameProvider.gameState!,
                          ),
                          size: const Size(400, 450),
                        );
                      },
                    ),
                    // Spawn animation overlay
                    AnimatedBuilder(
                      animation: _spawnAnimationController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: SpawnAnimationPainter(
                            progress: _spawnAnimationController.value,
                            spawnedTokens: _activeSpawnedTokens,
                            gameState: gameProvider.gameState!,
                          ),
                          size: const Size(400, 450),
                        );
                      },
                    ),
                    // Color buttons positioned around the board
                    Positioned(
                      left: -20,
                      top: -30,
                      child: SizedBox(
                        width: 96,
                        child: _buildColorButton(
                          PlayerColor.green,
                          gameProvider,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -20,
                      top: -30,
                      child: SizedBox(
                        width: 96,
                        child: _buildColorButton(
                          PlayerColor.yellow,
                          gameProvider,
                        ),
                      ),
                    ),
                    Positioned(
                      left: -20,
                      bottom: -30,
                      child: SizedBox(
                        width: 96,
                        child: _buildColorButton(PlayerColor.red, gameProvider),
                      ),
                    ),
                    Positioned(
                      right: -20,
                      bottom: -30,
                      child: SizedBox(
                        width: 96,
                        child: _buildColorButton(
                          PlayerColor.blue,
                          gameProvider,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Dice and controls
        _buildGameControls(gameProvider),

        // Tokens panel
        _buildTokensPanel(gameProvider),
      ],
    );
  }

  Widget _buildPlayerInfo(GameProvider gameProvider) {
    final currentPlayer = gameProvider.currentPlayer;
    if (currentPlayer == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Turn: ${currentPlayer.name}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Dice: ${gameProvider.diceValue > 0 ? gameProvider.diceValue : 'Roll'}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTurnOrderStrip(PlayerColor currentColor) {
    const turnOrder = [
      PlayerColor.red,
      PlayerColor.green,
      PlayerColor.yellow,
      PlayerColor.blue,
    ];

    return SizedBox(
      width: 190,
      child: Row(
        children: turnOrder.map((color) {
          final isActive = color == currentColor;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _buildTurnColorBox(
                color,
                isActive: isActive,
                label: _playerColorLabel(color),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTurnColorBox(
    PlayerColor color, {
    required bool isActive,
    required String label,
  }) {
    final colorValue = _getPlayerColorValue(color);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 48,
      decoration: BoxDecoration(
        color: colorValue.withOpacity(isActive ? 1.0 : 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? Colors.black87 : colorValue.withOpacity(0.85),
          width: isActive ? 2.5 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: colorValue.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : const [],
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  String _playerColorLabel(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return 'Red';
      case PlayerColor.green:
        return 'Green';
      case PlayerColor.yellow:
        return 'Yellow';
      case PlayerColor.blue:
        return 'Blue';
    }
  }

  Widget _buildColorButton(PlayerColor color, GameProvider gameProvider) {
    final isActive = gameProvider.currentPlayer?.color == color;
    final colorValue = _getPlayerColorValue(color);

    return Stack(
      alignment: Alignment.center,
      children: [
        _buildTurnColorBox(
          color,
          isActive: isActive,
          label: _playerColorLabel(color),
        ),
        if (isActive)
          Positioned(
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${gameProvider.currentPlayer?.name ?? ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Dice: ${gameProvider.diceValue > 0 ? gameProvider.diceValue : 'Roll'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGameControls(GameProvider gameProvider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Dice button with extra-turn pop animation
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.08).animate(
              CurvedAnimation(
                parent: _extraTurnController,
                curve: Curves.elasticOut,
              ),
            ),
            child: ElevatedButton(
              onPressed:
                  (!gameProvider.diceRolled && !gameProvider.awaitingServer)
                  ? () {
                      _onDiceRoll(gameProvider);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Roll Dice',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),

          // Undo button
          ElevatedButton(
            onPressed: () {
              gameProvider.requestUndo();
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              backgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Undo',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _onDiceRoll(GameProvider gameProvider) {
    // Play dice animation
    _diceAnimationController.forward(from: 0);

    // Play sound
    context.read<SoundService>().playSound(GameSound.diceRoll);

    // Roll dice
    final diceValue = gameProvider.rollDice();

    // Handle AI turn if needed
    if (gameProvider.currentPlayer?.type == PlayerType.ai) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        gameProvider.autoPlayAITurn();
      });
    }
  }

  Widget _buildTokensPanel(GameProvider gameProvider) {
    final movableTokens = gameProvider.getMovableTokens();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Token to Move',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          movableTokens.isEmpty
              ? const Text('No movable tokens')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: movableTokens.map((token) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildTokenCard(token, gameProvider),
                      );
                    }).toList(),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildTokenCard(Token token, GameProvider gameProvider) {
    final color = _getPlayerColorValue(token.playerColor);

    return GestureDetector(
      onTap: gameProvider.awaitingServer
          ? null
          : () {
              gameProvider.moveToken(token);
              context.read<SoundService>().playSound(GameSound.tokenMove);
            },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.3),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  '${token.id + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pos: ${token.position}',
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPlayerColorValue(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return Colors.red;
      case PlayerColor.green:
        return Colors.green;
      case PlayerColor.yellow:
        return Colors.yellow[700]!;
      case PlayerColor.blue:
        return Colors.blue;
    }
  }

  Widget _buildGameOverScreen(GameProvider gameProvider) {
    final winner = gameProvider.winner;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.celebration,
            size: 100,
            color: _getPlayerColorValue(winner?.color ?? PlayerColor.red),
          ),
          const SizedBox(height: 20),
          Text(
            '${winner?.name} Wins!',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              gameProvider.resetGame();
              // Navigate back
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Play Again',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              backgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Back to Menu',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// Painter for kill animation overlay
class KillAnimationPainter extends CustomPainter {
  final double progress; // 0.0 -> 1.0
  final List<Map<String, dynamic>> killedTokens;
  final GameState gameState;

  KillAnimationPainter({
    required this.progress,
    required this.killedTokens,
    required this.gameState,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (killedTokens.isEmpty) return;
    final double actualSize = min(size.width, size.height);
    final double cellSize = actualSize / 15;
    final boardOffset = Offset(
      (size.width - actualSize) / 2,
      (size.height - actualSize) / 2,
    );

    for (final kt in killedTokens) {
      try {
        final int fromPos = kt['from'] as int? ?? -1;
        final PlayerColor color = kt['color'] as PlayerColor;
        if (fromPos < 0) continue;

        // From coordinate in grid
        Offset fromGrid;
        if (fromPos >= 52) {
          // home stretch
          final tmp = Token(
            id: kt['tokenId'] as int,
            playerColor: color,
            position: fromPos,
          );
          fromGrid = LudoBoardPainter.gridCoordinateForToken(tmp);
        } else {
          final tmp = Token(
            id: kt['tokenId'] as int,
            playerColor: color,
            position: fromPos,
          );
          fromGrid = LudoBoardPainter.gridCoordinateForToken(tmp);
        }

        // To coordinate: home base spot for that player
        final homeTmp = Token(
          id: kt['tokenId'] as int,
          playerColor: color,
          position: -1,
        );
        final toGrid = LudoBoardPainter.gridCoordinateForToken(homeTmp);

        // convert to pixel centers
        final fromPx =
            Offset(
              (fromGrid.dx + 0.5) * cellSize,
              (fromGrid.dy + 0.5) * cellSize,
            ) +
            boardOffset;
        final toPx =
            Offset((toGrid.dx + 0.5) * cellSize, (toGrid.dy + 0.5) * cellSize) +
            boardOffset;

        final current = Offset.lerp(
          fromPx,
          toPx,
          Curves.easeInOut.transform(progress),
        )!;

        // draw token circle following progress
        final paint = Paint()
          ..color = _colorFor(color).withOpacity(1.0 - 0.6 * progress);
        final radius = cellSize * 0.35 * (1.0 - 0.3 * progress);

        // shadow
        canvas.drawCircle(
          current + const Offset(2, 3),
          radius * 1.05,
          Paint()..color = Colors.black.withOpacity(0.3),
        );
        canvas.drawCircle(current, radius, paint);
        canvas.drawCircle(
          current,
          radius,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } catch (e) {
        // ignore
      }
    }
  }

  Color _colorFor(PlayerColor c) {
    switch (c) {
      case PlayerColor.red:
        return Colors.red;
      case PlayerColor.green:
        return Colors.green;
      case PlayerColor.yellow:
        return Colors.yellow[700]!;
      case PlayerColor.blue:
        return Colors.blue;
    }
  }

  @override
  bool shouldRepaint(covariant KillAnimationPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.killedTokens != killedTokens;
  }
}

// Painter for spawn (open-on-6) animation
class SpawnAnimationPainter extends CustomPainter {
  final double progress; // 0.0 -> 1.0
  final List<Map<String, dynamic>> spawnedTokens;
  final GameState gameState;

  SpawnAnimationPainter({
    required this.progress,
    required this.spawnedTokens,
    required this.gameState,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (spawnedTokens.isEmpty) return;
    final double actualSize = min(size.width, size.height);
    final double cellSize = actualSize / 15;
    final boardOffset = Offset(
      (size.width - actualSize) / 2,
      (size.height - actualSize) / 2,
    );

    for (final st in spawnedTokens) {
      try {
        final int toPos = st['to'] as int? ?? -1;
        final PlayerColor color = st['color'] as PlayerColor;
        if (toPos < 0) continue;

        final homeTmp = Token(
          id: st['tokenId'] as int,
          playerColor: color,
          position: -1,
        );
        final fromGrid = LudoBoardPainter.gridCoordinateForToken(homeTmp);
        final toTmp = Token(
          id: st['tokenId'] as int,
          playerColor: color,
          position: toPos,
        );
        final toGrid = LudoBoardPainter.gridCoordinateForToken(toTmp);

        final fromPx =
            Offset(
              (fromGrid.dx + 0.5) * cellSize,
              (fromGrid.dy + 0.5) * cellSize,
            ) +
            boardOffset;
        final toPx =
            Offset((toGrid.dx + 0.5) * cellSize, (toGrid.dy + 0.5) * cellSize) +
            boardOffset;

        final eased = Curves.easeOut.transform(progress);
        final current = Offset.lerp(fromPx, toPx, eased)!;

        // scale/pop effect
        final scale = 0.6 + 0.6 * eased;
        final paint = Paint()..color = _colorFor(color).withOpacity(0.95);
        final radius = cellSize * 0.35 * scale;

        // shadow
        canvas.drawCircle(
          current + const Offset(2, 3),
          radius * 1.05,
          Paint()..color = Colors.black.withOpacity(0.25),
        );
        canvas.drawCircle(current, radius, paint);
        canvas.drawCircle(
          current,
          radius,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } catch (e) {
        // ignore
      }
    }
  }

  Color _colorFor(PlayerColor c) {
    switch (c) {
      case PlayerColor.red:
        return Colors.red;
      case PlayerColor.green:
        return Colors.green;
      case PlayerColor.yellow:
        return Colors.yellow[700]!;
      case PlayerColor.blue:
        return Colors.blue;
    }
  }

  @override
  bool shouldRepaint(covariant SpawnAnimationPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.spawnedTokens != spawnedTokens;
  }
}
