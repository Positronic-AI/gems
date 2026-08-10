import 'package:flutter/material.dart';
import '../models/game_mode.dart';
import '../services/daily_gem.dart';
import '../widgets/starfield_background.dart';
import 'game_screen.dart';

class ModeSelectScreen extends StatefulWidget {
  const ModeSelectScreen({super.key});

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen> {
  final _seedCtrl = TextEditingController();
  int? _dailyScore;

  @override
  void initState() {
    super.initState();
    DailyGem.todayScore().then((v) {
      if (mounted) setState(() => _dailyScore = v);
    });
  }

  @override
  void dispose() {
    _seedCtrl.dispose();
    super.dispose();
  }

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
                    _buildDailyCard(context),
                    const SizedBox(height: 20),
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

                    // Seed: same seed = same board and refills. Leave blank
                    // for a random game; scores record their seed either way.
                    Row(
                      children: [
                        Icon(Icons.casino_outlined,
                            size: 18, color: Colors.white.withOpacity(0.5)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _seedCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              counterText: '',
                              isDense: true,
                              hintText: 'Seed (optional) — replay a board',
                              hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                  fontSize: 13),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.2)),
                              ),
                            ),
                          ),
                        ),
                        if (_seedCtrl.text.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.clear,
                                size: 16,
                                color: Colors.white.withOpacity(0.5)),
                            onPressed: () =>
                                setState(() => _seedCtrl.clear()),
                          ),
                      ],
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

  Widget _buildDailyCard(BuildContext context) {
    final played = _dailyScore != null;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameScreen(
              mode: const GameMode.moves(),
              seed: DailyGem.seedFor(),
              isDaily: true,
            ),
          ),
        );
        final v = await DailyGem.todayScore();
        if (mounted) setState(() => _dailyScore = v);
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade700, Colors.deepOrange.shade800],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.35),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('💎', style: TextStyle(fontSize: 34)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Gem — ${DailyGem.displayDate()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    played
                        ? 'Your score: $_dailyScore  ·  tap to practice'
                        : 'Same board for everyone, once a day. 30 moves.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              played ? Icons.check_circle : Icons.play_circle_fill,
              color: Colors.white,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }

  void _startGame(BuildContext context, GameMode mode) {
    final seed = int.tryParse(_seedCtrl.text.trim());
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(mode: mode, seed: seed),
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
