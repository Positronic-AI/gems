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

enum MatchPattern {
  horizontal3,   // Basic 3 horizontal
  vertical3,     // Basic 3 vertical
  horizontal4,   // 4 in a row horizontal -> line bomb (horizontal)
  vertical4,     // 4 in a row vertical -> line bomb (vertical)
  horizontal5,   // 5+ in a row -> color bomb
  vertical5,     // 5+ in a row -> color bomb
  lShape,        // L shape -> radial bomb
  tShape,        // T shape -> radial bomb
}

class Match {
  final List<Position> positions;
  final GemType type;
  final MatchPattern pattern;
  final Position? powerUpPosition; // Where to place the power-up (intersection or center)

  Match(this.positions, this.type, {this.pattern = MatchPattern.horizontal3, this.powerUpPosition});

  int get length => positions.length;

  /// Determines what power-up this match should create (if any)
  PowerUpType get powerUpType {
    switch (pattern) {
      case MatchPattern.horizontal5:
      case MatchPattern.vertical5:
        return PowerUpType.colorBomb;
      case MatchPattern.horizontal4:
        return PowerUpType.lineHorizontal;
      case MatchPattern.vertical4:
        return PowerUpType.lineVertical;
      case MatchPattern.lShape:
      case MatchPattern.tShape:
        return PowerUpType.radial;
      case MatchPattern.horizontal3:
      case MatchPattern.vertical3:
        return PowerUpType.none;
    }
  }
}

/// Represents a special match pattern (L, T, or cross shape)
class SpecialMatch {
  final Match horizontalMatch;
  final Match verticalMatch;
  final Position intersection;
  final MatchPattern pattern;

  SpecialMatch({
    required this.horizontalMatch,
    required this.verticalMatch,
    required this.intersection,
    required this.pattern,
  });

  Set<Position> get allPositions {
    return {...horizontalMatch.positions, ...verticalMatch.positions};
  }
}

/// Result of removing matches from the board
class MatchRemovalResult {
  final int points;
  final int gemsCleared;
  final Map<Position, PowerUpType> powerUpsCreated;
  final List<Position> powerUpsActivated;

  MatchRemovalResult({
    required this.points,
    required this.gemsCleared,
    required this.powerUpsCreated,
    required this.powerUpsActivated,
  });
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

  /// Every game has a seed; same seed + same moves = same game. Shown to the
  /// player and recorded on the leaderboard.
  final int seed;
  late Random _random;

