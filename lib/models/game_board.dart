import 'dart:math';
import 'gem.dart';

class Position {
  final int row;
  final int col;

  const Position(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position && row == other.row && col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  @override
  String toString() => 'Position($row, $col)';
}

class Match {
  final List<Position> positions;
  final GemType type;

  Match(this.positions, this.type);

  int get length => positions.length;
}

class GameBoard {
  static const int minSize = 5;
  static const int maxSize = 10;
  static const int defaultSize = 8;

  int _rows;
  int _cols;

  int get rows => _rows;
  int get cols => _cols;

  List<List<Gem?>> grid;
  int score = 0;
  int combo = 0;
  final Random _random = Random();

  GameBoard({int size = defaultSize})
      : _rows = size.clamp(minSize, maxSize),
        _cols = size.clamp(minSize, maxSize),
        grid = [] {
    _initializeBoard();
  }

  void _initializeBoard() {
    grid = List.generate(
      _rows,
      (row) => List.generate(_cols, (col) => null),
    );

    // Fill board ensuring no initial matches
    for (int row = 0; row < _rows; row++) {
      for (int col = 0; col < _cols; col++) {
        grid[row][col] = _generateNonMatchingGem(row, col);
      }
    }
  }

  /// Resize the board - creates a new game
  void resize(int newSize) {
    newSize = newSize.clamp(minSize, maxSize);
    if (newSize == _rows) return;

    _rows = newSize;
    _cols = newSize;
    score = 0;
    combo = 0;
    _initializeBoard();
  }

  Gem _generateNonMatchingGem(int row, int col) {
    final availableTypes = List<GemType>.from(GemType.values);

    // Check horizontal (left 2)
    if (col >= 2) {
      final left1 = grid[row][col - 1];
      final left2 = grid[row][col - 2];
      if (left1 != null && left2 != null && left1.type == left2.type) {
        availableTypes.remove(left1.type);
      }
    }

    // Check vertical (up 2)
    if (row >= 2) {
      final up1 = grid[row - 1][col];
      final up2 = grid[row - 2][col];
      if (up1 != null && up2 != null && up1.type == up2.type) {
        availableTypes.remove(up1.type);
      }
    }

    final type = availableTypes[_random.nextInt(availableTypes.length)];
    return Gem(type: type);
  }

  Gem? getGem(int row, int col) {
    if (row < 0 || row >= _rows || col < 0 || col >= _cols) return null;
    return grid[row][col];
  }

  bool canSwap(Position pos1, Position pos2) {
    // Must be adjacent (not diagonal)
    final rowDiff = (pos1.row - pos2.row).abs();
    final colDiff = (pos1.col - pos2.col).abs();
    return (rowDiff == 1 && colDiff == 0) || (rowDiff == 0 && colDiff == 1);
  }

  void swap(Position pos1, Position pos2) {
    final temp = grid[pos1.row][pos1.col];
    grid[pos1.row][pos1.col] = grid[pos2.row][pos2.col];
    grid[pos2.row][pos2.col] = temp;
  }

  bool wouldCreateMatch(Position pos1, Position pos2) {
    // Temporarily swap
    swap(pos1, pos2);
    final hasMatch = findMatches().isNotEmpty;
    // Swap back
    swap(pos1, pos2);
    return hasMatch;
  }

