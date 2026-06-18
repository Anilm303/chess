// Ludo Board Painter - Renders the classic 15x15 grid Ludo board
import 'package:flutter/material.dart';
import 'dart:math';
import '../models/ludo_models.dart';

/// Defines the 4 selectable board color themes.
class LudoBoardTheme {
  final Color red;
  final Color green;
  final Color yellow;
  final Color blue;
  final Color boardBg;
  final Color pathBg;

  const LudoBoardTheme({
    required this.red,
    required this.green,
    required this.yellow,
    required this.blue,
    required this.boardBg,
    required this.pathBg,
  });

  static const List<LudoBoardTheme> themes = [
    // Theme 1 – Classic
    LudoBoardTheme(
      red: Color(0xFFF1463A),
      green: Color(0xFF59A95A),
      yellow: Color(0xFFF0D63D),
      blue: Color(0xFF3B73F2),
      boardBg: Color(0xFFE5C599),
      pathBg: Color(0xFFEDE0C8),
    ),
    // Theme 2 – Deep Ocean
    LudoBoardTheme(
      red: Color(0xFF1565C0),
      green: Color(0xFF00838F),
      yellow: Color(0xFF29B6F6),
      blue: Color(0xFF6A1B9A),
      boardBg: Color(0xFF0D2137),
      pathBg: Color(0xFF163352),
    ),
    // Theme 3 – Pastel
    LudoBoardTheme(
      red: Color(0xFFEF9A9A),
      green: Color(0xFFA5D6A7),
      yellow: Color(0xFFFFF176),
      blue: Color(0xFF90CAF9),
      boardBg: Color(0xFFFFF8E1),
      pathBg: Color(0xFFFFF3E0),
    ),
    // Theme 4 – Dark Neon
    LudoBoardTheme(
      red: Color(0xFFFF1744),
      green: Color(0xFF00E676),
      yellow: Color(0xFFFFEA00),
      blue: Color(0xFF2979FF),
      boardBg: Color(0xFF121212),
      pathBg: Color(0xFF1E1E1E),
    ),
  ];
}

class LudoBoardPainter extends CustomPainter {
  final GameState gameState;
  final double boardSize;
  final Map<String, dynamic>? lastMove;
  final bool showSafeCells;
  final int boardIndex;
  final double turnHighlight;

  LudoBoardPainter({
    required this.gameState,
    this.boardSize = 400,
    this.lastMove,
    this.showSafeCells = true,
    this.boardIndex = 0,
    this.turnHighlight = 0.0,
  });

  LudoBoardTheme get _theme => LudoBoardTheme.themes[boardIndex.clamp(0, LudoBoardTheme.themes.length - 1)];

  // Standard Ludo Path Coordinates (52 steps around the perimeter)
  static const List<Offset> _pathCoords = [
    Offset(6, 13),
    Offset(6, 12),
    Offset(6, 11),
    Offset(6, 10),
    Offset(6, 9), // Bottom arm up
    Offset(5, 8),
    Offset(4, 8),
    Offset(3, 8),
    Offset(2, 8),
    Offset(1, 8),
    Offset(0, 8), // Left arm left
    Offset(0, 7), Offset(0, 6), // Turn up & right
    Offset(1, 6),
    Offset(2, 6),
    Offset(3, 6),
    Offset(4, 6),
    Offset(5, 6), // Left arm right
    Offset(6, 5),
    Offset(6, 4),
    Offset(6, 3),
    Offset(6, 2),
    Offset(6, 1),
    Offset(6, 0), // Top arm up
    Offset(7, 0), Offset(8, 0), // Turn right & down
    Offset(8, 1),
    Offset(8, 2),
    Offset(8, 3),
    Offset(8, 4),
    Offset(8, 5), // Top arm down
    Offset(9, 6),
    Offset(10, 6),
    Offset(11, 6),
    Offset(12, 6),
    Offset(13, 6),
    Offset(14, 6), // Right arm right
    Offset(14, 7), Offset(14, 8), // Turn down & left
    Offset(13, 8),
    Offset(12, 8),
    Offset(11, 8),
    Offset(10, 8),
    Offset(9, 8), // Right arm left
    Offset(8, 9),
    Offset(8, 10),
    Offset(8, 11),
    Offset(8, 12),
    Offset(8, 13),
    Offset(8, 14), // Bottom arm down
    Offset(7, 14), Offset(6, 14), // Turn left & up
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Force a square size
    final double actualSize = min(size.width, size.height);
    final double cellSize = actualSize / 15;

    // Save state to center the board if needed
    canvas.save();
    if (size.width > actualSize)
      canvas.translate((size.width - actualSize) / 2, 0);
    if (size.height > actualSize)
      canvas.translate(0, (size.height - actualSize) / 2);

    _drawBoard(canvas, cellSize);
    _drawTokens(canvas, cellSize);

    canvas.restore();
  }

