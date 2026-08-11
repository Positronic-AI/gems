import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tile styles — the MATERIAL axis (palettes are the COLOR axis).
/// classic = flat, glass = lit/shiny, wood = matte extruded with grain.
/// Free for everyone in v1; future styles can join the streak ladder.
enum TileStyle { classic, glass, wood }

extension TileStyleExt on TileStyle {
  String get displayName => switch (this) {
        TileStyle.classic => 'Classic',
        TileStyle.glass => 'Glass',
        TileStyle.wood => 'Wood',
      };

  String get description => switch (this) {
        TileStyle.classic => 'Flat and clean — the original look',
        TileStyle.glass => 'Lit from above, glints and glow',
        TileStyle.wood => 'Matte grain, carved tiles, nothing shiny',
      };
}

class ActiveTileStyle {
  static TileStyle current = TileStyle.glass;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('tile_style');
    current = TileStyle.values.firstWhere((s) => s.name == name,
        orElse: () => TileStyle.glass);
  }

  static Future<void> select(TileStyle s) async {
    current = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tile_style', s.name);
  }
}

/// Subtle deterministic wood grain: thin wavy strokes, no randomness at
/// paint time (stable across frames).
class WoodGrainPainter extends CustomPainter {
  final Color base;

  WoodGrainPainter(this.base);

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()
      ..color = Colors.black.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.15 + i * 0.18);
      final path = Path()..moveTo(0, y);
      path.cubicTo(size.width * 0.3, y - size.height * 0.04,
          size.width * 0.6, y + size.height * 0.05, size.width, y - 1);
      canvas.drawPath(path, dark);
    }
  }

  @override
  bool shouldRepaint(covariant WoodGrainPainter old) => old.base != base;
}
