import 'package:flutter/material.dart';
import '../../../../chess_logic.dart';

class ColorSelectionScreen extends StatelessWidget {
  final String tournamentId;
  final Function(ChessColor selectedColor) onColorSelected;

  const ColorSelectionScreen({
    super.key,
    required this.tournamentId,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Side')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Select the color you want to play with:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ColorCard(
                    color: ChessColor.white,
                    label: 'White',
                    icon: '♔',
                    onTap: () => onColorSelected(ChessColor.white),
                  ),
                  _ColorCard(
                    color: ChessColor.black,
                    label: 'Black',
                    icon: '♚',
                    onTap: () => onColorSelected(ChessColor.black),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              const Text(
                'Note: If your opponent chooses the same color, the system will assign colors randomly.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorCard extends StatelessWidget {
  final ChessColor color;
  final String label;
  final String icon;
  final VoidCallback onTap;

  const _ColorCard({
    required this.color,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isWhite = color == ChessColor.white;
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isWhite ? Colors.white : Colors.black87,
        child: Container(
          width: 140,
          height: 180,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                icon,
                style: TextStyle(
                  fontSize: 64,
                  color: isWhite ? Colors.black : Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isWhite ? Colors.black : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
