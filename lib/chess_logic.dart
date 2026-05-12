
enum ChessColor { white, black }

class ChessPiece {
  final String type; // 'p', 'r', 'n', 'b', 'q', 'k'
  final ChessColor color;

  ChessPiece({required this.type, required this.color});

  String get symbol {
    const symbols = {
      'P': '♙', 'R': '♖', 'N': '♘', 'B': '♗', 'Q': '♕', 'K': '♔',
      'p': '♟', 'r': '♜', 'n': '♞', 'b': '♝', 'q': '♛', 'k': '♚',
    };
    return color == ChessColor.white ? symbols[type.toUpperCase()]! : symbols[type.toLowerCase()]!;
  }
}

class ChessGame {
  List<List<ChessPiece?>> board = List.generate(8, (_) => List.filled(8, null));
  ChessColor turn = ChessColor.white;

  ChessGame() {
    _initBoard();
  }

  void _initBoard() {
    // Black pieces
    const backRank = ['r', 'n', 'b', 'q', 'k', 'b', 'n', 'r'];
    for (int i = 0; i < 8; i++) {
      board[0][i] = ChessPiece(type: backRank[i], color: ChessColor.black);
      board[1][i] = ChessPiece(type: 'p', color: ChessColor.black);
    }

    // White pieces
    for (int i = 0; i < 8; i++) {
      board[6][i] = ChessPiece(type: 'p', color: ChessColor.white);
      board[7][i] = ChessPiece(type: backRank[i], color: ChessColor.white);
    }
  }

  bool inBounds(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  List<List<int>> getRawMoves(int r, int c) {
    var piece = board[r][c];
    if (piece == null) return [];

    List<List<int>> moves = [];
    String type = piece.type.toLowerCase();
    ChessColor color = piece.color;

    if (type == 'p') {
      int dir = color == ChessColor.white ? -1 : 1;
      int startRow = color == ChessColor.white ? 6 : 1;
      
      // forward
      if (inBounds(r + dir, c) && board[r + dir][c] == null) {
        moves.add([r + dir, c]);
        if (r == startRow && board[r + 2 * dir][c] == null) {
          moves.add([r + 2 * dir, c]);
        }
      }
      // captures
      for (int dc in [-1, 1]) {
        if (inBounds(r + dir, c + dc)) {
          var target = board[r + dir][c + dc];
          if (target != null && target.color != color) {
            moves.add([r + dir, c + dc]);
          }
        }
      }
    } else if (type == 'r' || type == 'q') {
      const dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];
      for (var d in dirs) {
        int nr = r + d[0], nc = c + d[1];
        while (inBounds(nr, nc)) {
          if (board[nr][nc] == null) {
            moves.add([nr, nc]);
          } else {
            if (board[nr][nc]!.color != color) moves.add([nr, nc]);
            break;
          }
          nr += d[0]; nc += d[1];
        }
      }
    }
    if (type == 'b' || type == 'q') {
      const dirs = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
      for (var d in dirs) {
        int nr = r + d[0], nc = c + d[1];
        while (inBounds(nr, nc)) {
          if (board[nr][nc] == null) {
            moves.add([nr, nc]);
          } else {
            if (board[nr][nc]!.color != color) moves.add([nr, nc]);
            break;
          }
          nr += d[0]; nc += d[1];
        }
      }
    } else if (type == 'n') {
      const dirs = [[-2, -1], [-2, 1], [-1, -2], [-1, 2], [1, -2], [1, 2], [2, -1], [2, 1]];
      for (var d in dirs) {
        int nr = r + d[0], nc = c + d[1];
        if (inBounds(nr, nc) && (board[nr][nc] == null || board[nr][nc]!.color != color)) {
          moves.add([nr, nc]);
        }
      }
    } else if (type == 'k') {
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          int nr = r + dr, nc = c + dc;
          if (inBounds(nr, nc) && (board[nr][nc] == null || board[nr][nc]!.color != color)) {
            moves.add([nr, nc]);
          }
        }
      }
    }

    return moves;
  }

  bool isInCheck(ChessColor color) {
    int kr = -1, kc = -1;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        if (board[r][c]?.type == 'k' && board[r][c]?.color == color) {
          kr = r; kc = c;
          break;
        }
      }
    }
    
    ChessColor opp = color == ChessColor.white ? ChessColor.black : ChessColor.white;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        if (board[r][c]?.color == opp) {
          var moves = getRawMoves(r, c);
          for (var move in moves) {
            if (move[0] == kr && move[1] == kc) return true;
          }
        }
      }
    }
    return false;
  }

  bool makeMove(int r1, int c1, int r2, int c2) {
    var piece = board[r1][c1];
    if (piece == null || piece.color != turn) return false;

    var rawMoves = getRawMoves(r1, c1);
    bool valid = false;
    for (var m in rawMoves) {
      if (m[0] == r2 && m[1] == c2) {
        valid = true;
        break;
      }
    }
    if (!valid) return false;

    // Simulate to check
    var originalTarget = board[r2][c2];
    board[r2][c2] = piece;
    board[r1][c1] = null;
    
    if (isInCheck(turn)) {
      // Revert
      board[r1][c1] = piece;
      board[r2][c2] = originalTarget;
      return false;
    }

    // Pawn promotion
    if (piece.type == 'p') {
      if ((piece.color == ChessColor.white && r2 == 0) || (piece.color == ChessColor.black && r2 == 7)) {
        board[r2][c2] = ChessPiece(type: 'q', color: piece.color);
      }
    }

    turn = turn == ChessColor.white ? ChessColor.black : ChessColor.white;
    return true;
  }
}
