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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                gem.type.glowColor,
                gem.type.color,
                gem.type.color.withOpacity(0.8),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(size * 0.2),
            border: isSelected
                ? Border.all(color: Colors.white, width: 3)
                : isHinted
                    ? Border.all(color: Colors.yellow.withOpacity(0.8), width: 2)
                    : null,
            boxShadow: [
              BoxShadow(
                color: gem.type.glowColor.withOpacity(isSelected ? 0.8 : 0.4),
                blurRadius: isSelected ? 15 : 8,
                spreadRadius: isSelected ? 2 : 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              gem.type.icon,
              size: size * 0.5,
              color: gem.type.iconColor,
              shadows: [
                Shadow(
                  color: gem.type == GemType.white
                      ? Colors.white.withOpacity(0.5)
                      : Colors.black.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedGemWidget extends StatefulWidget {
  final Gem gem;
  final double size;
  final bool isSelected;
  final bool isMatched;
  final bool isNew;
  final VoidCallback? onTap;

  const AnimatedGemWidget({
    super.key,
    required this.gem,
    required this.size,
    this.isSelected = false,
    this.isMatched = false,
    this.isNew = false,
    this.onTap,
  });

  @override
  State<AnimatedGemWidget> createState() => _AnimatedGemWidgetState();
}

class _AnimatedGemWidgetState extends State<AnimatedGemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(_controller);
    _opacityAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(_controller);

    if (widget.isNew) {
      _controller.duration = const Duration(milliseconds: 200);
      _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
      );
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AnimatedGemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isMatched && !oldWidget.isMatched) {
      _controller.duration = const Duration(milliseconds: 300);
      _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeIn),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: GemWidget(
              gem: widget.gem,
              size: widget.size,
              isSelected: widget.isSelected,
              onTap: widget.onTap,
            ),
          ),
        );
      },
    );
  }
}