  void _drawBoard(Canvas canvas, double cellSize) {
    // Draw thick border around the entire board (Frame)
    final boardRect = Rect.fromLTWH(0, 0, 15 * cellSize, 15 * cellSize);
    
    // Draw background using theme color
    final woodPaint = Paint()..color = _theme.boardBg;
    canvas.drawRect(boardRect, woodPaint);

    // Draw Wood Texture Grain
    _drawWoodGrain(canvas, boardRect, cellSize);

    final borderPaint = Paint()
      ..color = const Color(0xFF3E2723) // Dark brown frame
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawRect(boardRect, borderPaint);

    // Grid lines for the path cells
    final linePaint = Paint()
      ..color = Colors.black.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int x = 0; x < 15; x++) {
      for (int y = 0; y < 15; y++) {
        if ((x < 6 && y < 6) ||
            (x > 8 && y < 6) ||
            (x < 6 && y > 8) ||
            (x > 8 && y > 8)) {
          continue;
        }
        if (x >= 6 && x <= 8 && y >= 6 && y <= 8) continue;

        final rect = Rect.fromLTWH(
          x * cellSize,
          y * cellSize,
          cellSize,
          cellSize,
        );
        canvas.drawRect(rect, linePaint);
      }
    }

    // Color start squares, safe stars, and home stretches
    _colorSpecialCells(canvas, cellSize);

    // Draw 4 home bases
    _drawHomeBase(canvas, cellSize, 0, 9, PlayerColor.blue); // BL
    _drawHomeBase(canvas, cellSize, 0, 0, PlayerColor.green); // TL
    _drawHomeBase(canvas, cellSize, 9, 0, PlayerColor.red); // TR
    _drawHomeBase(canvas, cellSize, 9, 9, PlayerColor.yellow); // BR

    // Draw Center
    _drawCenter(canvas, cellSize);
    
