import 'package:flutter/material.dart';
import '../models/game_mode.dart';
import '../widgets/starfield_background.dart';
import 'game_screen.dart';

class ModeSelectScreen extends StatelessWidget {
  const ModeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StarfieldBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Title
              const Text(
                'GEM GAME',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 8,
                  shadows: [
                    Shadow(
                      color: Colors.purple,
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Choose Your Mode',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 40),

              // Mode cards
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _ModeCard(
                      mode: GameModeType.timed,
                      color: Colors.orange,
                      onTap: () => _startGame(context, const GameMode.timed()),
                    ),
                    const SizedBox(height: 16),
                    _ModeCard(
                      mode: GameModeType.moves,
                      color: Colors.blue,
                      onTap: () => _startGame(context, const GameMode.moves()),
                    ),
                    const SizedBox(height: 16),
                    _ModeCard(
                      mode: GameModeType.target,
                      color: Colors.green,
                      onTap: () => _startGame(context, const GameMode.target()),
                    ),
                    const SizedBox(height: 16),
                    _ModeCard(
                      mode: GameModeType.zen,
                      color: Colors.purple,
                      onTap: () => _startGame(context, const GameMode.zen()),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startGame(BuildContext context, GameMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(mode: mode),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final GameModeType mode;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.3),
              color.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: Text(
                  mode.icon,
                  style: const TextStyle(fontSize: 30),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mode.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}
