import 'package:flutter/material.dart';

import '../../domain/entities/liveness_step.dart';

class LivenessStatusCard extends StatelessWidget {
  final LivenessStep step;
  final String hint;
  final bool blinkDetected;
  final bool turnDetected;
  final bool smileDetected;
  final double spoofScore;

  const LivenessStatusCard({
    super.key,
    required this.step,
    required this.hint,
    required this.blinkDetected,
    required this.turnDetected,
    required this.smileDetected,
    required this.spoofScore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC051B2D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00D4FF), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hint,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Blink', blinkDetected),
              _chip('Turn', turnDetected),
              _chip('Smile', smileDetected),
              _scoreChip(spoofScore),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFF0B8A65) : const Color(0xFF11334A),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        '$label ${ok ? 'OK' : '...'}',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _scoreChip(double score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF11334A),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        'Liveness ${(score * 100).toStringAsFixed(0)}%',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
