import 'package:flutter_test/flutter_test.dart';
import 'package:gem_game/models/game_board.dart';
import 'package:gem_game/services/daily_gem.dart';

void main() {
  test('same seed produces the same board', () {
    final a = GameBoard(size: 8, seed: 424242);
    final b = GameBoard(size: 8, seed: 424242);
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        expect(a.grid[r][c]!.type, b.grid[r][c]!.type,
            reason: 'mismatch at $r,$c');
      }
    }
    expect(a.seed, 424242);
  });

  test('reset replays the same board', () {
    final board = GameBoard(size: 6, seed: 777);
    final original = [
      for (var r = 0; r < 6; r++) [for (var c = 0; c < 6; c++) board.grid[r][c]!.type]
    ];
    board.reset();
    for (var r = 0; r < 6; r++) {
      for (var c = 0; c < 6; c++) {
        expect(board.grid[r][c]!.type, original[r][c]);
      }
    }
  });

  test('different seeds differ', () {
    final a = GameBoard(size: 8, seed: 1);
    final b = GameBoard(size: 8, seed: 2);
    var same = true;
    for (var r = 0; r < 8 && same; r++) {
      for (var c = 0; c < 8; c++) {
        if (a.grid[r][c]!.type != b.grid[r][c]!.type) { same = false; break; }
      }
    }
    expect(same, false);
  });

  test('daily seed is deterministic and date-scoped', () {
    final a = DailyGem.seedFor(DateTime(2026, 8, 10));
    final b = DailyGem.seedFor(DateTime(2026, 8, 10));
    final c = DailyGem.seedFor(DateTime(2026, 8, 11));
    expect(a, b);
    expect(a == c, false);
    expect(a >= 0 && a < 1000000, true);
  });

  test('daily board is identical across devices (seed + fixed size)', () {
    final s1 = DailyGem.seedFor(DateTime(2026, 8, 10));
    final b1 = GameBoard(size: DailyGem.gridSize, seed: s1);
    final b2 = GameBoard(size: DailyGem.gridSize, seed: s1);
    for (var r = 0; r < DailyGem.gridSize; r++) {
      for (var c = 0; c < DailyGem.gridSize; c++) {
        expect(b1.grid[r][c]!.type, b2.grid[r][c]!.type);
      }
    }
  });
}
