import 'package:flutter/material.dart';
import 'package:chess_app/features/tournament/presentation/widgets/tournament_payment_button.dart';
import 'package:chess_app/features/tournament/presentation/screens/tournament_waiting_screen.dart';
import 'package:chess_app/features/chess/presentation/screens/chess_board_screen.dart';

/// A full "tournament flow" screen that:
///  1. Shows the Pay button.
///  2. After successful payment, pushes the waiting room.
///  3. When both players have paid (`in_progress`), pushes the chess board.
///  4. When the tournament finishes, returns the result so the caller can show
///     the winner screen.
class TournamentJoinFlow extends StatefulWidget {
  final String userId;
  final String? tournamentId;
  final String tournamentTitle;
  final double amount;
  final String backendBaseUrl;
  final Widget? gameScreen; // Optional override for the game screen

  const TournamentJoinFlow({
    super.key,
    required this.userId,
    this.tournamentId,
    required this.tournamentTitle,
    required this.amount,
    required this.backendBaseUrl,
    this.gameScreen,
  });

  @override
  State<TournamentJoinFlow> createState() => _TournamentJoinFlowState();
}

class _TournamentJoinFlowState extends State<TournamentJoinFlow> {
  String? _tournamentId;

  @override
  void initState() {
    super.initState();
    _tournamentId = widget.tournamentId;
  }

  void _onPaymentCompleted(String? newTournamentId) {
    if (newTournamentId != null) {
      setState(() => _tournamentId = newTournamentId);
    }
    if (_tournamentId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TournamentWaitingScreen(
          tournamentId: _tournamentId!,
          backendBaseUrl: widget.backendBaseUrl,
          onStateChanged: (state) => _onTournamentState(state),
        ),
      ),
    );
  }

  void _onTournamentState(TournamentState state) {
    // Don't auto-push when the state is "open" or "waiting" - we only
    // navigate when the game actually starts or ends.
    if (state.status == 'in_progress') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => widget.gameScreen ??
              const ChessBoardScreen(), // whatever your screen is
        ),
      );
    }
    if (state.status == 'finished') {
      // Pop back to the join screen so the winner card is visible there.
      // (TournamentWaitingScreen shows the winner card itself.)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.tournamentTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.tournamentTitle,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Entry fee: NPR ${widget.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              TournamentPaymentButton(
                userId: widget.userId,
                tournamentId: _tournamentId,
                amount: widget.amount,
                backendBaseUrl: widget.backendBaseUrl,
                onPaymentCompleted: () => _onPaymentCompleted(_tournamentId),
              ),
              const SizedBox(height: 16),
              const Text(
                'Win the match and the full prize pool (2x entry fee minus 10% platform fee) goes to your wallet!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
