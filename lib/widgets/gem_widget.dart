import 'package:flutter/material.dart';
import '../models/gem.dart';

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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.08),
        child: Container(
          decoration: BoxDecoration(
            gradient: _buildGradient(),
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
          child: Center(
            child: _buildIcon(),
          ),
        ),
      ),
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
