import 'package:flutter/material.dart';

class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final radius = size.shortestSide * 0.34;
          return Stack(
            children: [
              Container(color: Colors.black.withOpacity(0.35)),
              Center(
                child: Container(
                  width: radius * 2,
                  height: radius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00D4FF),
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x8800D4FF),
                        blurRadius: 26,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(painter: _ScannerLinePainter()),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScannerLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x0000D4FF), Color(0xFF00D4FF), Color(0x0000D4FF)],
      ).createShader(Rect.fromLTWH(0, size.height * 0.45, size.width, 3))
      ..strokeWidth = 3;

    canvas.drawLine(
      Offset(0, size.height * 0.45),
      Offset(size.width, size.height * 0.45),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
