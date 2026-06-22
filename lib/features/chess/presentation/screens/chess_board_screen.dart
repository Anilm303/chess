import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../chess_logic.dart';
import '../../../../theme/colors.dart';
import '../../../../widgets/notification_bell.dart';
import '../../../../services/auth_service.dart';
import '../../../chat/data/services/message_service.dart';
import '../../../../services/theme_service.dart';
import '../../../chat/presentation/screens/messaging_screen.dart';
import '../../../face_liveness/presentation/screens/liveness_permission_screen.dart';
import '../../../ludo/presentation/screens/ludo_home_screen.dart';
import '../../../tournament/presentation/screens/tournament_list_screen.dart';
import '../../../../services/socket_service.dart';
import '../../../../features/auth/data/services/auth_service.dart';

class ChessBoardScreen extends StatefulWidget {
  final String? tournamentId;
  final ChessColor? myColor;

  const ChessBoardScreen({
    super.key,
    this.tournamentId,
    this.myColor,
  });

  @override
  State<ChessBoardScreen> createState() => _ChessBoardScreenState();
}

class _ChessBoardScreenState extends State<ChessBoardScreen> {
  late ChessGame _game;
  int? _selectedRow;
  int? _selectedCol;
  List<List<int>> _validMoves = [];
  String? _message;
  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    _game = ChessGame();
    if (widget.tournamentId != null) {
      _setupOnlinePlay();
    }
  }

  void _setupOnlinePlay() {
    final auth = context.read<AuthService>();
    final token = auth.accessToken ?? '';
    
    debugPrint('DEBUG: Setting up online play for tournament ${widget.tournamentId}');
    
    _socketService.connect(
      token: token,
      onMessage: (_) {},
      onConnected: () {
        debugPrint('DEBUG: Socket connected, joining room chess_${widget.tournamentId}');
        _socketService.send('chess_join', {'tournament_id': widget.tournamentId});
      },
      onDisconnected: () {
        debugPrint('DEBUG: Socket disconnected');
      },
      eventHandlers: {
        'chess_move_received': (data) {
          debugPrint('DEBUG: Received remote move: $data');
          if (mounted) {
            setState(() {
              _game.makeMove(
                data['fromRow'],
                data['fromCol'],
                data['toRow'],
                data['toCol'],
              );
              _message = '${_game.turn == ChessColor.white ? 'White' : 'Black'} to move';
            });
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }

  void _tapSquare(int row, int col) {
    // CRUCIAL: Online Game Logic - Strictly enforce color and turn
    if (widget.tournamentId != null) {
      // 1. Check if it's the current player's turn
      if (_game.turn != widget.myColor) {
        setState(() => _message = "Waiting for opponent's move...");
        return;
      }
      
      // 2. If selecting a new piece, ensure it's their own color
      if (_selectedRow == null) {
        final piece = _game.board[row][col];
        if (piece != null && piece.color != widget.myColor) {
          setState(() => _message = "You can only move your own pieces!");
          return;
        }
      }
    }

    setState(() {
      // If tapping a valid move destination
      if (_validMoves.any((m) => m[0] == row && m[1] == col)) {
        final fromRow = _selectedRow!;
        final fromCol = _selectedCol!;
        
        bool moveSuccess = _game.makeMove(
          fromRow,
          fromCol,
          row,
          col,
        );
        
        if (moveSuccess) {
          // Send move to server if online
          if (widget.tournamentId != null) {
            _socketService.send('chess_move', {
              'tournament_id': widget.tournamentId,
              'fromRow': fromRow,
              'fromCol': fromCol,
              'toRow': row,
              'toCol': col,
            });
          }

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
          IconButton(
            tooltip: 'Tournaments',
            icon: const Icon(Icons.emoji_events_outlined),
            color: Colors.amber.shade700,
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const TournamentListScreen()));
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
                tooltip:
                    isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
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
                        color: MessengerColors.messengerBlue.withAlpha(77),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final messageService = context.read<MessageService>();
                        final authService = context.read<AuthService>();
                        final token = authService.accessToken;
                        if (token != null) {
                          messageService.fetchCurrentUserProfile(token);
                          messageService.fetchConversations(token);
                          messageService.fetchAllUsers(token);
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
                              color: Colors.red.withAlpha(102),
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
          if (widget.tournamentId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: widget.myColor == ChessColor.white 
                    ? Colors.white.withOpacity(0.1) 
                    : Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MessengerColors.messengerBlue),
              ),
              child: Text(
                'TOURNAMENT MODE: YOU ARE ${widget.myColor == ChessColor.white ? "WHITE" : "BLACK"}',
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
            ),
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
                                ? (isDark ? theme.cardColor : theme.cardColor)
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
                              color: theme.textTheme.bodyLarge?.color ??
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
          if (widget.tournamentId == null)
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
