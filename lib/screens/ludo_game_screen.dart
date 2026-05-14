// Ludo Game Screen
import 'package:flutter/material.dart';
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
  late GameProvider gameProvider;

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

    // Initialize game in provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      gameProvider = context.read<GameProvider>();
      gameProvider.initializeOfflineGame(
        players: widget.players,
        gameMode: widget.gameMode,
      );
      gameProvider.startGame();
    });
  }

  @override
  void dispose() {
    _diceAnimationController.dispose();
    _tokenAnimationController.dispose();
    super.dispose();
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
          if (gameProvider.gameState == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return gameProvider.hasGameEnded
              ? _buildGameOverScreen(gameProvider)
              : _buildGameScreen(gameProvider);
        },
      ),
    );
  }

  Widget _buildGameScreen(GameProvider gameProvider) {
    return Column(
      children: [
        // Current player info
        _buildPlayerInfo(gameProvider),

        // Game board
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: CustomPaint(
                painter: LudoBoardPainter(
                  gameState: gameProvider.gameState!,
                  boardSize: 400,
                ),
                size: const Size(400, 450),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          _buildPlayerColorIndicator(currentPlayer.color),
        ],
      ),
    );
  }

  Widget _buildPlayerColorIndicator(PlayerColor color) {
    Color colorValue;
    switch (color) {
      case PlayerColor.red:
        colorValue = Colors.red;
        break;
      case PlayerColor.green:
        colorValue = Colors.green;
        break;
      case PlayerColor.yellow:
        colorValue = Colors.yellow;
        break;
      case PlayerColor.blue:
        colorValue = Colors.blue;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colorValue,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildGameControls(GameProvider gameProvider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Dice button
          ElevatedButton(
            onPressed: !gameProvider.diceRolled
                ? () {
                    _onDiceRoll(gameProvider);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
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

          // Undo button
          ElevatedButton(
            onPressed: () {
              // TODO: Implement undo
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
      onTap: () {
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