    // Arrows drawing disabled as requested
    // _drawArrows(canvas, cellSize);
  }

  void _drawWoodGrain(Canvas canvas, Rect rect, double cellSize) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final random = Random(42); // Fixed seed for consistent grain
    for (int i = 0; i < 40; i++) {
      final y = rect.top + random.nextDouble() * rect.height;
      final path = Path();
      path.moveTo(rect.left, y);
      
      double curX = rect.left;
      double curY = y;
      while (curX < rect.right) {
        curX += 20 + random.nextDouble() * 100;
        curY += (random.nextDouble() - 0.5) * 15;
        path.quadraticBezierTo(curX - 25, curY + 10, curX, curY);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawHomeBase(
    Canvas canvas,
    double cellSize,
    int col,
    int row,
    PlayerColor pColor,
  ) {
    final Color color = _getPlayerColor(pColor);
    final rect = Rect.fromLTWH(
      col * cellSize,
      row * cellSize,
      6 * cellSize,
      6 * cellSize,
    );
    
    // Outer colored rounded rectangle
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.4));
    canvas.drawRRect(rrect, Paint()..color = color);

    // Blinking effect for current turn
    final bool isMyTurn = gameState.currentPlayer.color == pColor;
    if (isMyTurn) {
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.3 + (turnHighlight * 0.4))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 + (turnHighlight * 5);
      canvas.drawRRect(rrect, highlightPaint);
      
      final glowPaint = Paint()
        ..color = color.withOpacity(0.2 + (turnHighlight * 0.3))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 + (turnHighlight * 10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(rrect, glowPaint);
    }

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = isMyTurn ? Colors.white : Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = isMyTurn ? 3 : 2.5,
    );

    // Inner white rounded square (larger as per image)
    final innerRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        (col + 0.8) * cellSize,
        (row + 1.0) * cellSize,
        4.4 * cellSize,
        4.0 * cellSize,
      ),
      Radius.circular(cellSize * 1.0),
    );
    canvas.drawRRect(innerRRect, Paint()..color = Colors.white);

    // 4 token spots (concentric rings as per image)
    for (int i = 0; i < 4; i++) {
      final dx = (i % 2 == 0) ? 1.6 : 3.4;
      final dy = (i < 2) ? 1.6 : 3.4;
      final center = Offset((col + dx + 0.5) * cellSize, (row + dy + 0.5) * cellSize);
      
      canvas.drawCircle(center, cellSize * 0.65, Paint()..color = color);
      canvas.drawCircle(center, cellSize * 0.45, Paint()..color = Colors.white);
      canvas.drawCircle(center, cellSize * 0.25, Paint()..color = color);
    }
    
    // Player Name and Percentage
    Player? p;
    try {
      p = gameState.players.firstWhere((element) => element.color == pColor);
    } catch (_) {}
    
    if (p != null) {
      const int maxStepsPerToken = 57;
      int totalStepsMoved = 0;
      for (final t in p.tokens) {
        if (t.position >= 0) {
          final int startPos = BoardConfig.playerStartPositions[p.color] ?? 0;
          if (t.position >= BoardConfig.homePathStart) {
            totalStepsMoved += (BoardConfig.totalPositions) + (t.position - BoardConfig.homePathStart);
          } else {
            int steps = t.position - startPos;
            if (steps < 0) steps += BoardConfig.totalPositions;
            totalStepsMoved += steps;
          }
        }
      }
      final int maxTotalSteps = p.tokenCount * maxStepsPerToken;
      double pct = maxTotalSteps > 0 ? (totalStepsMoved / maxTotalSteps) * 100 : 0.0;
      if (pct > 100) pct = 100;
      String pctStr = "${pct.toStringAsFixed(1)}%";

      // Draw Percentage at Top
      final pctPainter = TextPainter(
        text: TextSpan(
          text: pctStr,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: cellSize * 0.6,
            shadows: const [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      pctPainter.layout();
      pctPainter.paint(canvas, Offset(rect.center.dx - pctPainter.width / 2, rect.top + cellSize * 0.15));

      // Draw Name at Bottom
      final String displayName = p.type == PlayerType.ai ? 'Computer' : p.name;
      final namePainter = TextPainter(
        text: TextSpan(
          text: displayName,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: cellSize * 0.65,
            shadows: const [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      namePainter.layout();
      namePainter.paint(canvas, Offset(rect.center.dx - namePainter.width / 2, rect.bottom - cellSize * 0.85));
    }
  }

  void _colorSpecialCells(Canvas canvas, double cellSize) {
    void paintCell(Offset coord, Color color, {bool isStar = false}) {
      final rect = Rect.fromLTWH(
        coord.dx * cellSize,
        coord.dy * cellSize,
        cellSize,
        cellSize,
      );
      canvas.drawRect(rect, Paint()..color = color);
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.black.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      if (isStar) {
        // Star Background Circle
        canvas.drawCircle(rect.center, cellSize * 0.42, Paint()..color = Colors.black.withOpacity(0.12));
        _drawStar(
          canvas,
          rect.center,
          cellSize * 0.38,
          Paint()..color = Colors.white,
        );
      }
    }

    // Paint start squares
    BoardConfig.playerStartPositions.forEach((color, startIdx) {
      final token = Token(id: 0, playerColor: color, position: startIdx);
      final coord = gridCoordinateForToken(token);
      paintCell(coord, _getPlayerColor(color));
    });

    // Paint safe positions (stars)
    if (showSafeCells) {
      for (final idx in BoardConfig.safePositions) {
        final tmp = Token(id: 0, playerColor: PlayerColor.red, position: idx);
        final coord = gridCoordinateForToken(tmp);
        bool isStart = BoardConfig.playerStartPositions.values.contains(idx);
        paintCell(coord, isStart ? _getPlayerColor(BoardConfig.playerStartPositions.entries.firstWhere((e) => e.value == idx).key) : Colors.transparent, isStar: true);
      }
    }

    // Paint home-stretch cells
    for (final color in PlayerColor.values) {
      for (int step = 1; step <= BoardConfig.homePositions - 1; step++) {
        final token = Token(id: 0, playerColor: color, position: 51 + step);
        final coord = gridCoordinateForToken(token);
        paintCell(coord, _getPlayerColor(color));
      }
    }
  }

  void _drawCenter(Canvas canvas, double cellSize) {
    final rect = Rect.fromLTWH(
      6 * cellSize,
      6 * cellSize,
      3 * cellSize,
      3 * cellSize,
    );
    final center = rect.center;

    // Left triangle (Green)
    final pathLeft = Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(center.dx, center.dy)
      ..close();
    canvas.drawPath(pathLeft, Paint()..color = _getPlayerColor(PlayerColor.green));

    // Top triangle (Red)
    final pathTop = Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(center.dx, center.dy)
      ..close();
    canvas.drawPath(pathTop, Paint()..color = _getPlayerColor(PlayerColor.red));

    // Right triangle (Yellow)
    final pathRight = Path()
      ..moveTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(center.dx, center.dy)
      ..close();
    canvas.drawPath(pathRight, Paint()..color = _getPlayerColor(PlayerColor.yellow));

    // Bottom triangle (Blue)
    final pathBottom = Path()
      ..moveTo(rect.left, rect.bottom)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(center.dx, center.dy)
      ..close();
    canvas.drawPath(pathBottom, Paint()..color = _getPlayerColor(PlayerColor.blue));

    // Black outlines for the triangles
    final linePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(pathBottom, linePaint);
    canvas.drawPath(pathLeft, linePaint);
    canvas.drawPath(pathTop, linePaint);
    canvas.drawPath(pathRight, linePaint);
    canvas.drawRect(rect, linePaint);

    // Draw circular slots in the middle of each triangle where finished tokens will sit
    final slotPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(Offset(6.5 * cellSize, 7.5 * cellSize), cellSize * 0.35, slotPaint); // Green (Left)
    canvas.drawCircle(Offset(7.5 * cellSize, 6.5 * cellSize), cellSize * 0.35, slotPaint); // Yellow (Top)
    canvas.drawCircle(Offset(8.5 * cellSize, 7.5 * cellSize), cellSize * 0.35, slotPaint); // Blue (Right)
    canvas.drawCircle(Offset(7.5 * cellSize, 8.5 * cellSize), cellSize * 0.35, slotPaint); // Red (Bottom)
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
        case PlayerColor.blue:
          return Offset(7, 14.0 - steps); // Moving UP to 7,8
        case PlayerColor.green:
          return Offset(0.0 + steps, 7); // Moving RIGHT to 6,7
        case PlayerColor.red:
          return Offset(7, 0.0 + steps); // Moving DOWN to 7,6
        case PlayerColor.yellow:
          return Offset(14.0 - steps, 7); // Moving LEFT to 8,7
      }
    }
    // Main path (0-51)
    return _pathCoords[token.position];
  }

  /// Public helper: compute grid coordinate (in 15x15 grid) for a token
  static Offset gridCoordinateForToken(Token token) {
    if (token.position == -1) {
      // In home base
      double baseX = 0, baseY = 0;
      switch (token.playerColor) {
        case PlayerColor.blue:
          baseX = 0;
          baseY = 9;
          break;
        case PlayerColor.green:
          baseX = 0;
          baseY = 0;
          break;
        case PlayerColor.red:
          baseX = 9;
          baseY = 0;
          break;
        case PlayerColor.yellow:
          baseX = 9;
          baseY = 9;
          break;
      }
      final dx = (token.id % 2 == 0) ? 1.5 : 3.5;
      final dy = (token.id < 2) ? 1.6 : 3.4;
      return Offset(baseX + dx, baseY + dy);
    } else if (token.position >= 52) {
      int steps = token.position - 51; // position 52 -> step 1
      switch (token.playerColor) {
        case PlayerColor.blue:
          return Offset(7, 14.0 - steps);
        case PlayerColor.green:
          return Offset(0.0 + steps, 7);
        case PlayerColor.red:
          return Offset(7, 0.0 + steps);
        case PlayerColor.yellow:
          return Offset(14.0 - steps, 7);
      }
    }
    return _pathCoords[token.position];
  }

  Offset _getHomeBaseCoordinate(Token token) {
    double baseX = 0, baseY = 0;
    switch (token.playerColor) {
      case PlayerColor.blue:
        baseX = 0;
        baseY = 9;
        break; // Bottom-Left
      case PlayerColor.green:
        baseX = 0;
        baseY = 0;
        break; // Top-Left
      case PlayerColor.red:
        baseX = 9;
        baseY = 0;
        break; // Top-Right
      case PlayerColor.yellow:
        baseX = 9;
        baseY = 9;
        break; // Bottom-Right
    }

    final dx = (token.id % 2 == 0) ? 1.5 : 3.5;
    final dy = (token.id < 2) ? 1.6 : 3.4;

    return Offset(baseX + dx, baseY + dy);
  }

  Color _getPlayerColor(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return _theme.red;
      case PlayerColor.green:
        return _theme.green;
      case PlayerColor.yellow:
        return _theme.yellow;
      case PlayerColor.blue:
        return _theme.blue;
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
    // If lastMove indicates killed tokens, draw kill flashes even if tile is now empty
    if (lastMove != null && lastMove!['killedTokens'] != null) {
      try {
        final List<dynamic> kt = lastMove!['killedTokens'] as List<dynamic>;
        for (final k in kt) {
          final Map<String, dynamic> km = Map<String, dynamic>.from(k as Map);
          final int fromPos = km['from'] as int? ?? -1;
          if (fromPos >= 0) {
            final tmpToken = Token(
              id: km['tokenId'] as int,
              playerColor: PlayerColor.red,
              position: fromPos,
            );
            final coord = _getGridCoordinate(tmpToken);
            _drawKillFlash(canvas, cellSize, coord);
          }
        }
      } catch (e) {
        // ignore
      }
    }

    positionedTokens.forEach((pos, tokens) {
      final baseCoord = _getGridCoordinate(tokens.first);

      // highlight last-move tile
      if (lastMove != null && lastMove!['newPosition'] != null) {
        final int mvPos = lastMove!['newPosition'];
        if (mvPos == pos) {
          _drawLastMoveRing(canvas, cellSize, baseCoord);
        }
      }

      // detect stacks/blocks by color
      final Map<PlayerColor, int> colorCounts = {};
      for (final t in tokens) {
        colorCounts[t.playerColor] = (colorCounts[t.playerColor] ?? 0) + 1;
      }

      // If there is any blocked color (2 or more tokens), draw a block indicator
      colorCounts.forEach((color, count) {
        if (count >= 2) {
          _drawBlockIndicator(canvas, cellSize, baseCoord, color, count);
        }
      });

      for (int i = 0; i < tokens.length; i++) {
        _drawToken(canvas, cellSize, tokens[i], baseCoord, tokens.length, i);
      }
    });
  }

  void _drawKillFlash(Canvas canvas, double cellSize, Offset gridCoord) {
    final double cx = (gridCoord.dx + 0.5) * cellSize;
    final double cy = (gridCoord.dy + 0.5) * cellSize;

    // Glow circle
    final glow = Paint()..color = Colors.red.withOpacity(0.25);
    canvas.drawCircle(Offset(cx, cy), cellSize * 0.7, glow);

    // Core burst
    final core = Paint()..color = Colors.red.withOpacity(0.9);
    canvas.drawCircle(Offset(cx, cy), cellSize * 0.25, core);
  }

  void _drawLastMoveRing(Canvas canvas, double cellSize, Offset gridCoord) {
    final double cx = (gridCoord.dx + 0.5) * cellSize;
    final double cy = (gridCoord.dy + 0.5) * cellSize;
    final paint = Paint()
      ..color = Colors.yellow.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(Offset(cx, cy), cellSize * 0.45, paint);
  }

  void _drawBlockIndicator(
    Canvas canvas,
    double cellSize,
    Offset gridCoord,
    PlayerColor color,
    int count,
  ) {
    // small badge at top-right of the cell
    final double cx = (gridCoord.dx + 0.85) * cellSize;
    final double cy = (gridCoord.dy + 0.15) * cellSize;
    final double size = cellSize * 0.6;

    final paint = Paint()..color = _getPlayerColor(color);
    // background circle
    canvas.drawCircle(Offset(cx, cy), size * 0.45, paint);
    // border
    canvas.drawCircle(
      Offset(cx, cy),
      size * 0.45,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // draw count text
    final textPainter = TextPainter(
      text: TextSpan(
        text: count.toString(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.6,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
    );
  }

  void _drawToken(
    Canvas canvas,
    double cellSize,
    Token token,
    Offset gridCoord,
    int totalInCell,
    int index,
  ) {
    double cx = (gridCoord.dx + 0.5) * cellSize;
    double cy = (gridCoord.dy + 0.5) * cellSize;

    // Apply offset if clustered
    if (totalInCell > 1) {
      final offsetStep = cellSize * 0.2;
      if (totalInCell == 2) {
        cx += (index == 0) ? -offsetStep : offsetStep;
      } else if (totalInCell == 3) {
        if (index == 0) {
          cx -= offsetStep;
          cy -= offsetStep;
        } else if (index == 1) {
          cx += offsetStep;
          cy -= offsetStep;
        } else {
          cy += offsetStep;
        }
      } else if (totalInCell >= 4) {
        cx += (index % 2 == 0) ? -offsetStep : offsetStep;
        cy += (index < 2) ? -offsetStep : offsetStep;
      }
    }

    final tokenPos = Offset(cx, cy);
    final paint = Paint()
      ..color = _getPlayerColor(token.playerColor)
      ..style = PaintingStyle.fill;
    final radius = cellSize * 0.35;

    // Token shadow
    canvas.drawCircle(
      tokenPos,
      radius * 1.1,
      Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Token body
    canvas.drawCircle(tokenPos, radius, paint);

    // Token border
    canvas.drawCircle(
      tokenPos,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Token inner ring for depth
    canvas.drawCircle(
      tokenPos,
      radius * 0.6,
      Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Token number label (1-4)
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${token.id + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final textOffset = Offset(
      tokenPos.dx - textPainter.width / 2,
      tokenPos.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(LudoBoardPainter oldDelegate) {
    return true; // Always repaint to ensure tokens and theme update immediately
  }
}
