import 'dart:math';
import 'package:flutter/material.dart';

class ComboCelebration extends StatefulWidget {
  final int combo;
  final int points;
  final Color? gemColor;
  final VoidCallback? onComplete;

  const ComboCelebration({
    super.key,
    required this.combo,
    required this.points,
    this.gemColor,
    this.onComplete,
  });

  @override
  State<ComboCelebration> createState() => _ComboCelebrationState();
}

class _ComboCelebrationState extends State<ComboCelebration>
    with TickerProviderStateMixin {
  late AnimationController _textController;
  late AnimationController _particleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _slideAnimation;

  final List<_Particle> _particles = [];
  final Random _random = Random();

  String get _comboText {
    if (widget.combo >= 5) return 'INCREDIBLE!';
    if (widget.combo >= 4) return 'AMAZING!';
    if (widget.combo >= 3) return 'FANTASTIC!';
    if (widget.combo >= 2) return 'GREAT!';
    if (widget.combo >= 1) return 'NICE!';
    return '+${widget.points}';
  }

  Color get _comboColor {
    if (widget.gemColor != null) return widget.gemColor!;
    if (widget.combo >= 5) return Colors.purple;
    if (widget.combo >= 4) return Colors.red;
    if (widget.combo >= 3) return Colors.orange;
    if (widget.combo >= 2) return Colors.yellow;
    return Colors.amber;
  }

  double get _fontSize {
    if (widget.combo >= 4) return 36;
    if (widget.combo >= 2) return 32;
    return 28;
  }

  @override
  void initState() {
    super.initState();

    // Text animation
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.3).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ]).animate(_textController);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_textController);

    _slideAnimation = Tween<double>(begin: 20, end: -10).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    // Particle animation
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Generate particles
    _generateParticles();

    _textController.forward();
    _particleController.forward();

    _textController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
  }

  void _generateParticles() {
    final color = _comboColor;
    final count = 8 + widget.combo * 4; // More particles for bigger combos

    for (int i = 0; i < count; i++) {
      _particles.add(_Particle(
        color: Color.lerp(color, Colors.white, _random.nextDouble() * 0.5)!,
        angle: _random.nextDouble() * 2 * pi,
        speed: 50 + _random.nextDouble() * 100 + widget.combo * 20,
        size: 4 + _random.nextDouble() * 6,
        decay: 0.5 + _random.nextDouble() * 0.5,
      ));
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_textController, _particleController]),
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Particles
            ..._particles.map((p) => _buildParticle(p)),
            // Combo text
            Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: _buildComboText(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildParticle(_Particle p) {
    final progress = _particleController.value;
    final distance = p.speed * progress;
    final opacity = (1 - progress * p.decay).clamp(0.0, 1.0);
    final size = p.size * (1 - progress * 0.5);

    return Transform.translate(
      offset: Offset(
        cos(p.angle) * distance,
        sin(p.angle) * distance - progress * 30, // Float upward
      ),
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p.color,
            boxShadow: [
              BoxShadow(
                color: p.color.withOpacity(0.8),
                blurRadius: size,
                spreadRadius: size / 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComboText() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main combo text with points inline
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _comboText,
              style: TextStyle(
                fontSize: _fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: _comboColor,
                    blurRadius: 20,
                  ),
                  const Shadow(
                    color: Colors.black,
                    blurRadius: 4,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '+${widget.points}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
                shadows: [
                  Shadow(
                    color: Colors.orange.withOpacity(0.8),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ],
        ),
        // Combo multiplier - only for actual combos
        if (widget.combo > 0)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _comboColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _comboColor.withOpacity(0.6)),
            ),
            child: Text(
              '${widget.combo + 1}x COMBO',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _Particle {
  final Color color;
  final double angle;
  final double speed;
  final double size;
  final double decay;

  _Particle({
    required this.color,
    required this.angle,
    required this.speed,
    required this.size,
    required this.decay,
  });
}
