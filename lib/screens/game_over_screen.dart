import 'package:flutter/material.dart';
import '../models/game_mode.dart';
import '../services/leaderboard_service.dart';
import '../widgets/starfield_background.dart';

class GameOverScreen extends StatefulWidget {
  final GameMode mode;
  final int score;
  final int gridSize;
  final bool won; // For target mode
  final VoidCallback onPlayAgain;
  final VoidCallback onMainMenu;
  final VoidCallback? onNextLevel; // For target mode

  const GameOverScreen({
    super.key,
    required this.mode,
    required this.score,
    required this.gridSize,
    this.won = false,
    required this.onPlayAgain,
    required this.onMainMenu,
    this.onNextLevel,
  });

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen>
    with SingleTickerProviderStateMixin {
  final LeaderboardService _leaderboardService = LeaderboardService();
  List<LeaderboardEntry> _leaderboard = [];
  int? _newRank;
  bool _isLoading = true;
  bool _isHighScore = false;
  String _playerName = '';
  final TextEditingController _nameController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();

    _checkAndHandleHighScore();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _checkAndHandleHighScore() async {
    // Check if this is a high score
    _isHighScore = await _leaderboardService.isHighScore(
      widget.mode.type,
      widget.score,
    );

    if (_isHighScore && widget.score > 0) {
      // Show name entry dialog
      if (mounted) {
        await _showNameEntryDialog();
      }
    }

    // Save score with name
    await _saveScore();
  }

  Future<void> _showNameEntryDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.amber.withOpacity(0.5)),
        ),
        title: Column(
          children: [
            const Text(
              '🏆',
              style: TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 8),
            const Text(
              'HIGH SCORE!',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            Text(
              '${widget.score} points',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your name:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: 10,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'AAA',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  letterSpacing: 4,
                ),
                counterStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.purple.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.amber),
                ),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
              ),
              onSubmitted: (value) {
                _playerName = value.trim().isEmpty ? '???' : value.trim().toUpperCase();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _playerName = _nameController.text.trim().isEmpty
                  ? '???'
                  : _nameController.text.trim().toUpperCase();
              Navigator.of(context).pop();
            },
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveScore() async {
    // Save score
    _newRank = await _leaderboardService.addScore(
      mode: widget.mode.type,
      name: _playerName.isEmpty ? '???' : _playerName,
      score: widget.score,
      gridSize: widget.gridSize,
      level: widget.mode.type == GameModeType.target ? widget.mode.level : null,
    );

    // Load leaderboard
    _leaderboard = await _leaderboardService.getLeaderboard(widget.mode.type);

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTargetWin = widget.mode.type == GameModeType.target && widget.won;

    return Scaffold(
      body: StarfieldBackground(
        child: SafeArea(
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isTargetWin
                        ? Colors.green.withOpacity(0.5)
                        : Colors.purple.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isTargetWin ? Colors.green : Colors.purple)
                          .withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      isTargetWin ? 'LEVEL COMPLETE!' : 'GAME OVER',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isTargetWin ? Colors.green : Colors.white,
                        letterSpacing: 4,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Mode badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.mode.type.icon} ${widget.mode.type.displayName} Mode',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Score
                    Text(
                      'SCORE',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      '${widget.score}',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                        shadows: [
                          Shadow(
                            color: Colors.orange,
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),

                    // New high score indicator
                    if (_newRank != null && _newRank! <= 5)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.amber, Colors.orange],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _newRank == 1 ? '🏆 NEW HIGH SCORE!' : '#$_newRank on Leaderboard!',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Leaderboard
                    _buildLeaderboard(),

                    const SizedBox(height: 24),

                    // Buttons
                    if (isTargetWin && widget.onNextLevel != null)
                      _buildButton(
                        'Next Level',
                        Colors.green,
                        widget.onNextLevel!,
                      ),
                    const SizedBox(height: 12),
                    _buildButton(
                      'Play Again',
                      Colors.purple,
                      widget.onPlayAgain,
                    ),
                    const SizedBox(height: 12),
                    _buildButton(
                      'Main Menu',
                      Colors.grey,
                      widget.onMainMenu,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboard() {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_leaderboard.isEmpty) {
      return Text(
        'No scores yet!',
        style: TextStyle(color: Colors.white.withOpacity(0.5)),
      );
    }

    return Column(
      children: [
        Text(
          'LEADERBOARD',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.6),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(_leaderboard.length, (index) {
          final entry = _leaderboard[index];
          final isCurrentScore = _newRank == index + 1;
          final medals = ['🥇', '🥈', '🥉', '4.', '5.'];

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isCurrentScore
                  ? Colors.amber.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isCurrentScore
                  ? Border.all(color: Colors.amber.withOpacity(0.5))
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    medals[index],
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    entry.name,
                    style: TextStyle(
                      color: Colors.amber.withOpacity(0.9),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${entry.score}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                          isCurrentScore ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                Text(
                  '${entry.gridSize}x${entry.gridSize}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildButton(String text, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.3),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withOpacity(0.5)),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
