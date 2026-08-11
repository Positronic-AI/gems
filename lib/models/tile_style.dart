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

/// Deterministic per-tile wood grain: the seed (gem id) varies line
/// phase, spacing, and tone so every tile is its own plank — like real
/// wood — while staying stable across repaints.
class WoodGrainPainter extends CustomPainter {
  final Color base;
  final int seed;

  WoodGrainPainter(this.base, {this.seed = 0});

  double _n(int i) => (((seed * 73856093) ^ (i * 19349663)) % 1000) / 1000.0;

  @override
  void paint(Canvas canvas, Size size) {
    final lines = 4 + (seed % 3); // 4-6 grain lines per plank
    for (var i = 0; i < lines; i++) {
      final tone = 0.06 + _n(i) * 0.08;
      final paint = Paint()
        ..color = Colors.black.withOpacity(tone)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 + _n(i + 7) * 0.8;
      final y = size.height * ((i + 0.5 + _n(i + 13) * 0.5) / (lines + 1));
      final w1 = (_n(i + 3) - 0.5) * size.height * 0.14;
      final w2 = (_n(i + 5) - 0.5) * size.height * 0.14;
      final path = Path()..moveTo(0, y);
      path.cubicTo(size.width * 0.33, y + w1, size.width * 0.66, y + w2,
          size.width, y + (w1 + w2) / 3);
      canvas.drawPath(path, paint);
    }
    // Occasional knot (about 1 in 4 tiles)
    if (seed % 4 == 0) {
      final kx = size.width * (0.25 + _n(21) * 0.5);
      final ky = size.height * (0.25 + _n(22) * 0.5);
      final knot = Paint()
        ..color = Colors.black.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(kx, ky),
              width: size.width * 0.16,
              height: size.height * 0.10),
          knot);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(kx, ky),
              width: size.width * 0.08,
              height: size.height * 0.05),
          knot);
    }
  }

  @override
  bool shouldRepaint(covariant WoodGrainPainter old) =>
      old.base != base || old.seed != seed;
}
