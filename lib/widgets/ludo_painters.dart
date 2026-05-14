// Ludo Board Painter - Renders the classic 15x15 grid Ludo board
import 'package:flutter/material.dart';
import 'dart:math';
import '../models/ludo_models.dart';

class LudoBoardPainter extends CustomPainter {
  final GameState gameState;
  final double boardSize;

  LudoBoardPainter({required this.gameState, this.boardSize = 400});

  // Standard Ludo Path Coordinates (52 steps around the perimeter)
  static const List<Offset> _pathCoords = [
    Offset(6, 13), Offset(6, 12), Offset(6, 11), Offset(6, 10), Offset(6, 9), // Bottom arm up
    Offset(5, 8), Offset(4, 8), Offset(3, 8), Offset(2, 8), Offset(1, 8), Offset(0, 8), // Left arm left
    Offset(0, 7), Offset(0, 6), // Turn up & right
    Offset(1, 6), Offset(2, 6), Offset(3, 6), Offset(4, 6), Offset(5, 6), // Left arm right
    Offset(6, 5), Offset(6, 4), Offset(6, 3), Offset(6, 2), Offset(6, 1), Offset(6, 0), // Top arm up
    Offset(7, 0), Offset(8, 0), // Turn right & down
    Offset(8, 1), Offset(8, 2), Offset(8, 3), Offset(8, 4), Offset(8, 5), // Top arm down
    Offset(9, 6), Offset(10, 6), Offset(11, 6), Offset(12, 6), Offset(13, 6), Offset(14, 6), // Right arm right
    Offset(14, 7), Offset(14, 8), // Turn down & left
    Offset(13, 8), Offset(12, 8), Offset(11, 8), Offset(10, 8), Offset(9, 8), // Right arm left
    Offset(8, 9), Offset(8, 10), Offset(8, 11), Offset(8, 12), Offset(8, 13), Offset(8, 14), // Bottom arm down
    Offset(7, 14), Offset(6, 14) // Turn left & up
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Force a square size
    final double actualSize = min(size.width, size.height);
    final double cellSize = actualSize / 15;
    
    // Save state to center the board if needed
    canvas.save();
    if (size.width > actualSize) canvas.translate((size.width - actualSize) / 2, 0);
    if (size.height > actualSize) canvas.translate(0, (size.height - actualSize) / 2);

    _drawBoard(canvas, cellSize);
    _drawTokens(canvas, cellSize);
    
    canvas.restore();
  }

  void _drawBoard(Canvas canvas, double cellSize) {
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Draw all path cells first (white by default)
    for (int x = 0; x < 15; x++) {
      for (int y = 0; y < 15; y++) {
        // Skip corner home bases
        if ((x < 6 && y < 6) || (x > 8 && y < 6) || (x < 6 && y > 8) || (x > 8 && y > 8)) continue;
        // Skip center triangle area
        if (x >= 6 && x <= 8 && y >= 6 && y <= 8) continue;
        
        final rect = Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize);
        canvas.drawRect(rect, Paint()..color = Colors.white);
        canvas.drawRect(rect, borderPaint);
      }
    }
    
    // Draw 4 home bases
    _drawHomeBase(canvas, cellSize, 0, 9, Colors.red);
    _drawHomeBase(canvas, cellSize, 0, 0, Colors.green);
    _drawHomeBase(canvas, cellSize, 9, 0, Colors.yellow[700]!);
    _drawHomeBase(canvas, cellSize, 9, 9, Colors.blue);
    
    // Color start squares, safe stars, and home stretches
    _colorSpecialCells(canvas, cellSize);
    
