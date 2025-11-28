import 'package:flutter/material.dart';
import 'dart:math';

enum GemType {
  red,
  orange,
  yellow,
  green,
  blue,
  purple,
  white,
}

extension GemTypeExtension on GemType {
  Color get color {
    switch (this) {
      case GemType.red:
        return const Color(0xFFE53935);
      case GemType.orange:
        return const Color(0xFFFF9800);
      case GemType.yellow:
        return const Color(0xFFFFEB3B);
      case GemType.green:
        return const Color(0xFF4CAF50);
      case GemType.blue:
        return const Color(0xFF2196F3);
      case GemType.purple:
        return const Color(0xFF9C27B0);
      case GemType.white:
        return const Color(0xFFE0E0E0);
    }
  }

  Color get glowColor {
    switch (this) {
      case GemType.red:
        return const Color(0xFFFF5252);
      case GemType.orange:
        return const Color(0xFFFFB74D);
      case GemType.yellow:
        return const Color(0xFFFFF176);
      case GemType.green:
        return const Color(0xFF81C784);
      case GemType.blue:
        return const Color(0xFF64B5F6);
      case GemType.purple:
        return const Color(0xFFBA68C8);
      case GemType.white:
        return const Color(0xFFFFFFFF);
    }
  }

  IconData get icon {
    switch (this) {
      case GemType.red:
        return Icons.favorite;
      case GemType.orange:
        return Icons.local_fire_department;
      case GemType.yellow:
        return Icons.star;
      case GemType.green:
        return Icons.eco;
      case GemType.blue:
        return Icons.water_drop;
      case GemType.purple:
        return Icons.diamond;
      case GemType.white:
        return Icons.ac_unit; // snowflake - more visible
    }
  }

  Color get iconColor {
    switch (this) {
      case GemType.white:
        return const Color(0xFF4A4A5A); // dark color for contrast on white gem
      default:
        return const Color(0xFFFFFFFF).withOpacity(0.9);
    }
  }
}

class Gem {
  final GemType type;
  final int id;
  bool isMatched;
  bool isNew;

  static int _nextId = 0;
  static final Random _random = Random();

  Gem({
    required this.type,
    this.isMatched = false,
    this.isNew = false,
  }) : id = _nextId++;

  factory Gem.random() {
    final type = GemType.values[_random.nextInt(GemType.values.length)];
    return Gem(type: type, isNew: true);
  }

  Gem copyWith({
    GemType? type,
    bool? isMatched,
    bool? isNew,
  }) {
    return Gem(
      type: type ?? this.type,
      isMatched: isMatched ?? this.isMatched,
      isNew: isNew ?? this.isNew,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Gem && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
