// Ludo Game Screen
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../../../../models/ludo_models.dart';
import '../../../../providers/game_provider.dart';
import '../../../../services/sound_service.dart';
import '../../../../widgets/ludo_painters.dart';

class LudoGameScreen extends StatefulWidget {
  final List<Player> players;
  final GameMode gameMode;
  final LudoRuleSettings ruleSettings;
  final bool initialDiceFling;
  final int boardIndex;
  final bool continuousRolling;
  final double moveSpeed;

  const LudoGameScreen({
    Key? key,
    required this.players,
    required this.gameMode,
    this.ruleSettings = const LudoRuleSettings(),
    this.initialDiceFling = true,
    this.boardIndex = 0,
    this.continuousRolling = false,
    this.moveSpeed = 0.82,
  }) : super(key: key);

  @override
  State<LudoGameScreen> createState() => _LudoGameScreenState();
}

enum DiceRollMode { tap, fling }

class _LudoGameScreenState extends State<LudoGameScreen>
    with TickerProviderStateMixin {
  late AnimationController _diceAnimationController;
  late AnimationController _tokenAnimationController;
  late AnimationController _spawnAnimationController;
  late AnimationController _extraTurnController;
  late AnimationController _turnBlinkController;
  late GameProvider gameProvider;
  bool _undoDialogVisible = false;
  bool _debugOverlay = false;
  late DiceRollMode _diceRollMode;
  double? _diceLeft;
  double? _diceTop;
  Offset _flingVelocity = Offset.zero;
  double _lastAnimationValue = 0.0;
  List<Map<String, dynamic>> _activeKilledTokens = [];
  List<Map<String, dynamic>> _activeSpawnedTokens = [];
  int _initialDiceValue = 1;
  bool _isAutoRollingDice = false;
  bool _isAutoMovingToken = false;

  @override
  void initState() {
    super.initState();
    _diceRollMode = widget.initialDiceFling ? DiceRollMode.fling : DiceRollMode.tap;
    // Start with dice coordinates in center (width will be set in build)
    _diceLeft = null;
    _diceTop = null;
    _initialDiceValue = Random().nextInt(6) + 1;

    final double speedMultiplier = 2.0 - (widget.moveSpeed - 0.2) * 2.125;

    _diceAnimationController = AnimationController(
      duration: Duration(milliseconds: (800 * speedMultiplier).clamp(100.0, 3000.0).toInt()),
      vsync: this,
    );
    _diceAnimationController.addListener(() {
      if (_diceRollMode == DiceRollMode.fling && _flingVelocity != Offset.zero) {
        final t = _diceAnimationController.value;
        final dt = t - _lastAnimationValue;
        _lastAnimationValue = t;
        
        if (dt > 0) {
          final boardSize = MediaQuery.of(context).size.width;
          setState(() {
            // Apply velocity physics (0.35 scales velocity to sensible board movement)
            double newLeft = (_diceLeft ?? 0) + _flingVelocity.dx * dt * 0.35;
            double newTop = (_diceTop ?? 0) + _flingVelocity.dy * dt * 0.35;
            
            // Bounce off left/right
            if (newLeft < 0) {
              newLeft = 0;
              _flingVelocity = Offset(-_flingVelocity.dx * 0.75, _flingVelocity.dy); // 75% elasticity
            } else if (newLeft > boardSize - 60) {
              newLeft = boardSize - 60;
              _flingVelocity = Offset(-_flingVelocity.dx * 0.75, _flingVelocity.dy);
            }
            
            // Bounce off top/bottom
            if (newTop < 0) {
              newTop = 0;
              _flingVelocity = Offset(_flingVelocity.dx, -_flingVelocity.dy * 0.75);
            } else if (newTop > boardSize - 60) {
              newTop = boardSize - 60;
              _flingVelocity = Offset(_flingVelocity.dx, -_flingVelocity.dy * 0.75);
            }
            
            _diceLeft = newLeft;
            _diceTop = newTop;
            
            // Apply friction/drag deceleration
            _flingVelocity = _flingVelocity * (1.0 - dt * 2.2);
          });
        }
      }
    });
    _diceAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _flingVelocity = Offset.zero;
          _lastAnimationValue = 0.0;
        });
      }
    });
    _tokenAnimationController = AnimationController(
      duration: Duration(milliseconds: (600 * speedMultiplier).clamp(100.0, 3000.0).toInt()),
      vsync: this,
    );
    _spawnAnimationController = AnimationController(
      duration: Duration(milliseconds: (520 * speedMultiplier).clamp(100.0, 3000.0).toInt()),
      vsync: this,
    );
    _extraTurnController = AnimationController(
      duration: Duration(milliseconds: (450 * speedMultiplier).clamp(100.0, 3000.0).toInt()),
      vsync: this,
    );
    _extraTurnController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _extraTurnController.reverse();
      }
    });

    _turnBlinkController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    // Initialize game in provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      gameProvider = context.read<GameProvider>();
      gameProvider.initializeOfflineGame(
        players: widget.players,
        gameMode: widget.gameMode,
        rules: widget.ruleSettings,
      );
      gameProvider.startGame();
      // listen for lastMove events to trigger kill animation
      gameProvider.addListener(_onGameProviderChanged);
      // Trigger initial check for continuous rolling
      _onGameProviderChanged();
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
    _turnBlinkController.dispose();
    super.dispose();
  }

  void _onGameProviderChanged() {
    final prov = context.read<GameProvider>();
    final gs = prov.gameState;
    if (gs != null && gs.diceRolled && gs.diceValue > 0) {
      _initialDiceValue = gs.diceValue;
    }
    final lm = prov.lastMoveEvent;

    // Play dice animation when server rolled dice
    if (lm != null && lm['diceRoll'] != null) {
      try {
        final dr = lm['diceRoll'] as Map<String, dynamic>;
        final int val = dr['diceValue'] as int? ?? 0;
        if (val > 0) {
          _initialDiceValue = val;
        }
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

    // Continuous rolling check
    final state = prov.gameState;
    if (state != null && state.isPlaying) {
      final currentPlayer = state.currentPlayer;
      final isLocalPlayerTurn = widget.gameMode == GameMode.offline
          ? (currentPlayer.type == PlayerType.human)
          : (currentPlayer.id == prov.currentUserId);

      if (widget.continuousRolling && isLocalPlayerTurn && !state.diceRolled && !_isAutoRollingDice) {
        _isAutoRollingDice = true;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            final currentProv = context.read<GameProvider>();
            if (currentProv.gameState?.currentPlayer.id == currentPlayer.id &&
                !(currentProv.gameState?.diceRolled ?? true)) {
              _onDiceRoll(currentProv);
            }
          }
          _isAutoRollingDice = false;
        });
      }

      // Auto-move single token for local human player
      if (isLocalPlayerTurn && state.diceRolled && state.canMove && !_isAutoMovingToken) {
        final movableTokens = prov.getMovableTokens();
        final uniquePositions = movableTokens.map((t) => t.position).toSet();

        if (uniquePositions.length == 1) {
          _isAutoMovingToken = true;
          // Wait 900ms to let the dice animation finish
          Future.delayed(const Duration(milliseconds: 900), () {
            if (mounted) {
              final currentProv = context.read<GameProvider>();
              final currentState = currentProv.gameState;
              if (currentState != null &&
                  currentState.isPlaying &&
                  currentState.currentPlayer.id == currentPlayer.id &&
                  currentState.diceRolled &&
                  currentState.canMove) {
                
                final currentMovable = currentProv.getMovableTokens();
                if (currentMovable.isNotEmpty) {
                  currentProv.moveToken(currentMovable.first);
                  context.read<SoundService>().playSound(GameSound.tokenMove);
                }
              }
              _isAutoMovingToken = false;
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<GameProvider>(
        builder: (context, gameProvider, _) {
          if (gameProvider.pendingUndoRequest != null && !_undoDialogVisible) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              _undoDialogVisible = true;
              final pending = gameProvider.pendingUndoRequest as Map<String, dynamic>;
              await showModalBottomSheet(
                context: context,
                isDismissible: false,
                builder: (ctx) {
                  final requester = pending['playerId'] ?? 'Someone';
                  final votes = pending['votes'] as Map<String, dynamic>?;
                  final acceptCount = votes != null ? (votes['accept'] ?? 0) : 0;
                  final rejectCount = votes != null ? (votes['reject'] ?? 0) : 0;

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
              _undoDialogVisible = false;
            });
          }

          if (gameProvider.gameState == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final currentColor = gameProvider.currentPlayer?.color;
          List<Color> bgColors;
          switch (currentColor) {
            case PlayerColor.red:
              bgColors = [const Color(0xFFFFEBEB), const Color(0xFFFFCDD2), const Color(0xFFFFEBEB)];
              break;
            case PlayerColor.green:
              bgColors = [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9), const Color(0xFFE8F5E9)];
              break;
            case PlayerColor.yellow:
              bgColors = [const Color(0xFFFFFDE7), const Color(0xFFFFF59D), const Color(0xFFFFFDE7)];
              break;
            case PlayerColor.blue:
              bgColors = [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB), const Color(0xFFE3F2FD)];
              break;
            default:
              bgColors = [const Color(0xFFE5C599), const Color(0xFFC9A676), const Color(0xFFE5C599)];
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              // Tinted background based on current player
              gradient: LinearGradient(
                colors: bgColors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: gameProvider.hasGameEnded
                  ? _buildGameOverScreen(gameProvider)
                  : Stack(
                      children: [
                        _buildGameScreen(gameProvider),
                        if (_debugOverlay) _buildDebugOverlay(gameProvider),
                      ],
                    ),
            ),
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
          color: Colors.black.withAlpha(179),
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
    if (_diceLeft == null || _diceTop == null) {
      _diceLeft = (MediaQuery.of(context).size.width - 60) / 2;
      _diceTop = (MediaQuery.of(context).size.width - 60) / 2;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.brown.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Mode: ${_diceRollMode.toString().split('.').last.toUpperCase()} | Pos: (${_diceLeft?.toStringAsFixed(1)}, ${_diceTop?.toStringAsFixed(1)})',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.brown,
              ),
            ),
          ),
        ),
        const Spacer(),
        // Game board
        Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.width,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Board painting layer
                AnimatedBuilder(
                  animation: _turnBlinkController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: LudoBoardPainter(
                        gameState: gameProvider.gameState!,
                        boardSize: MediaQuery.of(context).size.width,
                        lastMove: gameProvider.lastMoveEvent,
                        showSafeCells:
                            gameProvider.gameState?.rules.showSafeCells ?? true,
                        boardIndex: widget.boardIndex,
                        turnHighlight: _turnBlinkController.value,
                      ),
                      size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.width),
                    );
                  },
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
                      size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.width),
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
                      size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.width),
                    );
                  },
                ),
                // Board tap layer (for selecting tokens) - below dice
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (details) => _onBoardTap(details, gameProvider),
                  ),
                ),
                // Dice on top - gets gesture priority
                Positioned(
                  left: _diceRollMode == DiceRollMode.tap 
                      ? (MediaQuery.of(context).size.width - 60) / 2 
                      : _diceLeft,
                  top: _diceRollMode == DiceRollMode.tap 
                      ? (MediaQuery.of(context).size.width - 60) / 2 
                      : _diceTop,
                  child: _buildCenterDice(gameProvider),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        // Bottom Controls
        _buildBottomControls(gameProvider),
        const SizedBox(height: 20),
      ],
    );
  }

  bool _shouldShowDot(int value, int row, int col) {
    if (value == 1) {
      return row == 1 && col == 1;
    }
    if (value == 2) {
      return (row == 0 && col == 0) || (row == 2 && col == 2);
    }
    if (value == 3) {
      return (row == 0 && col == 0) || (row == 1 && col == 1) || (row == 2 && col == 2);
    }
    if (value == 4) {
      return (row == 0 && col == 0) || (row == 0 && col == 2) ||
             (row == 2 && col == 0) || (row == 2 && col == 2);
    }
    if (value == 5) {
      return (row == 0 && col == 0) || (row == 0 && col == 2) ||
             (row == 1 && col == 1) ||
             (row == 2 && col == 0) || (row == 2 && col == 2);
    }
    if (value == 6) {
      return (row == 0 && col == 0) || (row == 0 && col == 2) ||
             (row == 1 && col == 0) || (row == 1 && col == 2) ||
             (row == 2 && col == 0) || (row == 2 && col == 2);
    }
    return false;
  }

  Widget _buildDiceFace(int value, Color dotColor) {
    final displayValue = value > 0 ? value : _initialDiceValue;

    return Padding(
      padding: const EdgeInsets.all(10.0), // Generous padding for dots
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(3, (row) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (col) {
              final show = _shouldShowDot(displayValue, row, col);
              return Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: show ? dotColor : Colors.transparent,
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildCenterDice(GameProvider gameProvider) {
    final canRoll = gameProvider.currentPlayer?.type == PlayerType.human &&
        !gameProvider.diceRolled &&
        !gameProvider.awaitingServer;

    final currentColor = gameProvider.currentPlayer?.color;
    Color diceColor;
    Color diceBorderColor;

    switch (currentColor) {
      case PlayerColor.red:
        diceColor = Colors.red[500]!;
        diceBorderColor = Colors.red[800]!;
        break;
      case PlayerColor.green:
        diceColor = Colors.green[500]!;
        diceBorderColor = Colors.green[900]!;
        break;
      case PlayerColor.yellow:
        diceColor = Colors.yellow[600]!;
        diceBorderColor = Colors.orange[800]!;
        break;
      case PlayerColor.blue:
        diceColor = Colors.blue[500]!;
        diceBorderColor = Colors.blue[900]!;
        break;
      default:
        diceColor = Colors.grey[500]!;
        diceBorderColor = Colors.grey[800]!;
    }

    final turnsAnimation = Tween<double>(begin: 0.0, end: 3.0).animate(
      CurvedAnimation(
        parent: _diceAnimationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (canRoll && _diceRollMode == DiceRollMode.tap)
          ? () => _onDiceRoll(gameProvider)
          : null,
      onPanUpdate: (_diceRollMode == DiceRollMode.fling)
          ? (details) {
              _flingVelocity = Offset.zero;
              _lastAnimationValue = 0.0;
              final boardSize = MediaQuery.of(context).size.width;
              setState(() {
                _diceLeft = (_diceLeft ?? 0) + details.delta.dx;
                _diceTop = (_diceTop ?? 0) + details.delta.dy;
                // Constrain within board
                _diceLeft = _diceLeft!.clamp(0.0, boardSize - 60);
                _diceTop = _diceTop!.clamp(0.0, boardSize - 60);
              });
            }
          : null,
      onPanEnd: (canRoll && _diceRollMode == DiceRollMode.fling)
          ? (details) {
              final velocity = details.velocity.pixelsPerSecond;
              if (velocity.distance > 50) { // Lowered threshold for emulator
                _flingVelocity = velocity;
                _onDiceRoll(gameProvider);
              }
            }
          : null,
      child: RotationTransition(
        turns: turnsAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: diceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: diceBorderColor, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 8,
                offset: Offset(2, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: _buildDiceFace(gameProvider.diceValue, Colors.white),
        ),
      ),
    );
  }

  Widget _buildBottomControls(GameProvider gameProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          _buildCircleButton(
            icon: Icons.arrow_back,
            onPressed: () => Navigator.pop(context),
          ),
          // Right side buttons
          Row(
            children: [
              _buildCircleButton(
                icon: _diceRollMode == DiceRollMode.tap ? Icons.touch_app : Icons.gesture,
                onPressed: () {
                  setState(() {
                    _diceRollMode = _diceRollMode == DiceRollMode.tap
                        ? DiceRollMode.fling
                        : DiceRollMode.tap;
                    if (_diceRollMode == DiceRollMode.tap) {
                      _diceLeft = null;
                      _diceTop = null;
                      _flingVelocity = Offset.zero;
                      _lastAnimationValue = 0.0;
                    }
                  });
                },
              ),
              const SizedBox(width: 12),
              _buildCircleButton(
                icon: Icons.settings,
                onPressed: () {
                  _showSettingsDialog();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onBoardTap(TapUpDetails details, GameProvider gameProvider) {
    if (!gameProvider.canMove ||
        gameProvider.currentPlayer?.type != PlayerType.human) {
      return;
    }

    final boardSize = MediaQuery.of(context).size.width;
    final cellSize = boardSize / 15;
    final localPosition = details.localPosition;

    final movableTokens = gameProvider.getMovableTokens();

    for (final token in movableTokens) {
      final gridCoord = LudoBoardPainter.gridCoordinateForToken(token);
      // gridCoord is cell index; +0.5 gives center (same as _drawToken)
      final cx = (gridCoord.dx + 0.5) * cellSize;
      final cy = (gridCoord.dy + 0.5) * cellSize;

      final distance = (Offset(cx, cy) - localPosition).distance;
      if (distance <= cellSize * 1.2) {
        gameProvider.moveToken(token);
        context.read<SoundService>().playSound(GameSound.tokenMove);
        break;
      }
    }
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFDEBCC), // Light warm color
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              height: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Game Settings',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Dice Rolling:',
                        style: TextStyle(fontSize: 18, color: Colors.black87),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                          elevation: 3,
                        ),
                        onPressed: () {
                          setModalState(() {
                            // Update local state to rebuild modal UI
                            _diceRollMode = _diceRollMode == DiceRollMode.tap
                                ? DiceRollMode.fling
                                : DiceRollMode.tap;
                            if (_diceRollMode == DiceRollMode.tap) {
                              _diceLeft = null;
                              _diceTop = null;
                            }
                          });
                          // Update parent state to apply setting to game
                          setState(() {});
                        },
                        child: Text(
                          _diceRollMode == DiceRollMode.tap ? 'Tap' : 'Fling',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.yellow[700],
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  // Removed old token panels and unused builders

  void _onDiceRoll(GameProvider gameProvider) {
    _lastAnimationValue = 0.0;
    // Play dice animation
    _diceAnimationController.forward(from: 0);

    // Play sound
    context.read<SoundService>().playSound(GameSound.diceRoll);

    // Roll dice
    gameProvider.rollDice();
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
        final fromPx = Offset(
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
          ..color = _colorFor(color)
              .withAlpha(((1.0 - 0.6 * progress) * 255).round());
        final radius = cellSize * 0.35 * (1.0 - 0.3 * progress);

        // shadow
        canvas.drawCircle(
          current + const Offset(2, 3),
          radius * 1.05,
          Paint()..color = Colors.black.withAlpha(77),
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

        final fromPx = Offset(
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
        final paint = Paint()
          ..color = _colorFor(color).withAlpha((0.95 * 255).round());
        final radius = cellSize * 0.35 * scale;

        // shadow
        canvas.drawCircle(
          current + const Offset(2, 3),
          radius * 1.05,
          Paint()..color = Colors.black.withAlpha(64),
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
