import 'dart:math';
import 'package:flutter/material.dart';

class Star {
  double x;
  double y;
  double z; // depth - affects size and speed
  double baseSize;
  double twinklePhase;
  Color color;

  Star({
    required this.x,
    required this.y,
    required this.z,
    required this.baseSize,
    required this.twinklePhase,
    required this.color,
  });
}

class StarfieldBackground extends StatefulWidget {
  final Widget child;
  final int starCount;

  const StarfieldBackground({
    super.key,
    required this.child,
    this.starCount = 150,
  });

  @override
  State<StarfieldBackground> createState() => _StarfieldBackgroundState();
}

class _StarfieldBackgroundState extends State<StarfieldBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Star> _stars;
  final Random _random = Random();

  static const List<Color> _starColors = [
    Colors.white,
    Color(0xFFE8E8FF), // slight blue
    Color(0xFFFFE8E8), // slight red
    Color(0xFFFFFFF0), // slight yellow
    Color(0xFFE8FFFF), // slight cyan
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    _initStars();
  }

  void _initStars() {
    _stars = List.generate(widget.starCount, (index) {
      return _createStar();
    });
  }

  Star _createStar({double? startY}) {
    final z = _random.nextDouble(); // 0 = far, 1 = close
    return Star(
      x: _random.nextDouble(),
      y: startY ?? _random.nextDouble(),
      z: z,
      baseSize: 0.5 + z * 2.5, // far stars smaller
      twinklePhase: _random.nextDouble() * 2 * pi,
      color: _starColors[_random.nextInt(_starColors.length)],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Deep space gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0a0a1a),
                Color(0xFF1a1a2e),
                Color(0xFF16213e),
                Color(0xFF0f0f23),
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
        // Animated stars
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: StarfieldPainter(
                stars: _stars,
                animationValue: _controller.value,
                onStarOffscreen: (index) {
                  // Reset star to top when it goes off bottom
                  _stars[index] = _createStar(startY: 0);
                },
              ),
              size: Size.infinite,
            );
          },
        ),
        // Subtle nebula overlay
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.5, -0.5),
              radius: 1.5,
              colors: [
                Colors.purple.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.7, 0.8),
              radius: 1.2,
              colors: [
                Colors.blue.withOpacity(0.05),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Child content
        widget.child,
      ],
    );
  }
}

class StarfieldPainter extends CustomPainter {
  final List<Star> stars;
  final double animationValue;
  final Function(int index)? onStarOffscreen;

  StarfieldPainter({
    required this.stars,
    required this.animationValue,
    this.onStarOffscreen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < stars.length; i++) {
      final star = stars[i];

      // Move stars downward (parallax - closer stars move faster)
      final speed = 0.02 + star.z * 0.08;
      star.y += speed * 0.016; // roughly per-frame movement

      // Reset if off screen
      if (star.y > 1.1) {
        star.y = -0.1;
        star.x = Random().nextDouble();
      }

      final x = star.x * size.width;
      final y = star.y * size.height;

      // Twinkle effect
      final twinkle = 0.5 + 0.5 * sin(animationValue * 2 * pi * 3 + star.twinklePhase);
      final opacity = 0.3 + 0.7 * twinkle * (0.5 + star.z * 0.5);

      final paint = Paint()
        ..color = star.color.withOpacity(opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, star.baseSize * 0.5);

      // Draw star glow
      canvas.drawCircle(
        Offset(x, y),
        star.baseSize * (0.8 + twinkle * 0.4),
        paint,
      );

      // Draw star core (brighter center)
      final corePaint = Paint()
        ..color = Colors.white.withOpacity(opacity * 0.8);
      canvas.drawCircle(
        Offset(x, y),
        star.baseSize * 0.3,
        corePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StarfieldPainter oldDelegate) => true;
}