  GameBoard({int size = defaultSize, int? seed})
      : seed = seed ?? Random().nextInt(1000000),
        _rows = size.clamp(minSize, maxSize),
        _cols = size.clamp(minSize, maxSize),
        grid = [] {
    _random = Random(this.seed);
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

  /// Find all matches on the board, classifying them by pattern type.
  /// If swapPosition is provided, power-ups will be placed there when applicable.
  List<Match> findMatches({Position? swapPosition}) {
    // First, find all horizontal runs
    final horizontalRuns = <Match>[];
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
          final pattern = positions.length >= 5
              ? MatchPattern.horizontal5
              : positions.length == 4
                  ? MatchPattern.horizontal4
                  : MatchPattern.horizontal3;
          horizontalRuns.add(Match(positions, gem.type, pattern: pattern));
        }

        col = nextCol;
      }
    }

    // Find all vertical runs
    final verticalRuns = <Match>[];
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
          final pattern = positions.length >= 5
              ? MatchPattern.vertical5
              : positions.length == 4
                  ? MatchPattern.vertical4
                  : MatchPattern.vertical3;
          verticalRuns.add(Match(positions, gem.type, pattern: pattern));
        }

        row = nextRow;
      }
    }

    // Find intersections (L and T shapes)
    final specialMatches = <SpecialMatch>[];
    final usedHorizontal = <Match>{};
    final usedVertical = <Match>{};

    for (final hMatch in horizontalRuns) {
      for (final vMatch in verticalRuns) {
        if (hMatch.type != vMatch.type) continue;

        // Find intersection point
        for (final hPos in hMatch.positions) {
          for (final vPos in vMatch.positions) {
            if (hPos == vPos) {
              // Found intersection!
              // Determine if it's L, T, or cross shape
              final isLShape = _isLShape(hMatch, vMatch, hPos);
              final isTShape = _isTShape(hMatch, vMatch, hPos);

              if (isLShape || isTShape) {
                specialMatches.add(SpecialMatch(
                  horizontalMatch: hMatch,
                  verticalMatch: vMatch,
                  intersection: hPos,
                  pattern: isTShape ? MatchPattern.tShape : MatchPattern.lShape,
                ));
                usedHorizontal.add(hMatch);
                usedVertical.add(vMatch);
              }
            }
          }
        }
      }
    }

    // Build final match list
    final matches = <Match>[];

    // Add special matches (L/T shapes) as single matches
    for (final special in specialMatches) {
      final allPositions = special.allPositions.toList();
      // Determine power-up position: prefer swap position if it's in the match, else intersection
      Position powerUpPos = special.intersection;
      if (swapPosition != null && allPositions.contains(swapPosition)) {
        powerUpPos = swapPosition;
      }
      matches.add(Match(
        allPositions,
        special.horizontalMatch.type,
        pattern: special.pattern,
        powerUpPosition: powerUpPos,
      ));
    }

    // Add remaining horizontal runs (not part of special matches)
    for (final hMatch in horizontalRuns) {
      if (!usedHorizontal.contains(hMatch)) {
        // Determine power-up position
        Position? powerUpPos;
        if (hMatch.pattern != MatchPattern.horizontal3) {
          if (swapPosition != null && hMatch.positions.contains(swapPosition)) {
            powerUpPos = swapPosition;
          } else {
            // Use middle position
            powerUpPos = hMatch.positions[hMatch.positions.length ~/ 2];
          }
        }
        matches.add(Match(
          hMatch.positions,
          hMatch.type,
          pattern: hMatch.pattern,
          powerUpPosition: powerUpPos,
        ));
      }
    }

    // Add remaining vertical runs (not part of special matches)
    for (final vMatch in verticalRuns) {
      if (!usedVertical.contains(vMatch)) {
        // Determine power-up position
        Position? powerUpPos;
        if (vMatch.pattern != MatchPattern.vertical3) {
          if (swapPosition != null && vMatch.positions.contains(swapPosition)) {
            powerUpPos = swapPosition;
          } else {
            // Use middle position
            powerUpPos = vMatch.positions[vMatch.positions.length ~/ 2];
          }
        }
        matches.add(Match(
          vMatch.positions,
          vMatch.type,
          pattern: vMatch.pattern,
          powerUpPosition: powerUpPos,
        ));
      }
    }

    return matches;
  }

  /// Check if horizontal and vertical matches form an L shape at intersection
  bool _isLShape(Match hMatch, Match vMatch, Position intersection) {
    // L shape: intersection is at a corner of both matches
    final hPositions = hMatch.positions;
    final vPositions = vMatch.positions;

    final isHorizontalEnd = hPositions.first == intersection || hPositions.last == intersection;
    final isVerticalEnd = vPositions.first == intersection || vPositions.last == intersection;

    return isHorizontalEnd && isVerticalEnd;
  }

  /// Check if horizontal and vertical matches form a T shape at intersection
  bool _isTShape(Match hMatch, Match vMatch, Position intersection) {
    final hPositions = hMatch.positions;
    final vPositions = vMatch.positions;

    final isHorizontalEnd = hPositions.first == intersection || hPositions.last == intersection;
    final isVerticalEnd = vPositions.first == intersection || vPositions.last == intersection;
    final isHorizontalMiddle = !isHorizontalEnd && hPositions.contains(intersection);
    final isVerticalMiddle = !isVerticalEnd && vPositions.contains(intersection);

    // T shape: one is at end, other is in middle
    return (isHorizontalEnd && isVerticalMiddle) || (isVerticalEnd && isHorizontalMiddle);
  }

  /// Result of removing matches, including any power-ups created
  /// and any positions cleared by power-up activations
  MatchRemovalResult removeMatches(List<Match> matches) {
    final toRemove = <Position>{};
    final powerUpsCreated = <Position, PowerUpType>{};
    final powerUpsActivated = <Position>[];

    // First pass: collect all positions to remove and identify power-up creation
    for (final match in matches) {
      final powerUpType = match.powerUpType;

      if (powerUpType != PowerUpType.none && match.powerUpPosition != null) {
        // This match creates a power-up
        powerUpsCreated[match.powerUpPosition!] = powerUpType;
        // Remove all positions except the power-up position
        for (final pos in match.positions) {
          if (pos != match.powerUpPosition) {
            toRemove.add(pos);
          }
        }
      } else {
        // Regular match - remove all positions
        toRemove.addAll(match.positions);
      }
    }

    // Check for power-up gems being removed (activation)
    for (final pos in toRemove.toList()) {
      final gem = grid[pos.row][pos.col];
      if (gem != null && gem.hasPowerUp) {
        powerUpsActivated.add(pos);
        // Add positions cleared by this power-up
        final clearedByPowerUp = _getPowerUpClearPositions(pos, gem.powerUp);
        toRemove.addAll(clearedByPowerUp);
      }
    }

    // Remove gems (but not power-up creation positions)
    for (final pos in toRemove) {
      if (!powerUpsCreated.containsKey(pos)) {
        grid[pos.row][pos.col] = null;
      }
    }

    // Create power-up gems
    for (final entry in powerUpsCreated.entries) {
      final pos = entry.key;
      final powerUpType = entry.value;
      final existingGem = grid[pos.row][pos.col];
      if (existingGem != null) {
        grid[pos.row][pos.col] = existingGem.copyWith(powerUp: powerUpType);
      }
    }

    // Calculate score with combo multiplier
    int points = 0;
    final totalCleared = toRemove.length;

    for (final match in matches) {
      // Base: 50 per gem, bonus for longer matches
      final basePoints = match.length * 50;
      final lengthBonus = match.length > 3 ? (match.length - 3) * 100 : 0;
      // Bonus for creating power-ups
      final powerUpBonus = match.powerUpType != PowerUpType.none ? 200 : 0;
      points += basePoints + lengthBonus + powerUpBonus;
    }

    // Bonus for power-up activations
    points += powerUpsActivated.length * 300;

    // Apply combo multiplier
    points = (points * (1 + combo * 0.5)).round();

    score += points;
    return MatchRemovalResult(
      points: points,
      gemsCleared: totalCleared,
      powerUpsCreated: powerUpsCreated,
      powerUpsActivated: powerUpsActivated,
    );
  }

  /// Get all positions that would be cleared by activating a power-up
  Set<Position> _getPowerUpClearPositions(Position pos, PowerUpType powerUp) {
    final positions = <Position>{};

    switch (powerUp) {
      case PowerUpType.lineHorizontal:
        // Clear entire row
        for (int col = 0; col < _cols; col++) {
          positions.add(Position(pos.row, col));
        }
        break;

      case PowerUpType.lineVertical:
        // Clear entire column
        for (int row = 0; row < _rows; row++) {
          positions.add(Position(row, pos.col));
        }
        break;

      case PowerUpType.radial:
        // Clear 3x3 area
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            final newRow = pos.row + dr;
            final newCol = pos.col + dc;
            if (newRow >= 0 && newRow < _rows && newCol >= 0 && newCol < _cols) {
              positions.add(Position(newRow, newCol));
            }
          }
        }
        break;

      case PowerUpType.colorBomb:
        // Color bomb is handled differently - needs to know what it was swapped with
        // This is handled in activateColorBomb
        break;

      case PowerUpType.none:
        break;
    }

    return positions;
  }

  /// Activate a color bomb by clearing all gems of the given color
  Set<Position> activateColorBomb(Position bombPos, GemType targetColor) {
    final positions = <Position>{};

    for (int row = 0; row < _rows; row++) {
      for (int col = 0; col < _cols; col++) {
        final gem = grid[row][col];
        if (gem != null && gem.type == targetColor) {
          positions.add(Position(row, col));
        }
      }
    }

    // Also include the bomb position itself
    positions.add(bombPos);

    return positions;
  }

  /// Check if a swap involves a color bomb
  bool isColorBombSwap(Position pos1, Position pos2) {
    final gem1 = grid[pos1.row][pos1.col];
    final gem2 = grid[pos2.row][pos2.col];
    return (gem1?.powerUp == PowerUpType.colorBomb) ||
           (gem2?.powerUp == PowerUpType.colorBomb);
  }

  /// Get the positions to clear when two power-ups are combined
  Set<Position> getCombinedPowerUpClearPositions(Position pos1, Position pos2) {
    final gem1 = grid[pos1.row][pos1.col];
    final gem2 = grid[pos2.row][pos2.col];

    if (gem1 == null || gem2 == null) return {};
    if (!gem1.hasPowerUp || !gem2.hasPowerUp) return {};

    final positions = <Position>{};
    final type1 = gem1.powerUp;
    final type2 = gem2.powerUp;

    // Color bomb + anything
    if (type1 == PowerUpType.colorBomb || type2 == PowerUpType.colorBomb) {
      if (type1 == PowerUpType.colorBomb && type2 == PowerUpType.colorBomb) {
        // Two color bombs = clear entire board!
        for (int row = 0; row < _rows; row++) {
          for (int col = 0; col < _cols; col++) {
            positions.add(Position(row, col));
          }
        }
      } else {
        // Color bomb + other power-up = turn all gems of that color into that power-up type
        final colorBombPos = type1 == PowerUpType.colorBomb ? pos1 : pos2;
        final otherPos = type1 == PowerUpType.colorBomb ? pos2 : pos1;
        final otherGem = type1 == PowerUpType.colorBomb ? gem2 : gem1;

        // Clear all of target color with the other power-up's effect
        for (int row = 0; row < _rows; row++) {
          for (int col = 0; col < _cols; col++) {
            final gem = grid[row][col];
            if (gem != null && gem.type == otherGem.type) {
              positions.add(Position(row, col));
              // Add the effect of the other power-up at each position
              positions.addAll(_getPowerUpClearPositions(Position(row, col), otherGem.powerUp));
            }
          }
        }
        positions.add(colorBombPos);
        positions.add(otherPos);
      }
    }
    // Line + Line = cross
    else if ((type1 == PowerUpType.lineHorizontal || type1 == PowerUpType.lineVertical) &&
             (type2 == PowerUpType.lineHorizontal || type2 == PowerUpType.lineVertical)) {
      // Clear row and column of both positions
      for (int col = 0; col < _cols; col++) {
        positions.add(Position(pos1.row, col));
        positions.add(Position(pos2.row, col));
      }
      for (int row = 0; row < _rows; row++) {
        positions.add(Position(row, pos1.col));
        positions.add(Position(row, pos2.col));
      }
    }
    // Line + Radial = 3-row or 3-column clear
    else if ((type1 == PowerUpType.lineHorizontal || type1 == PowerUpType.lineVertical) &&
             type2 == PowerUpType.radial ||
             type1 == PowerUpType.radial &&
             (type2 == PowerUpType.lineHorizontal || type2 == PowerUpType.lineVertical)) {
      final lineType = type1 == PowerUpType.radial ? type2 : type1;
      final centerPos = type1 == PowerUpType.radial ? pos1 : pos2;

      if (lineType == PowerUpType.lineHorizontal) {
        // Clear 3 rows
        for (int dr = -1; dr <= 1; dr++) {
          final row = centerPos.row + dr;
          if (row >= 0 && row < _rows) {
            for (int col = 0; col < _cols; col++) {
              positions.add(Position(row, col));
            }
          }
        }
      } else {
        // Clear 3 columns
        for (int dc = -1; dc <= 1; dc++) {
          final col = centerPos.col + dc;
          if (col >= 0 && col < _cols) {
            for (int row = 0; row < _rows; row++) {
              positions.add(Position(row, col));
            }
          }
        }
      }
    }
    // Radial + Radial = 5x5 explosion
    else if (type1 == PowerUpType.radial && type2 == PowerUpType.radial) {
      final centerRow = (pos1.row + pos2.row) ~/ 2;
      final centerCol = (pos1.col + pos2.col) ~/ 2;
      for (int dr = -2; dr <= 2; dr++) {
        for (int dc = -2; dc <= 2; dc++) {
          final row = centerRow + dr;
          final col = centerCol + dc;
          if (row >= 0 && row < _rows && col >= 0 && col < _cols) {
            positions.add(Position(row, col));
          }
        }
      }
    }

    return positions;
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
          grid[row][col] = Gem.randomWith(_random);
          count++;
        }
      }
      if (count > 0) {
        newGems[col] = count;
      }
    }

    return newGems;
  }

  /// Count distinct match-producing swaps on the board. Tappable power-ups
  /// are bonuses, not moves — they are deliberately not counted here.
  int countValidMoves() {
    int count = 0;
    for (int row = 0; row < _rows; row++) {
      for (int col = 0; col < _cols; col++) {
        final pos = Position(row, col);
        if (col < _cols - 1 && wouldCreateMatch(pos, Position(row, col + 1))) {
          count++;
        }
        if (row < _rows - 1 && wouldCreateMatch(pos, Position(row + 1, col))) {
          count++;
        }
      }
    }
    return count;
  }

  /// Deep-copy the grid (Gems are immutable — row copies suffice). Used by
  /// undo: snapshot before a move, restore to take it back.
  List<List<Gem?>> snapshotGrid() =>
      grid.map((row) => List<Gem?>.from(row)).toList();

  void restoreGrid(List<List<Gem?>> snapshot) {
    grid = snapshot.map((row) => List<Gem?>.from(row)).toList();
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
    // Re-seed: reset means "restart THIS game" — same seed, same board,
    // same refills. A different board is a new game from mode select.
    _random = Random(seed);
    _initializeBoard();
  }
}
