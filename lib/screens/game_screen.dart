import 'dart:async';
import 'package:flutter/material.dart';
import '../models/game_board.dart';
import '../models/game_mode.dart';
import '../widgets/combo_celebration.dart';
import '../widgets/game_board_widget.dart';
import '../widgets/starfield_background.dart';
import 'game_over_screen.dart';

class GameScreen extends StatefulWidget {
  final GameMode mode;

  const GameScreen({
    super.key,
    required this.mode,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late GameBoard _board;
  late GameMode _currentMode;
  int _displayScore = 0;
  int _lastPoints = 0;
  int _lastCombo = 0;
  bool _showCelebration = false;
  int _celebrationKey = 0; // Force rebuild of celebration widget
  bool _gameOver = false;

  // Timer mode
  Timer? _timer;
  int _timeRemaining = 0;

  // Moves mode
  int _movesRemaining = 0;

  late AnimationController _scoreAnimController;
  late Animation<double> _scorePulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.mode;
    _board = GameBoard();
    _initializeMode();

    _scoreAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scorePulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _scoreAnimController, curve: Curves.elasticOut),
    );

    _scoreAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _scoreAnimController.reverse();
      }
    });
  }

  void _initializeMode() {
    switch (_currentMode.type) {
      case GameModeType.timed:
        _timeRemaining = _currentMode.timeSeconds;
        _startTimer();
        break;
      case GameModeType.moves:
        _movesRemaining = _currentMode.maxMoves;
        break;
      case GameModeType.target:
      case GameModeType.zen:
        break;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        setState(() {
          _timeRemaining--;
        });
      } else {
        timer.cancel();
        _endGame();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scoreAnimController.dispose();
    super.dispose();
  }

  void _onScoreUpdate(int points, int combo) {
    setState(() {
      _lastPoints = points;
      _lastCombo = combo;
      _displayScore = _board.score;
      _showCelebration = true;
      _celebrationKey++; // Force new celebration widget
    });

    _scoreAnimController.forward(from: 0);

    // Check target mode win condition
    if (_currentMode.type == GameModeType.target &&
        _displayScore >= _currentMode.targetScore) {
      _endGame(won: true);
    }
  }

  void _onCelebrationComplete() {
    if (mounted) {
      setState(() {
        _showCelebration = false;
      });
    }
  }

  void _onMoveComplete() {
    if (_currentMode.type == GameModeType.moves) {
      setState(() {
        _movesRemaining--;
      });
      if (_movesRemaining <= 0) {
        _endGame();
      }
    }
  }

  void _onNoMoves() {
    // Just show a brief snackbar - the widget handles shuffle automatically
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.shuffle, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'No moves! Shuffling...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 1500),
        backgroundColor: Colors.deepPurple,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _onSizeChange(int newSize) {
    setState(() {
      _board.resize(newSize);
      _displayScore = 0;
    });
  }

  void _endGame({bool won = false}) {
    if (_gameOver) return;
    _gameOver = true;
    _timer?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameOverScreen(
          mode: _currentMode,
          score: _displayScore,
          gridSize: _board.rows,
          won: won,
          onPlayAgain: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => GameScreen(mode: widget.mode),
              ),
            );
          },
          onMainMenu: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          onNextLevel: _currentMode.type == GameModeType.target && won
              ? () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GameScreen(
                        mode: _currentMode.nextLevel(),
                      ),
                    ),
                  );
                }
              : null,
        ),
      ),
    );
  }

  Future<bool> _handleBackPressed() async {
    // For Zen mode, automatically go to game over screen to save score
    if (_currentMode.type == GameModeType.zen && _displayScore > 0) {
      _endGame();
      return false; // Don't pop - _endGame handles navigation
    }

    // For other modes, just exit
    return true;
  }

  void _resetGame() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Game?'),
        content: Text('Current score: $_displayScore\n\nStart a new game?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _board.reset();
                _displayScore = 0;
                _gameOver = false;
                _initializeMode();
              });
            },
            child: const Text('New Game'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackPressed();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        body: StarfieldBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header with score and mode info
              _buildHeader(),

              // Mode-specific display (timer, moves, target)
              _buildModeDisplay(),

              // Celebration area - fixed height so board doesn't jump
              SizedBox(
                height: 80,
                child: _showCelebration
                    ? ComboCelebration(
                        key: ValueKey(_celebrationKey),
                        combo: _lastCombo,
                        points: _lastPoints,
                        onComplete: _onCelebrationComplete,
                      )
                    : null,
              ),

              // Game board
              Expanded(
                child: Center(
                  child: GameBoardWidget(
                    board: _board,
                    onScoreUpdate: _onScoreUpdate,
                    onNoMoves: _onNoMoves,
                    onSizeChange: _onSizeChange,
                    onMoveComplete: _onMoveComplete,
                  ),
                ),
              ),

              // Grid size hint
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Pinch to resize: ${_board.rows}x${_board.cols}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back / Reset button
          Row(
            children: [
              IconButton(
                onPressed: () async {
                  final shouldPop = await _handleBackPressed();
                  if (shouldPop && mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.arrow_back),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _resetGame,
                icon: const Icon(Icons.refresh),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.purple.withOpacity(0.3),
                ),
              ),
            ],
          ),

          // Score display
          AnimatedBuilder(
            animation: _scorePulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scorePulseAnimation.value,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.shade700,
                        Colors.deepPurple.shade900,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        '$_displayScore',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Mode indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _currentMode.type.icon,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeDisplay() {
    switch (_currentMode.type) {
      case GameModeType.timed:
        return _buildTimerDisplay();
      case GameModeType.moves:
        return _buildMovesDisplay();
      case GameModeType.target:
        return _buildTargetDisplay();
      case GameModeType.zen:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTimerDisplay() {
    final isLow = _timeRemaining <= 10;
    final minutes = _timeRemaining ~/ 60;
    final seconds = _timeRemaining % 60;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Timer bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _timeRemaining / _currentMode.timeSeconds,
              minHeight: 12,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(
                isLow ? Colors.red : Colors.orange,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Time text
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isLow ? Colors.red : Colors.white,
              shadows: isLow
                  ? [
                      const Shadow(color: Colors.red, blurRadius: 20),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovesDisplay() {
    final isLow = _movesRemaining <= 5;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: (isLow ? Colors.red : Colors.blue).withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isLow ? Colors.red : Colors.blue).withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app,
              color: isLow ? Colors.red : Colors.blue,
            ),
            const SizedBox(width: 8),
            Text(
              '$_movesRemaining moves left',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isLow ? Colors.red : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetDisplay() {
    final progress = _displayScore / _currentMode.targetScore;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Level indicator
          Text(
            'LEVEL ${_currentMode.level}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade300,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation(Colors.green),
            ),
          ),
          const SizedBox(height: 8),
          // Target text
          Text(
            'Target: ${_currentMode.targetScore}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

}