    // Draw Center
    _drawCenter(canvas, cellSize);
  }

  void _drawHomeBase(Canvas canvas, double cellSize, int col, int row, Color color) {
    final rect = Rect.fromLTWH(col * cellSize, row * cellSize, 6 * cellSize, 6 * cellSize);
    canvas.drawRect(rect, Paint()..color = color);
    canvas.drawRect(rect, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2);
    
    // Inner white square
    final innerRect = Rect.fromLTWH((col + 1) * cellSize, (row + 1) * cellSize, 4 * cellSize, 4 * cellSize);
    canvas.drawRect(innerRect, Paint()..color = Colors.white);
    canvas.drawRect(innerRect, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1);
    
    // 4 token spots
    final spotPaint = Paint()..color = color;
    final spotBorder = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      final dx = (i % 2 == 0) ? 2.0 : 4.0;
      final dy = (i < 2) ? 2.0 : 4.0;
      final center = Offset((col + dx) * cellSize, (row + dy) * cellSize);
      canvas.drawCircle(center, cellSize * 0.7, spotPaint);
      canvas.drawCircle(center, cellSize * 0.7, spotBorder);
    }
  }

  void _colorSpecialCells(Canvas canvas, double cellSize) {
    void paintCell(Offset coord, Color color, {bool isStar = false}) {
      final rect = Rect.fromLTWH(coord.dx * cellSize, coord.dy * cellSize, cellSize, cellSize);
      canvas.drawRect(rect, Paint()..color = color);
      canvas.drawRect(rect, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1);
      
      if (isStar) {
        _drawStar(canvas, rect.center, cellSize * 0.35, Paint()..color = Colors.white);
      }
    }

    // Red (Starts at 0, Star at 8)
    paintCell(_pathCoords[0], Colors.red);
    paintCell(_pathCoords[8], Colors.red, isStar: true);
    for (int i = 1; i <= 5; i++) paintCell(Offset(7, 14 - i.toDouble()), Colors.red);
    
    // Green (Starts at 13, Star at 21)
    paintCell(_pathCoords[13], Colors.green);
    paintCell(_pathCoords[21], Colors.green, isStar: true);
    for (int i = 1; i <= 5; i++) paintCell(Offset(i.toDouble(), 7), Colors.green);
    
    // Yellow (Starts at 26, Star at 34)
    paintCell(_pathCoords[26], Colors.yellow[700]!);
    paintCell(_pathCoords[34], Colors.yellow[700]!, isStar: true);
    for (int i = 1; i <= 5; i++) paintCell(Offset(7, i.toDouble()), Colors.yellow[700]!);
    
    // Blue (Starts at 39, Star at 47)
    paintCell(_pathCoords[39], Colors.blue);
    paintCell(_pathCoords[47], Colors.blue, isStar: true);
    for (int i = 1; i <= 5; i++) paintCell(Offset(14 - i.toDouble(), 7), Colors.blue);
  }

  void _drawCenter(Canvas canvas, double cellSize) {
    final rect = Rect.fromLTWH(6 * cellSize, 6 * cellSize, 3 * cellSize, 3 * cellSize);
    final center = rect.center;
    
    // Bottom Triangle (Red)
    final pathRed = Path()..moveTo(rect.left, rect.bottom)..lineTo(rect.right, rect.bottom)..lineTo(center.dx, center.dy)..close();
    canvas.drawPath(pathRed, Paint()..color = Colors.red);
    
    // Left Triangle (Green)
    final pathGreen = Path()..moveTo(rect.left, rect.top)..lineTo(rect.left, rect.bottom)..lineTo(center.dx, center.dy)..close();
    canvas.drawPath(pathGreen, Paint()..color = Colors.green);
    
    // Top Triangle (Yellow)
    final pathYellow = Path()..moveTo(rect.left, rect.top)..lineTo(rect.right, rect.top)..lineTo(center.dx, center.dy)..close();
    canvas.drawPath(pathYellow, Paint()..color = Colors.yellow[700]!);
    
    // Right Triangle (Blue)
    final pathBlue = Path()..moveTo(rect.right, rect.top)..lineTo(rect.right, rect.bottom)..lineTo(center.dx, center.dy)..close();
    canvas.drawPath(pathBlue, Paint()..color = Colors.blue);
    
    // Center outlines
    final linePaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawLine(rect.topLeft, rect.bottomRight, linePaint);
    canvas.drawLine(rect.topRight, rect.bottomLeft, linePaint);
    canvas.drawRect(rect, linePaint);
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      // 144 degrees spacing creates a 5-pointed star
      final angle = (i * 144 - 90) * (pi / 180);
      final x = center.dx + size * cos(angle);
      final y = center.dy + size * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  Offset _getGridCoordinate(Token token) {
    if (token.position == -1) {
      // In home base
      return _getHomeBaseCoordinate(token);
    } else if (token.position >= 52) {
      // In home stretch (52-57)
      int steps = token.position - 51; // position 52 -> step 1
      switch (token.playerColor) {
        case PlayerColor.red: return Offset(7, 14.0 - steps); // Moving UP to 7,8
        case PlayerColor.green: return Offset(0.0 + steps, 7); // Moving RIGHT to 6,7
        case PlayerColor.yellow: return Offset(7, 0.0 + steps); // Moving DOWN to 7,6
        case PlayerColor.blue: return Offset(14.0 - steps, 7); // Moving LEFT to 8,7
      }
    }
    // Main path (0-51)
    return _pathCoords[token.position];
  }

  Offset _getHomeBaseCoordinate(Token token) {
    double baseX = 0, baseY = 0;
    switch (token.playerColor) {
      case PlayerColor.red: baseX = 0; baseY = 9; break; // Bottom-Left
      case PlayerColor.green: baseX = 0; baseY = 0; break; // Top-Left
      case PlayerColor.yellow: baseX = 9; baseY = 0; break; // Top-Right
      case PlayerColor.blue: baseX = 9; baseY = 9; break; // Bottom-Right
    }
    
    final dx = (token.id % 2 == 0) ? 2.0 : 4.0;
    final dy = (token.id < 2) ? 2.0 : 4.0;
    
    return Offset(baseX + dx, baseY + dy);
  }

  Color _getPlayerColor(PlayerColor color) {
    switch (color) {
      case PlayerColor.red: return Colors.red;
      case PlayerColor.green: return Colors.green;
      case PlayerColor.yellow: return Colors.yellow[700]!;
      case PlayerColor.blue: return Colors.blue;
    }
  }

  void _drawTokens(Canvas canvas, double cellSize) {
    Map<int, List<Token>> positionedTokens = {};
    
    for (final player in gameState.players) {
      for (final token in player.tokens) {
        if (token.position >= 0 && token.position < 57) {
          positionedTokens.putIfAbsent(token.position, () => []).add(token);
        } else {
          // Draw tokens in Home Base (-1) or Finished (57) immediately
          _drawToken(canvas, cellSize, token, _getGridCoordinate(token), 1, 0);
        }
      }
    }
    
    // Draw positioned tokens with clustering if they share a tile
    positionedTokens.forEach((pos, tokens) {
      final baseCoord = _getGridCoordinate(tokens.first);
      
      for (int i = 0; i < tokens.length; i++) {
        _drawToken(canvas, cellSize, tokens[i], baseCoord, tokens.length, i);
      }
    });
  }

  void _drawToken(Canvas canvas, double cellSize, Token token, Offset gridCoord, int totalInCell, int index) {
    double cx = (gridCoord.dx + 0.5) * cellSize;
    double cy = (gridCoord.dy + 0.5) * cellSize;
    
    // Apply offset if clustered
    if (totalInCell > 1) {
      final offsetStep = cellSize * 0.2;
      if (totalInCell == 2) {
        cx += (index == 0) ? -offsetStep : offsetStep;
      } else if (totalInCell == 3) {
        if (index == 0) { cx -= offsetStep; cy -= offsetStep; }
        else if (index == 1) { cx += offsetStep; cy -= offsetStep; }
        else { cy += offsetStep; }
      } else if (totalInCell >= 4) {
        cx += (index % 2 == 0) ? -offsetStep : offsetStep;
        cy += (index < 2) ? -offsetStep : offsetStep;
      }
    }
    
    final tokenPos = Offset(cx, cy);
    final paint = Paint()..color = _getPlayerColor(token.playerColor)..style = PaintingStyle.fill;
    final radius = cellSize * 0.35;

    // Token shadow
    canvas.drawCircle(
      tokenPos,
      radius * 1.1,
      Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
    );

    // Token body
    canvas.drawCircle(tokenPos, radius, paint);

    // Token border
    canvas.drawCircle(
      tokenPos,
      radius,
      Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2,
    );
    
    // Token inner ring for depth
    canvas.drawCircle(
      tokenPos,
      radius * 0.6,
      Paint()..color = Colors.black.withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(LudoBoardPainter oldDelegate) {
    return oldDelegate.gameState != gameState;
  }
}
