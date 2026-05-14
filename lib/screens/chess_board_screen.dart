import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../chess_logic.dart';
import '../theme/colors.dart';
import '../widgets/notification_bell.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../services/theme_service.dart';
import 'messaging_screen.dart';
import '../features/face_liveness/presentation/screens/liveness_permission_screen.dart';
import 'ludo_home_screen.dart';

class ChessBoardScreen extends StatefulWidget {
  const ChessBoardScreen({super.key});

  @override
  State<ChessBoardScreen> createState() => _ChessBoardScreenState();
}

class _ChessBoardScreenState extends State<ChessBoardScreen> {
  late ChessGame _game;
  int? _selectedRow;
  int? _selectedCol;
  List<List<int>> _validMoves = [];
  String? _message;

  @override
  void initState() {
    super.initState();
    _game = ChessGame();
  }

  void _tapSquare(int row, int col) {
    setState(() {
      // If tapping a valid move destination
      if (_validMoves.any((m) => m[0] == row && m[1] == col)) {
        bool moveSuccess = _game.makeMove(
          _selectedRow!,
          _selectedCol!,
          row,
          col,
        );
        if (moveSuccess) {
          _message =
              '${_game.turn == ChessColor.white ? 'Black' : 'White'} to move';
          _selectedRow = null;
          _selectedCol = null;
          _validMoves = [];
        }
        return;
      }

      // If tapping on an empty square
      if (_game.board[row][col] == null) {
        _selectedRow = null;
        _selectedCol = null;
        _validMoves = [];
        _message = null;
        return;
      }

      // If tapping on opponent's piece or empty
      if (_game.board[row][col]?.color != _game.turn) {
        _selectedRow = null;
        _selectedCol = null;
        _validMoves = [];
        _message = 'Select your piece';
        return;
      }

      // Select a new piece
      _selectedRow = row;
      _selectedCol = col;
      _validMoves = _game.getRawMoves(row, col);
      _message =
          '${_game.board[row][col]?.symbol ?? ''} selected - ${_validMoves.length} moves';
    });
  }

  void _resetGame() {
    setState(() {
      _game = ChessGame();
      _selectedRow = null;
      _selectedCol = null;
      _validMoves = [];
      _message = 'White to move';
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final userName = authService.currentUser?.username ?? 'Player';
    final theme = Theme.of(context);
    final appBarTheme = theme.appBarTheme;
    final appBarForeground =
        appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;

    final turnColor = _game.turn == ChessColor.white ? 'White' : 'Black';
    final inCheck = _game.isInCheck(_game.turn);

    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Chess Board'),
        elevation: 0.5,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                userName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const NotificationBell(),
          IconButton(
            tooltip: 'Face Liveness',
            icon: const Icon(Icons.verified_user_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LivenessPermissionScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Play Ludo',
            icon: const Icon(Icons.sports_esports),
            color: MessengerColors.messengerBlue,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LudoHomeScreen(),
                ),
              );
            },
          ),
          Consumer<ThemeService>(
            builder: (context, themeService, _) {
              final isDarkMode = themeService.isDarkMode;
              return IconButton(
                onPressed: () => themeService.toggleDarkMode(),
                icon: Icon(
                  isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: appBarForeground,
                ),
                tooltip: isDarkMode
                    ? 'Switch to light mode'
                    : 'Switch to dark mode',
              );
            },
          ),
          // Modern Messenger Icon with Gradient Background
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              children: [
                Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: MessengerColors.messengerGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: MessengerColors.messengerBlue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // Load message data before navigating
                        final messageService = context.read<MessageService>();
                        final authService = context.read<AuthService>();

                        if (authService.accessToken != null && mounted) {
                          messageService.fetchCurrentUserProfile(
                            authService.accessToken!,
                          );
                          messageService.fetchConversations(
                            authService.accessToken!,
                          );
                          messageService.fetchAllUsers(
                            authService.accessToken!,
                          );
                        }

                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const MessagingScreen(),
                          ),
                        );
                      },
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.messenger_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
                // Notification badge
                Positioned(
                  right: 0,
                  top: 0,
                  child: Consumer<MessageService>(
                    builder: (context, messageService, _) {
                      int unreadCount = messageService.conversations
                          .where(
                            (c) =>
                                c.lastMessage != null &&
                                c.lastMessage!.isNotEmpty,
                          )
                          .length;

                      if (unreadCount == 0) {
                        return const SizedBox.shrink();
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 22,
                          minHeight: 22,
                        ),
                        child: Center(
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              context.read<MessageService>().disconnectSocket();
              await context.read<AuthService>().logout();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            'Turn: $turnColor ${inCheck ? '(Check!)' : ''}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: inCheck ? Colors.red : theme.textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          if (_message != null)
            Text(_message!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 64,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                  ),
                  itemBuilder: (context, index) {
                    final row = index ~/ 8;
                    final col = index % 8;
                    final isDark = (row + col) % 2 == 1;
                    final isSelected =
                        row == _selectedRow && col == _selectedCol;
                    final isValidMove = _validMoves.any(
                      (m) => m[0] == row && m[1] == col,
                    );
                    final piece = _game.board[row][col];

                    Color bgColor;
                    final darkSquareColor = isDark
                        ? (isDark
                              ? (isDark
                                    ? (isDark
                                          ? theme.cardColor
                                          : theme.cardColor)
                                    : theme.cardColor)
                              : theme.cardColor)
                        : theme.cardColor;
                    final lightSquareColor = isDark
                        ? (isDark
                              ? theme.scaffoldBackgroundColor
                              : theme.scaffoldBackgroundColor)
                        : Colors.amber.shade100;

                    if (isSelected) {
                      bgColor = MessengerColors.messengerBlue;
                    } else if (isValidMove) {
                      bgColor = Colors.yellow.shade600;
                    } else {
                      bgColor = isDark
                          ? const Color(0xFF2B2B2B)
                          : Colors.amber.shade100;
                      if (isDark == false) {
                        bgColor = isDark
                            ? const Color(0xFF2B2B2B)
                            : Colors.amber.shade100;
                      }
                      if (isDark) {
                        // alternate dark/light square
                        bgColor = isDark
                            ? (isDark
                                  ? const Color(0xFF2B2B2B)
                                  : const Color(0xFF111315))
                            : bgColor;
                      }
                      // simpler: choose by parity
                      bgColor = (row + col) % 2 == 1
                          ? const Color(0xFF2B2B2B)
                          : const Color(0xFF111315);
                      if (!isDark) {
                        bgColor = (row + col) % 2 == 1
                            ? Colors.brown.shade700
                            : Colors.amber.shade100;
                      }
                    }

                    return GestureDetector(
                      onTap: () => _tapSquare(row, col),
                      child: Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          border: Border.all(
                            color: isValidMove
                                ? Colors.redAccent
                                : theme.dividerColor,
                            width: isValidMove ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            piece?.symbol ?? '',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color:
                                  theme.textTheme.bodyLarge?.color ??
                                  (isDark ? Colors.white : Colors.black),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _resetGame,
            icon: const Icon(Icons.refresh),
            label: const Text('New Game'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
