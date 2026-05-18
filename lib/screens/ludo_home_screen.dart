// Ludo Home Screen - Main Menu
import 'package:flutter/material.dart';
import '../models/ludo_models.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import 'ludo_game_screen.dart';
import 'ludo_lobby_screen.dart';
import '../widgets/cancel_match_button.dart';

class LudoHomeScreen extends StatefulWidget {
  const LudoHomeScreen({Key? key}) : super(key: key);

  @override
  State<LudoHomeScreen> createState() => _LudoHomeScreenState();
}

class _LudoHomeScreenState extends State<LudoHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<GameProvider>(
        builder: (context, gp, child) {
          // if matchmaking produced a room, navigate to game screen once
          if (gp.matchedRoom != null && !_navigating) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _navigating = true;
              try {
                // extract players if provided, otherwise navigate with empty list
                final data = gp.matchedRoom as Map<String, dynamic>;
                final playersData = data['players'] as List<dynamic>?;
                List<Player> players = [];
                if (playersData != null) {
                  players = playersData.map((p) {
                    return Player(
                      id: p['id'] ?? p['playerId'] ?? UniqueKey().toString(),
                      name: p['name'] ?? 'Player',
                      color:
                          PlayerColor.values[(p['colorIndex'] ?? 0) %
                              PlayerColor.values.length],
                      type: PlayerType.human,
                    );
                  }).toList();
                }

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LudoGameScreen(
                      players: players,
                      gameMode: GameMode.online,
                    ),
                  ),
                );
              } catch (e) {
                // fallback: open empty online game screen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        LudoGameScreen(players: [], gameMode: GameMode.online),
                  ),
                );
              }
            });
          }

          final children = <Widget>[
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.purple[400]!,
                    Colors.blue[600]!,
                    Colors.indigo[700]!,
                  ],
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Game title with animation
                        ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.8,
                            end: 1.0,
                          ).animate(_animationController),
                          child: const Text(
                            '🎲 LUDO GAME',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'The Classic Board Game',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Game mode buttons
                        _buildGameModeButton(
                          context,
                          'Play Offline',
                          Icons.people,
                          Colors.orange,
                          () => _showOfflineOptions(context),
                        ),
                        const SizedBox(height: 16),

                        _buildGameModeButton(
                          context,
                          'Play Online',
                          Icons.cloud,
                          Colors.green,
                          () => _showOnlineOptions(context),
                        ),
                        const SizedBox(height: 16),

                        ElevatedButton(
                          onPressed: () {
                            final gpLocal = context.read<GameProvider>();
                            gpLocal.quickMatch();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Searching for quick match...'),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 16,
                            ),
                            backgroundColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Quick Match',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildGameModeButton(
                          context,
                          'VS Computer',
                          Icons.computer,
                          Colors.red,
                          () => _startVsComputer(context),
                        ),
                        const SizedBox(height: 16),

                        _buildGameModeButton(
                          context,
                          'Settings',
                          Icons.settings,
                          Colors.teal,
                          () => _showSettings(context),
                        ),
                        const SizedBox(height: 16),

                        _buildGameModeButton(
                          context,
                          'Leaderboard',
                          Icons.leaderboard,
                          Colors.amber,
                          () => _showLeaderboard(context),
                        ),
                        const SizedBox(height: 40),

                        // Footer
                        const Text(
                          'Classic Indian Board Game',
                          style: TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ];

          if (gp.isSearchingMatch) {
            children.add(
              Positioned.fill(
                child: Container(
                  color: Colors.black45,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        const Text(
                          'Searching for match...',
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        CancelMatchButton(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return Stack(children: children);
        },
      ),
    );
  }

  Widget _buildGameModeButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOfflineOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offline Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('2 Players'),
              onTap: () {
                Navigator.pop(context);
                _startOfflineGame(context, 2);
              },
            ),
            ListTile(
              title: const Text('4 Players'),
              onTap: () {
                Navigator.pop(context);
                _startOfflineGame(context, 4);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showOnlineOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Online Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Create Room'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement create room
              },
            ),
            ListTile(
              title: const Text('Join Room'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LudoLobbyScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startVsComputer(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('VS Computer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Easy'),
              onTap: () {
                Navigator.pop(context);
                _startVsComputerGame(context, DifficultyLevel.easy);
              },
            ),
            ListTile(
              title: const Text('Medium'),
              onTap: () {
                Navigator.pop(context);
                _startVsComputerGame(context, DifficultyLevel.medium);
              },
            ),
            ListTile(
              title: const Text('Hard'),
              onTap: () {
                Navigator.pop(context);
                _startVsComputerGame(context, DifficultyLevel.hard);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startOfflineGame(BuildContext context, int playerCount) {
    final players = <Player>[];

    for (int i = 0; i < playerCount; i++) {
      players.add(
        Player(
          id: 'player_$i',
          name: 'Player ${i + 1}',
          color: PlayerColor.values[i],
          type: PlayerType.human,
        ),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LudoGameScreen(players: players, gameMode: GameMode.offline),
      ),
    );
  }

  void _startVsComputerGame(BuildContext context, DifficultyLevel difficulty) {
    final players = [
      Player(
        id: 'player_human',
        name: 'You',
        color: PlayerColor.red,
        type: PlayerType.human,
      ),
      Player(
        id: 'player_ai',
        name: 'Computer',
        color: PlayerColor.blue,
        type: PlayerType.ai,
        difficulty: difficulty,
      ),
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LudoGameScreen(players: players, gameMode: GameMode.vsComputer),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            ListTile(
              title: Text('Sound Effects'),
              trailing: Icon(Icons.volume_up),
            ),
            ListTile(
              title: Text('Background Music'),
              trailing: Icon(Icons.music_note),
            ),
            ListTile(title: Text('Vibration'), trailing: Icon(Icons.vibration)),
            ListTile(title: Text('Language'), trailing: Icon(Icons.language)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLeaderboard(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leaderboard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            ListTile(title: Text('1. Player Name'), trailing: Text('1500 pts')),
            ListTile(title: Text('2. Player Name'), trailing: Text('1200 pts')),
            ListTile(title: Text('3. Player Name'), trailing: Text('900 pts')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
