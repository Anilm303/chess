import 'package:flutter/material.dart';
import '../widgets/tournament_payment_button.dart';
import 'tournament_waiting_screen.dart';
import 'package:chess_app/features/chess/presentation/screens/chess_board_screen.dart';

/// Tournament Join screen that handles the full pay → wait → play flow:
///   1. User sees the entry fee and "Pay" button.
///   2. After successful eSewa payment the screen pushes the
///      [TournamentWaitingScreen].
///   3. The waiting screen polls the backend and, when both players have
///      paid (status='in_progress'), automatically pushes the chess board.
///   4. When the game ends, the waiting screen shows the winner card.
class TournamentJoinScreen extends StatefulWidget {
  final String userId;
  final String tournamentId;
  final double entryFee;
  final String backendBaseUrl;
  final String tournamentTitle;
  final Widget? gameScreen; // Optional override for the chess board

  const TournamentJoinScreen({
    Key? key,
    required this.userId,
    required this.tournamentId,
    required this.entryFee,
    required this.backendBaseUrl,
    this.tournamentTitle = 'Tournament',
    this.gameScreen,
  }) : super(key: key);

  @override
  State<TournamentJoinScreen> createState() => _TournamentJoinScreenState();
}

class _TournamentJoinScreenState extends State<TournamentJoinScreen> {
  bool _navigated = false;

  void _goToWaitingRoom() {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TournamentWaitingScreen(
          tournamentId: widget.tournamentId,
          backendBaseUrl: widget.backendBaseUrl,
          onStateChanged: (state) {
            if (state.status == 'in_progress' && mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => widget.gameScreen ?? const ChessBoardScreen(),
                ),
              );
            }
          },
        ),
      ),
    ).then((_) {
      // User popped back from the waiting room - allow re-navigation if they pay again.
      if (mounted) setState(() => _navigated = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.tournamentTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tournament: ${widget.tournamentId.substring(0, widget.tournamentId.length.clamp(0, 8))}...',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              'Entry fee: NPR ${widget.entryFee.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Win the match and the full prize pool (2x entry fee minus 10% platform fee) goes to your wallet!',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 24),
            TournamentPaymentButton(
              userId: widget.userId,
              tournamentId: widget.tournamentId,
              amount: widget.entryFee,
              backendBaseUrl: widget.backendBaseUrl,
              onPaymentCompleted: _goToWaitingRoom,
            ),
          ],
        ),
      ),
    );
  }
}
