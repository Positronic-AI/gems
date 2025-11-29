import 'package:flutter/material.dart';
import '../models/gem.dart';
import '../models/game_board.dart';
import 'gem_widget.dart';

class GameBoardWidget extends StatefulWidget {
  final GameBoard board;
  final Function(int points, int combo)? onScoreUpdate;
  final VoidCallback? onNoMoves;
  final Function(int newSize)? onSizeChange;
  final VoidCallback? onMoveComplete;

  const GameBoardWidget({
    super.key,
    required this.board,
    this.onScoreUpdate,
    this.onNoMoves,
    this.onSizeChange,
    this.onMoveComplete,
  });

  @override
  State<GameBoardWidget> createState() => _GameBoardWidgetState();
}

class _GameBoardWidgetState extends State<GameBoardWidget>
    with TickerProviderStateMixin {
  Position? _selectedPosition;
  bool _isAnimating = false;

  // Animation tracking - only animate gems that actually moved
  final Map<Position, Offset> _gemOffsets = {};
  final Map<Position, double> _gemScales = {};
  final Map<Position, double> _gemOpacities = {};
  final Set<Position> _animatingPositions = {};

  // Pinch to zoom
  double _currentScale = 1.0;
  double _scaleAtLastSizeChange = 1.0;
  bool _isScaling = false;

  // Swipe detection - track drag distance
  bool _swipeHandled = false;

  @override
  void initState() {
    super.initState();
    // Check for valid moves after first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForValidMoves();
    });
  }

  @override
  void didUpdateWidget(GameBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check after board changes (e.g., resize)
    if (oldWidget.board != widget.board ||
        oldWidget.board.rows != widget.board.rows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForValidMoves();
      });
    }
  }

  Future<void> _checkForValidMoves() async {
    if (_isAnimating) return;
    if (!mounted) return;
    if (!widget.board.hasValidMoves()) {
      await _handleNoMoves();
    }
  }

  double get _gemSize {
    final screenWidth = MediaQuery.of(context).size.width;
    final boardWidth = screenWidth - 32; // padding
    return boardWidth / widget.board.cols;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.purple.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 1,
          child: GestureDetector(
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            child: Stack(
              children: [
                // Background grid
                _buildBackground(),
                // Gems
                ..._buildGems(),
                // Size indicator during pinch
                if (_isScaling)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.board.rows}x${widget.board.cols}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildBackground() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.board.cols,
      ),
      itemCount: widget.board.rows * widget.board.cols,
      itemBuilder: (context, index) {
        final row = index ~/ widget.board.cols;
        final col = index % widget.board.cols;
        final isDark = (row + col) % 2 == 0;
        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.purple.withOpacity(0.1)
                : Colors.purple.withOpacity(0.05),
          ),
        );
      },
    );
  }

  List<Widget> _buildGems() {
    final gems = <Widget>[];
    final gemSize = _gemSize;

    for (int row = 0; row < widget.board.rows; row++) {
      for (int col = 0; col < widget.board.cols; col++) {
        final gem = widget.board.getGem(row, col);
        if (gem == null) continue;

        final pos = Position(row, col);
        final offset = _gemOffsets[pos] ?? Offset.zero;
        final scale = _gemScales[pos] ?? 1.0;
        final opacity = _gemOpacities[pos] ?? 1.0;
        final isSelected = _selectedPosition == pos;

        // Only animate gems that are in the animating set
        final shouldAnimate = _animatingPositions.contains(pos);

        gems.add(
          AnimatedPositioned(
            key: ValueKey(gem.id), // Track each gem by its unique ID
            duration: shouldAnimate
                ? const Duration(milliseconds: 170)
                : Duration.zero,
            curve: Curves.easeInQuad, // Accelerate like real falling
            left: col * gemSize + offset.dx,
            top: row * gemSize + offset.dy,
            width: gemSize,
            height: gemSize,
            child: AnimatedScale(
              duration: shouldAnimate
                  ? const Duration(milliseconds: 90)
                  : Duration.zero,
              scale: scale,
              child: AnimatedOpacity(
                duration: shouldAnimate
                    ? const Duration(milliseconds: 90)
                    : Duration.zero,
                opacity: opacity,
                child: GemWidget(
                  gem: gem,
                  size: gemSize,
                  isSelected: isSelected,
                  onTap: _isAnimating || _isScaling
                      ? null
                      : () => _onGemTap(pos),
                ),
              ),
            ),
          ),
        );
      }
    }

    return gems;
  }

  Position? _dragStartPosition;
  Offset? _dragStartOffset;

  void _onScaleStart(ScaleStartDetails details) {
    if (details.pointerCount == 2) {
      // Two finger pinch - reset tracking for new gesture
      _currentScale = 1.0;
      _scaleAtLastSizeChange = 1.0;
      _isScaling = true;
      setState(() {});
    } else if (details.pointerCount == 1 && !_isAnimating) {
      // Single finger drag
      final pos = _getPositionFromOffset(details.localFocalPoint);
      if (pos != null && widget.board.getGem(pos.row, pos.col) != null) {
        _dragStartPosition = pos;
        _dragStartOffset = details.localFocalPoint;
        _swipeHandled = false;
        setState(() {
          _selectedPosition = pos;
        });
      }
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_isScaling && details.pointerCount == 2) {
      _currentScale = details.scale;

      // Calculate scale change relative to last size change
      // Pinch out (scale > 1) = smaller grid (fewer, bigger gems)
      // Pinch in (scale < 1) = larger grid (more, smaller gems)
      final scaleDelta = _currentScale / _scaleAtLastSizeChange;
      int newSize = widget.board.rows;

      if (scaleDelta > 1.15) {
        newSize = widget.board.rows - 1;
        _scaleAtLastSizeChange = _currentScale;
      } else if (scaleDelta < 0.85) {
        newSize = widget.board.rows + 1;
        _scaleAtLastSizeChange = _currentScale;
      }

      newSize = newSize.clamp(GameBoard.minSize, GameBoard.maxSize);

      if (newSize != widget.board.rows) {
        widget.onSizeChange?.call(newSize);
      }

      setState(() {});
    } else if (!_isScaling &&
        _dragStartPosition != null &&
        _dragStartOffset != null &&
        !_swipeHandled &&
        !_isAnimating) {
      // Distance-based swipe detection during drag
      final currentOffset = details.localFocalPoint;
      final delta = currentOffset - _dragStartOffset!;
      final gemSize = _gemSize;
      final threshold = gemSize * 0.3; // 30% of gem size to trigger

      if (delta.dx.abs() > threshold || delta.dy.abs() > threshold) {
        Position? targetPos;

        if (delta.dx.abs() > delta.dy.abs()) {
          // Horizontal swipe
          if (delta.dx > 0) {
            targetPos = Position(
                _dragStartPosition!.row, _dragStartPosition!.col + 1);
          } else {
            targetPos = Position(
                _dragStartPosition!.row, _dragStartPosition!.col - 1);
          }
        } else {
          // Vertical swipe
          if (delta.dy > 0) {
            targetPos = Position(
                _dragStartPosition!.row + 1, _dragStartPosition!.col);
          } else {
            targetPos = Position(
                _dragStartPosition!.row - 1, _dragStartPosition!.col);
          }
        }

        // Validate and try swap
        if (targetPos != null &&
            targetPos.row >= 0 &&
            targetPos.row < widget.board.rows &&
            targetPos.col >= 0 &&
            targetPos.col < widget.board.cols) {
          _swipeHandled = true;
          _trySwap(_dragStartPosition!, targetPos);
          _dragStartPosition = null;
          _dragStartOffset = null;
          setState(() {
            _selectedPosition = null;
          });
        }
      }
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_isScaling) {
      _isScaling = false;
      _currentScale = 1.0;
      _scaleAtLastSizeChange = 1.0;
      setState(() {});
      return;
    }

    // Handle swipe (fallback if not already handled during drag)
    if (_dragStartPosition != null &&
        _dragStartOffset != null &&
        !_swipeHandled) {
      final endOffset = details.velocity.pixelsPerSecond;
      Position? targetPos;

      // Lower velocity threshold (was 100, now 50) for easier swipes
      if (endOffset.dx.abs() > 50 || endOffset.dy.abs() > 50) {
        if (endOffset.dx.abs() > endOffset.dy.abs()) {
          // Horizontal swipe
          if (endOffset.dx > 0) {
            targetPos = Position(
                _dragStartPosition!.row, _dragStartPosition!.col + 1);
          } else {
            targetPos = Position(
                _dragStartPosition!.row, _dragStartPosition!.col - 1);
          }
        } else {
          // Vertical swipe
          if (endOffset.dy > 0) {
            targetPos = Position(
                _dragStartPosition!.row + 1, _dragStartPosition!.col);
          } else {
            targetPos = Position(
                _dragStartPosition!.row - 1, _dragStartPosition!.col);
          }
        }
      }

      // Validate and try swap
      if (targetPos != null &&
          targetPos.row >= 0 &&
          targetPos.row < widget.board.rows &&
          targetPos.col >= 0 &&
          targetPos.col < widget.board.cols) {
        _trySwap(_dragStartPosition!, targetPos);
      }
    }

    _dragStartPosition = null;
    _dragStartOffset = null;
    _swipeHandled = false;
    setState(() {
      _selectedPosition = null;
    });
  }

  Position? _getPositionFromOffset(Offset offset) {
    final gemSize = _gemSize;
    final col = (offset.dx / gemSize).floor();
    final row = (offset.dy / gemSize).floor();

    if (row >= 0 &&
        row < widget.board.rows &&
        col >= 0 &&
        col < widget.board.cols) {
      return Position(row, col);
    }
    return null;
  }

  void _onGemTap(Position pos) {
    if (_isAnimating || _isScaling) return;

    if (_selectedPosition == null) {
      setState(() {
        _selectedPosition = pos;
      });
    } else if (_selectedPosition == pos) {
      setState(() {
        _selectedPosition = null;
      });
    } else if (widget.board.canSwap(_selectedPosition!, pos)) {
      _trySwap(_selectedPosition!, pos);
    } else {
      setState(() {
        _selectedPosition = pos;
      });
    }
  }

  Future<void> _trySwap(Position pos1, Position pos2) async {
    if (!widget.board.canSwap(pos1, pos2)) return;

    setState(() {
      _isAnimating = true;
      _selectedPosition = null;
      _animatingPositions.clear();
      _animatingPositions.add(pos1);
      _animatingPositions.add(pos2);
    });

    // Check if swap creates a match
    if (widget.board.wouldCreateMatch(pos1, pos2)) {
      // Perform swap
      widget.board.swap(pos1, pos2);
      widget.board.combo = 0;

      setState(() {});
      await Future.delayed(const Duration(milliseconds: 200));

      // Process matches
      await _processMatches();

      // Notify move complete (for moves mode)
      widget.onMoveComplete?.call();
    } else {
      // Invalid swap - animate swap and swap back
      widget.board.swap(pos1, pos2);
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 200));

      widget.board.swap(pos1, pos2);
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 200));
    }

    setState(() {
      _isAnimating = false;
      _animatingPositions.clear();
    });

    // Check for valid moves - auto-shuffle if none
    if (!widget.board.hasValidMoves()) {
      await _handleNoMoves();
    }
  }

  Future<void> _handleNoMoves() async {
    // Notify screen to show message
    widget.onNoMoves?.call();

    setState(() {
      _isAnimating = true;
    });

    // Brief delay to let snackbar appear
    await Future.delayed(const Duration(milliseconds: 300));

    // Shuffle the board
    widget.board.shuffle();
    setState(() {});

    // Process any matches that resulted from shuffle
    await _processMatches();

    setState(() {
      _isAnimating = false;
      _animatingPositions.clear();
    });

    // Check again - very unlikely but possible to still have no moves
    if (!widget.board.hasValidMoves()) {
      await _handleNoMoves();
    }
  }

  Future<void> _processMatches() async {
    var matches = widget.board.findMatches();
    final gemSize = _gemSize;

    while (matches.isNotEmpty) {
      // Track matched positions for animation - gentle highlight
      _animatingPositions.clear();
      for (final match in matches) {
        for (final pos in match.positions) {
          _animatingPositions.add(pos);
          _gemScales[pos] = 1.05; // Subtle scale, less jarring
          _gemOpacities[pos] = 0.8; // Keep mostly visible
        }
      }
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 60));

      // Fade out matched gems smoothly
      for (final match in matches) {
        for (final pos in match.positions) {
          _gemScales[pos] = 0.8; // Shrink instead of pop
          _gemOpacities[pos] = 0.0;
        }
      }
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 90));

      // Remove matches and update score
      final points = widget.board.removeMatches(matches);
      widget.onScoreUpdate?.call(points, widget.board.combo);

      _gemScales.clear();
      _gemOpacities.clear();

      // Apply gravity and get movement data
      final movements = widget.board.applyGravity();

      // Set up offsets so gems appear to start from their old positions
      _animatingPositions.clear();
      _gemOffsets.clear();
      for (final col in movements.keys) {
        for (final (fromRow, toRow) in movements[col]!) {
          final pos = Position(toRow, col);
          // Offset = where it came from relative to where it is now
          _gemOffsets[pos] = Offset(0, (fromRow - toRow) * gemSize);
          _animatingPositions.add(pos);
        }
      }

      // Show gems at their old positions (via offset)
      setState(() {});

      // Pause to let users see the gap before gems fall
      await Future.delayed(const Duration(milliseconds: 50));

      // Clear offsets to animate gems sliding down
      for (final pos in _animatingPositions) {
        _gemOffsets[pos] = Offset.zero;
      }
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 170));

      // Fill empty spaces and get new gem data
      final newGems = widget.board.fillEmptySpaces();

      // Set up new gems to pop in with scale animation
      _gemOffsets.clear();
      _animatingPositions.clear();
      for (final col in newGems.keys) {
        final count = newGems[col]!;
        // New gems fill from row 0 down to row count-1
        for (int row = 0; row < count; row++) {
          final pos = Position(row, col);
          // Start scaled to 0 (invisible) at final position
          _gemScales[pos] = 0.0;
          _animatingPositions.add(pos);
        }
      }

      // Show gems at scale 0
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 20));

      // Animate new gems popping in
      for (final pos in _animatingPositions) {
        _gemScales[pos] = 1.0;
      }
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 110));

      _gemOffsets.clear();

      // Increment combo and check for chain matches
      widget.board.combo++;
      matches = widget.board.findMatches();
    }

    _animatingPositions.clear();
    widget.board.combo = 0;
  }
}
