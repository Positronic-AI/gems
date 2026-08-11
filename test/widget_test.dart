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

  group('streak math', () {
    test('consecutive days increment', () {
      final r = DailyGem.computeStreak(
          prevDate: '2026-08-09', prevStreak: 4, passes: 0,
          today: DateTime(2026, 8, 10));
      expect(r.streak, 5);
    });

    test('one missed day with a Free Pass survives and burns it', () {
      final r = DailyGem.computeStreak(
          prevDate: '2026-08-08', prevStreak: 9, passes: 1,
          today: DateTime(2026, 8, 10));
      expect(r.streak, 10);
      expect(r.passes, 0);
    });

    test('one missed day without a pass resets', () {
      final r = DailyGem.computeStreak(
          prevDate: '2026-08-08', prevStreak: 9, passes: 0,
          today: DateTime(2026, 8, 10));
      expect(r.streak, 1);
    });

    test('two missed days reset even with passes', () {
      final r = DailyGem.computeStreak(
          prevDate: '2026-08-06', prevStreak: 20, passes: 2,
          today: DateTime(2026, 8, 10));
      expect(r.streak, 1);
    });

    test('pass earned at 7-day multiples, banked to max 2', () {
      final r7 = DailyGem.computeStreak(
          prevDate: '2026-08-09', prevStreak: 6, passes: 0,
          today: DateTime(2026, 8, 10));
      expect(r7.streak, 7);
      expect(r7.passes, 1);
      final r14 = DailyGem.computeStreak(
          prevDate: '2026-08-09', prevStreak: 13, passes: 2,
          today: DateTime(2026, 8, 10));
      expect(r14.streak, 14);
      expect(r14.passes, 2); // capped
    });

    test('month boundary counts as consecutive', () {
      final r = DailyGem.computeStreak(
          prevDate: '2026-08-31', prevStreak: 3, passes: 0,
          today: DateTime(2026, 9, 1));
      expect(r.streak, 4);
    });
  });
}
