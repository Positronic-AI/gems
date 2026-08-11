import 'package:shared_preferences/shared_preferences.dart';

/// Daily Gem: one board per calendar day, identical for every player on
/// Earth, with ZERO backend — the seed derives deterministically from the
/// date, so every device computes the same board offline. The game's
/// "no network activity" privacy promise stays intact; sharing your score
/// is a plain-text OS share sheet.
class DailyGem {
  /// The shared arena: Moves mode, 30 moves, 8x8. Fixed for comparability.
  static const int gridSize = 8;

  /// Debug time machine: shifts "today" by N days (Settings → tap the
  /// version 7×). Local cosmetics only, so simulating days is harmless —
  /// and it's the only way to QA streak behavior without waiting a month.
  static int debugDayOffset = 0;

  static Future<void> loadDebugOffset() async {
    final prefs = await SharedPreferences.getInstance();
    debugDayOffset = prefs.getInt('debug_day_offset') ?? 0;
    // Migration: dailies played on 1.2.0 recorded a date but no streak —
    // that play deserves to count as day one of the chain.
    if (prefs.getString('daily_date') != null &&
        prefs.getInt('daily_streak') == null) {
      await prefs.setInt('daily_streak', 1);
      final best = prefs.getInt('daily_best_streak') ?? 0;
      if (best < 1) await prefs.setInt('daily_best_streak', 1);
    }
  }

  static Future<void> setDebugOffset(int days) async {
    debugDayOffset = days;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('debug_day_offset', days);
  }

  static DateTime today() =>
      DateTime.now().add(Duration(days: debugDayOffset));

  static String dateKey([DateTime? d]) {
    final t = d ?? today();
    return '${t.year.toString().padLeft(4, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }

  static String displayDate([DateTime? d]) {
    final t = d ?? today();
    return '${t.month}/${t.day}';
  }

  /// Deterministic date → seed. FNV-1a over the date string, folded into
  /// the same 0..999999 space regular seeds use. Pure integer math — stable
  /// on every platform Dart runs on.
  static int seedFor([DateTime? d]) {
    const fnvPrime = 0x01000193;
    var hash = 0x811c9dc5;
    for (final c in dateKey(d).codeUnits) {
      hash = ((hash ^ c) * fnvPrime) & 0xFFFFFFFF;
    }
    return hash % 1000000;
  }

  /// First completion of the day is YOUR daily score (replays are practice —
  /// they never overwrite it; that's what makes posted scores honest).
  static Future<int?> todayScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('daily_date') != dateKey()) return null;
    return prefs.getInt('daily_score');
  }

  static Future<bool> recordScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('daily_date') == dateKey()) return false; // replay
    final st = computeStreak(
      prevDate: prefs.getString('daily_date'),
      prevStreak: prefs.getInt('daily_streak') ?? 0,
      passes: prefs.getInt('daily_passes') ?? 0,
      today: today(),
    );
    await prefs.setString('daily_date', dateKey());
    await prefs.setInt('daily_score', score);
    await prefs.setInt('daily_streak', st.streak);
    await prefs.setInt('daily_passes', st.passes);
    // Best-ever streak: unlocks key off this, so a broken streak never
    // re-locks what you earned.
    final best = prefs.getInt('daily_best_streak') ?? 0;
    if (st.streak > best) {
      await prefs.setInt('daily_best_streak', st.streak);
    }
    return true;
  }

  /// Debug only: force best-ever streak (Time Machine unlock testing).
  static Future<void> debugSetBestStreak(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_best_streak', v);
  }

  static Future<int> bestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('daily_best_streak') ?? 0;
  }

  /// Current streak for display: today's or yesterday's chain (a streak
  /// isn't "broken" until a full day is actually missed — showing 0 at
  /// 8 AM before you've played would be demoralizing and wrong).
  static Future<int> currentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString('daily_date');
    final streak = prefs.getInt('daily_streak') ?? 0;
    if (last == null) return 0;
    final gap = _gapDays(last, today());
    if (gap <= 1) return streak;
    // Missed day(s): a banked pass keeps the flame alive for ONE miss.
    final passes = prefs.getInt('daily_passes') ?? 0;
    if (gap == 2 && passes > 0) return streak;
    return 0;
  }

  /// Debug: wipe every daily/streak key and return to real time.
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in [
      'daily_date', 'daily_score', 'daily_streak',
      'daily_passes', 'daily_best_streak', 'debug_day_offset',
    ]) {
      await prefs.remove(k);
    }
    debugDayOffset = 0;
  }

  static Future<int> freePasses() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('daily_passes') ?? 0;
  }

  static int _gapDays(String prevKey, DateTime now) {
    final p = prevKey.split('-').map(int.parse).toList();
    final prev = DateTime(p[0], p[1], p[2]);
    return DateTime(now.year, now.month, now.day).difference(prev).inDays;
  }

  /// Pure streak math (testable): plays today given the previous play date.
  /// gap 1 → streak continues; gap 2 with a banked Free Pass → the pass
  /// burns and the streak survives; otherwise restart at 1. A Free Pass is
  /// earned at every 7-day multiple, banked to a max of 2.
  static ({int streak, int passes}) computeStreak({
    required String? prevDate,
    required int prevStreak,
    required int passes,
    required DateTime today,
  }) {
    int streak;
    int p = passes;
    if (prevDate == null) {
      streak = 1;
    } else {
      final gap = _gapDays(prevDate, today);
      if (gap == 1) {
        streak = prevStreak + 1;
      } else if (gap == 2 && p > 0) {
        p -= 1; // Free Pass burns, flame survives
        streak = prevStreak + 1;
      } else {
        streak = 1;
      }
    }
    if (streak > 0 && streak % 7 == 0 && p < 2) p += 1;
    return (streak: streak, passes: p);
  }

  static String shareText(int score, {int streak = 0, String? title}) {
    final flame = streak >= 2 ? ' · 🔥 $streak-day streak' : '';
    final honor = title != null ? ' · $title' : '';
    return '💎 Daily Gem ${displayDate()} — $score pts (s${seedFor()})$flame$honor\n'
        'Same board, every player, once a day. Beat me:\n'
        'https://play.google.com/store/apps/details?id=ai.positronic.gem_game';
  }
}
