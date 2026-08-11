import 'package:flutter/material.dart';
import '../models/gem.dart';
import '../models/tile_style.dart';

class GemWidget extends StatelessWidget {
  final Gem gem;
  final double size;
  final bool isSelected;
  final bool isHinted;
  final VoidCallback? onTap;

  const GemWidget({
    super.key,
    required this.gem,
    required this.size,
    this.isSelected = false,
    this.isHinted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = ActiveTileStyle.current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.08),
        child: style == TileStyle.wood ? _buildWoodTile() : _buildFlatOrGlassTile(style),
      ),
    );
  }

  Widget _buildFlatOrGlassTile(TileStyle style) {
    return Container(
      decoration: BoxDecoration(
        gradient: style == TileStyle.glass
            ? _buildGlassGradient()
            : _buildGradient(),
        borderRadius: BorderRadius.circular(size * 0.2),
        border: isSelected
            ? Border.all(color: Colors.white, width: 3)
            : isHinted
                ? Border.all(color: Colors.yellow.withOpacity(0.8), width: 2)
                : gem.hasPowerUp
                    ? Border.all(color: _getPowerUpGlowColor(), width: 3)
                    : null,
        boxShadow: [
          if (gem.hasPowerUp)
            BoxShadow(
              color: _getPowerUpGlowColor().withOpacity(0.7),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          BoxShadow(
            color: gem.type.glowColor.withOpacity(isSelected ? 0.8 : gem.hasPowerUp ? 0.6 : 0.4),
            blurRadius: isSelected ? 15 : gem.hasPowerUp ? 12 : 8,
            spreadRadius: isSelected ? 2 : gem.hasPowerUp ? 1 : 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: style == TileStyle.glass
          ? ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.2),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.32),
                            Colors.white.withOpacity(0.06),
                            Colors.transparent,
                            Colors.black.withOpacity(0.18),
                          ],
                          stops: const [0.0, 0.25, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Light transmitted through the glass pools at the bottom
                  Positioned(
                    left: size * 0.10,
                    right: size * 0.10,
                    bottom: 0,
                    height: size * 0.30,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.bottomCenter,
                          radius: 1.1,
                          colors: [
                            gem.type.glowColor.withOpacity(0.45),
                            gem.type.glowColor.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Crisp specular glint
                  Positioned(
                    left: size * 0.13,
                    top: size * 0.09,
                    child: Transform.rotate(
                      angle: -0.35,
                      child: Container(
                        width: size * 0.34,
                        height: size * 0.13,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(size * 0.12),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.75),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Bright top rim — the glass edge catching light
                  Positioned(
                    left: size * 0.06,
                    right: size * 0.3,
                    top: size * 0.025,
                    height: 1.6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1),
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                  Center(child: _buildIcon()),
                ],
              ),
            )
          : Center(child: _buildIcon()),
    );
  }

  /// Wood: a matte carved tile — warm grain face, darker extruded side
  /// faces on the bottom and right (3D without 3D), NOTHING shiny. The
  /// gem's color lives in the shape, Scrabble-tile style, so match
  /// readability is untouched.
  Widget _buildWoodTile() {
    final ext = size * 0.05; // extrusion depth (halved per playtest)
    // Per-tile hue jitter: planks from the same tree, not the same print
    final j = (gem.id * 2654435761) % 5; // 0..4
    final face = Color.lerp(const Color(0xFFD9B98C),
        const Color(0xFFC9A876), j / 4.0)!;
    final side = Color.lerp(const Color(0xFF8C6B44),
        const Color(0xFF7A5A38), j / 4.0)!;
    final radius = BorderRadius.circular(size * 0.14);
    return Stack(
      children: [
        // Extruded side block (bottom-right)
        Positioned(
          left: ext,
          top: ext,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: side,
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 3,
                  offset: const Offset(1.5, 1.5),
                ),
              ],
            ),
          ),
        ),
        // Face
        Positioned(
          left: 0,
          top: 0,
          right: ext,
          bottom: ext,
          child: Container(
            decoration: BoxDecoration(
              color: face,
              borderRadius: radius,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 2.5)
                  : isHinted
                      ? Border.all(
                          color: Colors.yellow.withOpacity(0.9), width: 2)
                      : gem.hasPowerUp
                          ? Border.all(
                              color: _getPowerUpGlowColor(), width: 2.5)
                          : Border.all(
                              color: const Color(0xFFB89968), width: 1),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                        painter: WoodGrainPainter(face, seed: gem.id)),
                  ),
                  Center(child: _buildIcon()),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getPowerUpGlowColor() {
    switch (gem.powerUp) {
      case PowerUpType.lineHorizontal:
      case PowerUpType.lineVertical:
        return Colors.cyan;
      case PowerUpType.radial:
        return Colors.orange;
      case PowerUpType.colorBomb:
        return Colors.white;
      case PowerUpType.none:
        return gem.type.glowColor;
    }
  }

  Widget _buildIcon() {
    // For power-ups, show the power-up icon instead of the gem icon
    if (gem.hasPowerUp) {
      IconData powerUpIcon;
      Color iconColor = Colors.white;
      double iconSize = size * 0.55;

      switch (gem.powerUp) {
        case PowerUpType.lineHorizontal:
          powerUpIcon = Icons.swap_horiz;
          iconColor = Colors.cyan.shade100;
          break;
        case PowerUpType.lineVertical:
          powerUpIcon = Icons.swap_vert;
          iconColor = Colors.cyan.shade100;
          break;
        case PowerUpType.radial:
          powerUpIcon = Icons.blur_on;
          iconColor = Colors.orange.shade100;
          break;
        case PowerUpType.colorBomb:
          powerUpIcon = Icons.all_inclusive;
          iconColor = Colors.white;
          iconSize = size * 0.5;
          break;
        case PowerUpType.none:
          powerUpIcon = gem.type.icon;
      }

      return Icon(
        powerUpIcon,
        size: iconSize,
        color: iconColor,
        shadows: const [
          Shadow(
            color: Colors.black,
            blurRadius: 6,
            offset: Offset(1, 1),
          ),
        ],
      );
    }

    // Regular gem icon
    if (ActiveTileStyle.current == TileStyle.wood) {
      // Scrabble aesthetic: the SHAPE carries the gem's color on wood.
      // Pale colors (white/yellow gems) darken toward walnut so they
      // don't wash out on maple; a carved emboss shadow grounds them.
      var c = gem.type.color;
      if (c.computeLuminance() > 0.55) {
        c = Color.lerp(c, const Color(0xFF5C4327), 0.55)!;
      }
      return Icon(
        gem.type.icon,
        size: size * 0.5,
        color: c,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 2,
            offset: const Offset(1, 1.5),
          ),
          Shadow(
            color: Colors.white.withOpacity(0.35),
            blurRadius: 1,
            offset: const Offset(-0.5, -0.5),
          ),
        ],
      );
    }
    return Icon(
      gem.type.icon,
      size: size * 0.5,
      color: gem.type.iconColor,
      shadows: [
        Shadow(
          color: gem.type == GemType.white || gem.type == GemType.yellow
              ? Colors.white.withOpacity(0.5)
              : Colors.black.withOpacity(0.5),
          blurRadius: 4,
          offset: const Offset(1, 1),
        ),
      ],
    );
  }

  /// Glass: same hues but translucent — the starfield ghosts through,
  /// which is what actually reads as "glass".
  Gradient _buildGlassGradient() {
    if (gem.powerUp == PowerUpType.colorBomb) return _buildGradient();
    return RadialGradient(
      colors: [
        gem.type.glowColor.withOpacity(0.80),
        gem.type.color.withOpacity(0.72),
        gem.type.color.withOpacity(0.55),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  Gradient _buildGradient() {
    if (gem.powerUp == PowerUpType.colorBomb) {
      // Rainbow gradient for color bomb
      return const SweepGradient(
        colors: [
          Colors.red,
          Colors.orange,
          Colors.yellow,
          Colors.green,
          Colors.blue,
          Colors.purple,
          Colors.red,
        ],
        stops: [0.0, 0.17, 0.33, 0.5, 0.67, 0.83, 1.0],
      );
    }

    // Regular gem gradient
    return RadialGradient(
      colors: [
        gem.type.glowColor,
        gem.type.color,
        gem.type.color.withOpacity(0.8),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }
}
