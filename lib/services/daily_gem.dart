import 'package:shared_preferences/shared_preferences.dart';

/// Daily Gem: one board per calendar day, identical for every player on
/// Earth, with ZERO backend — the seed derives deterministically from the
/// date, so every device computes the same board offline. The game's
/// "no network activity" privacy promise stays intact; sharing your score
/// is a plain-text OS share sheet.
class DailyGem {
  /// The shared arena: Moves mode, 30 moves, 8x8. Fixed for comparability.
  static const int gridSize = 8;

  static DateTime today() => DateTime.now();

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
    await prefs.setString('daily_date', dateKey());
    await prefs.setInt('daily_score', score);
    return true;
  }

  static String shareText(int score) =>
      '💎 Daily Gem ${displayDate()} — $score pts (s${seedFor()})\n'
      'Same board, every player, once a day. Beat me:\n'
      'https://play.google.com/store/apps/details?id=ai.positronic.gem_game';
}
