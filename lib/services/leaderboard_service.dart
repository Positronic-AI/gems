import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_mode.dart';

class LeaderboardEntry {
  final String name;
  final int score;
  final DateTime date;
  final int gridSize;
  final int? level; // For target mode

  LeaderboardEntry({
    required this.name,
    required this.score,
    required this.date,
    required this.gridSize,
    this.level,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'score': score,
        'date': date.toIso8601String(),
        'gridSize': gridSize,
        'level': level,
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      name: json['name'] as String? ?? '???',
      score: json['score'] as int,
      date: DateTime.parse(json['date'] as String),
      gridSize: json['gridSize'] as int? ?? 8,
      level: json['level'] as int?,
    );
  }
}

class LeaderboardService {
  static const int maxEntries = 5;
  static const String _keyPrefix = 'leaderboard_';

  SharedPreferences? _prefs;

  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  String _getKey(GameModeType mode) => '$_keyPrefix${mode.name}';

  Future<List<LeaderboardEntry>> getLeaderboard(GameModeType mode) async {
    await _ensureInitialized();

    final key = _getKey(mode);
    final jsonString = _prefs!.getString(key);

    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<int?> addScore({
    required GameModeType mode,
    required String name,
    required int score,
    required int gridSize,
    int? level,
  }) async {
    await _ensureInitialized();

    final entries = await getLeaderboard(mode);

    final newEntry = LeaderboardEntry(
      name: name.isEmpty ? '???' : name.toUpperCase(),
      score: score,
      date: DateTime.now(),
      gridSize: gridSize,
      level: level,
    );

    // Add new entry
    entries.add(newEntry);

    // Sort by score descending
    entries.sort((a, b) => b.score.compareTo(a.score));

    // Keep only top entries
    final trimmed = entries.take(maxEntries).toList();

    // Save
    final key = _getKey(mode);
    final jsonString = json.encode(trimmed.map((e) => e.toJson()).toList());
    await _prefs!.setString(key, jsonString);

    // Return rank if made it to leaderboard (1-indexed)
    final rank = trimmed.indexWhere((e) =>
        e.score == newEntry.score &&
        e.date == newEntry.date);

    if (rank >= 0 && rank < maxEntries) {
      return rank + 1;
    }
    return null;
  }

  Future<bool> isHighScore(GameModeType mode, int score) async {
    final entries = await getLeaderboard(mode);

    if (entries.length < maxEntries) return true;

    return score > entries.last.score;
  }

  Future<void> clearLeaderboard(GameModeType mode) async {
    await _ensureInitialized();
    final key = _getKey(mode);
    await _prefs!.remove(key);
  }

  Future<void> clearAllLeaderboards() async {
    await _ensureInitialized();
    for (final mode in GameModeType.values) {
      await clearLeaderboard(mode);
    }
  }
}
