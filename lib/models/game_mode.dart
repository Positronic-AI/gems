enum GameModeType {
  timed,
  moves,
  target,
  zen,
}

extension GameModeTypeExtension on GameModeType {
  String get displayName {
    switch (this) {
      case GameModeType.timed:
        return 'Timed';
      case GameModeType.moves:
        return 'Moves';
      case GameModeType.target:
        return 'Target';
      case GameModeType.zen:
        return 'Zen';
    }
  }

  String get description {
    switch (this) {
      case GameModeType.timed:
        return 'Race against the clock! Score as high as you can before time runs out.';
      case GameModeType.moves:
        return 'Limited moves! Make every swap count to maximize your score.';
      case GameModeType.target:
        return 'Reach the target score to advance. Each level gets harder!';
      case GameModeType.zen:
        return 'Relax and play forever. No pressure, no end.';
    }
  }

  String get icon {
    switch (this) {
      case GameModeType.timed:
        return '⏱️';
      case GameModeType.moves:
        return '🎯';
      case GameModeType.target:
        return '🏆';
      case GameModeType.zen:
        return '🧘';
    }
  }
}

class GameMode {
  final GameModeType type;
  final int timeSeconds; // For timed mode
  final int maxMoves; // For moves mode
  final int targetScore; // For target mode
  final int level; // For target mode progression

  const GameMode.timed({this.timeSeconds = 90})
      : type = GameModeType.timed,
        maxMoves = 0,
        targetScore = 0,
        level = 0;

  const GameMode.moves({this.maxMoves = 30})
      : type = GameModeType.moves,
        timeSeconds = 0,
        targetScore = 0,
        level = 0;

  const GameMode.target({this.level = 1})
      : type = GameModeType.target,
        timeSeconds = 0,
        maxMoves = 0,
        targetScore = 1000 + (level - 1) * 500; // 1000, 1500, 2000, etc.

  const GameMode.zen()
      : type = GameModeType.zen,
        timeSeconds = 0,
        maxMoves = 0,
        targetScore = 0,
        level = 0;

  GameMode nextLevel() {
    if (type == GameModeType.target) {
      return GameMode.target(level: level + 1);
    }
    return this;
  }

  String get leaderboardKey => type.name;
}