  List<Match> findMatches() {
    final matches = <Match>[];
    final matched = <Position>{};

    // Check horizontal matches
    for (int row = 0; row < _rows; row++) {
      int col = 0;
      while (col < _cols) {
        final gem = grid[row][col];
        if (gem == null) {
          col++;
          continue;
        }

        final positions = <Position>[Position(row, col)];
        int nextCol = col + 1;

        while (nextCol < _cols) {
          final nextGem = grid[row][nextCol];
          if (nextGem != null && nextGem.type == gem.type) {
            positions.add(Position(row, nextCol));
            nextCol++;
          } else {
            break;
          }
        }

        if (positions.length >= 3) {
          matches.add(Match(positions, gem.type));
          matched.addAll(positions);
        }

        col = nextCol;
      }
    }

    // Check vertical matches
    for (int col = 0; col < _cols; col++) {
      int row = 0;
      while (row < _rows) {
        final gem = grid[row][col];
        if (gem == null) {
          row++;
          continue;
        }

        final positions = <Position>[Position(row, col)];
        int nextRow = row + 1;

        while (nextRow < _rows) {
          final nextGem = grid[nextRow][col];
          if (nextGem != null && nextGem.type == gem.type) {
            positions.add(Position(nextRow, col));
            nextRow++;
          } else {
            break;
          }
        }

        if (positions.length >= 3) {
          matches.add(Match(positions, gem.type));
          matched.addAll(positions);
        }

        row = nextRow;
      }
    }

    return matches;
  }

  int removeMatches(List<Match> matches) {
    final toRemove = <Position>{};
    for (final match in matches) {
      toRemove.addAll(match.positions);
    }

    for (final pos in toRemove) {
      grid[pos.row][pos.col] = null;
    }

    // Calculate score with combo multiplier
    int points = 0;
    for (final match in matches) {
      // Base: 50 per gem, bonus for longer matches
      final basePoints = match.length * 50;
      final lengthBonus = match.length > 3 ? (match.length - 3) * 100 : 0;
      points += basePoints + lengthBonus;
    }

    // Apply combo multiplier
    points = (points * (1 + combo * 0.5)).round();

    score += points;
    return points;
  }

  /// Returns map of column -> list of (fromRow, toRow) movements
  Map<int, List<(int, int)>> applyGravity() {
    final movements = <int, List<(int, int)>>{};

    for (int col = 0; col < _cols; col++) {
      movements[col] = [];
      int writeRow = _rows - 1;

      // Move existing gems down
      for (int readRow = _rows - 1; readRow >= 0; readRow--) {
        if (grid[readRow][col] != null) {
          if (readRow != writeRow) {
            grid[writeRow][col] = grid[readRow][col];
            grid[readRow][col] = null;
            movements[col]!.add((readRow, writeRow));
          }
          writeRow--;
        }
      }
    }

    return movements;
  }

  /// Returns map of column -> number of new gems added
  Map<int, int> fillEmptySpaces() {
    final newGems = <int, int>{};

    for (int col = 0; col < _cols; col++) {
      int count = 0;
      for (int row = 0; row < _rows; row++) {
        if (grid[row][col] == null) {
          grid[row][col] = Gem.random();
          count++;
        }
      }
      if (count > 0) {
        newGems[col] = count;
      }
    }

    return newGems;
  }

  bool hasValidMoves() {
    for (int row = 0; row < _rows; row++) {
      for (int col = 0; col < _cols; col++) {
        final pos = Position(row, col);

        // Check swap right
        if (col < _cols - 1) {
          final rightPos = Position(row, col + 1);
          if (wouldCreateMatch(pos, rightPos)) return true;
        }

        // Check swap down
        if (row < _rows - 1) {
          final downPos = Position(row + 1, col);
          if (wouldCreateMatch(pos, downPos)) return true;
        }
      }
    }
    return false;
  }

  void shuffle() {
    // Collect all gems
    final gems = <Gem>[];
    for (int row = 0; row < _rows; row++) {
      for (int col = 0; col < _cols; col++) {
        if (grid[row][col] != null) {
          gems.add(grid[row][col]!);
        }
      }
    }

    // Shuffle
    gems.shuffle(_random);

    // Redistribute
    int idx = 0;
    for (int row = 0; row < _rows; row++) {
      for (int col = 0; col < _cols; col++) {
        grid[row][col] = gems[idx++];
      }
    }
  }

  void reset() {
    score = 0;
    combo = 0;
    _initializeBoard();
  }
}
