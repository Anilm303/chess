import 'package:flutter/material.dart';
import '../widgets/tournament_payment_button.dart';

class TournamentJoinScreen extends StatelessWidget {
  final String userId;
  final String tournamentId;
  final double entryFee;
  final String backendBaseUrl;

  const TournamentJoinScreen({
    Key? key,
    required this.userId,
    required this.tournamentId,
    required this.entryFee,
    required this.backendBaseUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournament Join')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tournament: $tournamentId',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Entry fee: NPR ${0.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            TournamentPaymentButton(
              userId: userId,
              tournamentId: tournamentId,
              amount: entryFee,
              backendBaseUrl: backendBaseUrl,
            ),
          ],
        ),
      ),
    );
  }
}
