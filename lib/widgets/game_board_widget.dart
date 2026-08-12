import 'package:flutter/material.dart';
import '../models/gem.dart';
import '../models/tile_style.dart';
import '../models/game_board.dart';
import 'gem_widget.dart';

class GameBoardWidget extends StatefulWidget {
  final GameBoard board;
  final Function(int points, int combo)? onScoreUpdate;
  final VoidCallback? onNoMoves;
  final Function(int newSize)? onSizeChange;
  final VoidCallback? onMoveComplete;
  final Function(String message)? onPowerUp;

  /// Fired synchronously BEFORE the board mutates for a player action
  /// (valid swap or power-up tap) — the undo snapshot moment.
  final VoidCallback? onMoveStarted;

  /// Fired when the board is fully settled after a player action
  /// (cascades done, shuffle-if-stuck done) — safe to recount moves / undo.
  final VoidCallback? onBoardSettled;

  /// When true, a dead board after a move ENDS the game (onLockout) instead
  /// of auto-shuffling — the peril. Zen keeps the shuffle. A dead board on
  /// the initial deal or resize always shuffles regardless: death at move
  /// zero is the RNG's fault, not the player's.
  final bool endOnLockout;
  final VoidCallback? onLockout;

  const GameBoardWidget({
    super.key,
    required this.board,
    this.onScoreUpdate,
    this.onNoMoves,
    this.onSizeChange,
    this.onMoveComplete,
    this.onPowerUp,
    this.onMoveStarted,
    this.onBoardSettled,
    this.endOnLockout = false,
    this.onLockout,
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

  /// Actual laid-out board edge, captured by the LayoutBuilder inside the
  /// AspectRatio. NEVER derive this from screen width: the square board is
  /// min(width, height), and on height-constrained screens (iPhones after
  /// notch + safe areas) a width-based guess maps touches up-and-left of
  /// the finger — worse toward the bottom-right corner.
  double? _boardSide;

  double get _gemSize {
    final side = _boardSide ?? (MediaQuery.of(context).size.width - 32);
    return side / widget.board.cols;
  }

  @override
  Widget build(BuildContext context) {
    final wood = ActiveTileStyle.current == TileStyle.wood;
    return Container(
      margin: const EdgeInsets.all(16),
      // Frameless everywhere (playtest verdict: the purple frame was
      // glass-era chrome nothing needed). Wood pads bottom/right to
      // balance its extruded side faces.
      padding: wood
          ? const EdgeInsets.only(bottom: 3, right: 3)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(wood ? 0.22 : 0.3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(builder: (context, constraints) {
            _boardSide = constraints.maxWidth;
            return GestureDetector(
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
          );
          }),
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

    final gem = widget.board.getGem(pos.row, pos.col);

    // Tap-to-activate power-ups (except color bomb which needs a target)
    if (gem != null && gem.hasPowerUp && gem.powerUp != PowerUpType.colorBomb) {
      _activatePowerUpByTap(pos);
      return;
    }

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

  /// Activate a power-up gem by tapping it directly
  Future<void> _activatePowerUpByTap(Position pos) async {
    final gem = widget.board.getGem(pos.row, pos.col);
    if (gem == null || !gem.hasPowerUp) return;

    widget.onMoveStarted?.call();

    setState(() {
      _isAnimating = true;
      _selectedPosition = null;
    });

    // Get positions to clear based on power-up type
    Set<Position> clearPositions = {};
    String message = 'BOOM!';

    switch (gem.powerUp) {
      case PowerUpType.lineHorizontal:
        for (int col = 0; col < widget.board.cols; col++) {
          clearPositions.add(Position(pos.row, col));
        }
        message = 'LINE BLAST!';
        break;
      case PowerUpType.lineVertical:
        for (int row = 0; row < widget.board.rows; row++) {
          clearPositions.add(Position(row, pos.col));
        }
        message = 'LINE BLAST!';
        break;
      case PowerUpType.radial:
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            final newRow = pos.row + dr;
            final newCol = pos.col + dc;
            if (newRow >= 0 && newRow < widget.board.rows &&
                newCol >= 0 && newCol < widget.board.cols) {
              clearPositions.add(Position(newRow, newCol));
            }
          }
        }
        message = 'RADIAL BLAST!';
        break;
      case PowerUpType.colorBomb:
      case PowerUpType.none:
        // Color bomb requires a swap target, can't tap-activate
        setState(() {
          _isAnimating = false;
        });
        return;
    }

    // Notify about activation
    widget.onPowerUp?.call(message);

    // Animate the clear effect
    _animatingPositions.clear();
    for (final clearPos in clearPositions) {
      _animatingPositions.add(clearPos);
      _gemScales[clearPos] = 1.15;
      _gemOpacities[clearPos] = 0.8;
    }
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 100));

    // Fade out
    for (final clearPos in clearPositions) {
      _gemScales[clearPos] = 0.5;
      _gemOpacities[clearPos] = 0.0;
    }
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 150));

    // Remove cleared gems and calculate score
    int points = clearPositions.length * 75;
    for (final clearPos in clearPositions) {
      widget.board.grid[clearPos.row][clearPos.col] = null;
    }
    widget.board.score += points;
    widget.onScoreUpdate?.call(points, widget.board.combo);

    _gemScales.clear();
    _gemOpacities.clear();

    // Apply gravity and fill
    await _applyGravityAndFill();

    // Process any cascading matches
    widget.board.combo = 1;
    await _processMatches();

    // Power-ups are bonuses — activating one does NOT consume a move.

    setState(() {
      _isAnimating = false;
      _animatingPositions.clear();
    });

    // Check for valid moves
    if (!widget.board.hasValidMoves()) {
      if (widget.endOnLockout) {
        widget.onBoardSettled?.call();
        widget.onLockout?.call();
        return;
      }
      await _handleNoMoves();
    }

    widget.onBoardSettled?.call();
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

    final gem1 = widget.board.getGem(pos1.row, pos1.col);
    final gem2 = widget.board.getGem(pos2.row, pos2.col);
    final bothHavePowerUps = gem1?.hasPowerUp == true && gem2?.hasPowerUp == true;
    final hasColorBomb = gem1?.powerUp == PowerUpType.colorBomb ||
                         gem2?.powerUp == PowerUpType.colorBomb;

    // Check if swap involves power-ups or creates a match
    if (bothHavePowerUps || hasColorBomb || widget.board.wouldCreateMatch(pos1, pos2)) {
      widget.onMoveStarted?.call();
      // Perform swap
      widget.board.swap(pos1, pos2);
      widget.board.combo = 0;

      setState(() {});
      await Future.delayed(const Duration(milliseconds: 200));

      // Handle special power-up swaps
      if (bothHavePowerUps) {
        await _processPowerUpCombination(pos1, pos2);
      } else if (hasColorBomb) {
        await _processColorBombSwap(pos1, pos2);
      } else {
        // Process normal matches, passing swap position for power-up placement
        await _processMatches(swapPosition: pos2);
      }

      // Notify move complete (for moves mode). Swaps that ACTIVATE bombs
      // are bonuses and don't consume a move — only ordinary match swaps do.
      if (!bothHavePowerUps && !hasColorBomb) {
        widget.onMoveComplete?.call();
      }
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

    // Check for valid moves — the peril: dead board ends the game in
    // scored modes; zen auto-shuffles.
    if (!widget.board.hasValidMoves()) {
      if (widget.endOnLockout) {
        widget.onBoardSettled?.call();
        widget.onLockout?.call();
        return;
      }
      await _handleNoMoves();
    }

    widget.onBoardSettled?.call();
  }

  /// Process swapping two power-up gems together
  Future<void> _processPowerUpCombination(Position pos1, Position pos2) async {
    final clearPositions = widget.board.getCombinedPowerUpClearPositions(pos1, pos2);

    if (clearPositions.isEmpty) {
      // Fallback to normal processing
      await _processMatches(swapPosition: pos2);
      return;
    }

    // Notify about the combo
    widget.onPowerUp?.call('MEGA COMBO!');

    // Animate the clear effect
    _animatingPositions.clear();
    for (final pos in clearPositions) {
      _animatingPositions.add(pos);
      _gemScales[pos] = 1.1;
      _gemOpacities[pos] = 0.8;
    }
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 100));

    // Fade out
    for (final pos in clearPositions) {
      _gemScales[pos] = 0.5;
      _gemOpacities[pos] = 0.0;
    }
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 150));

    // Remove all cleared gems
    int points = clearPositions.length * 75;
    for (final pos in clearPositions) {
      widget.board.grid[pos.row][pos.col] = null;
    }
    widget.board.score += points;
    widget.onScoreUpdate?.call(points, widget.board.combo);

    _gemScales.clear();
    _gemOpacities.clear();

    // Apply gravity and fill
    await _applyGravityAndFill();

    // Process any cascading matches
    await _processMatches();
  }

  /// Process swapping a color bomb with a regular gem
  Future<void> _processColorBombSwap(Position pos1, Position pos2) async {
    final gem1 = widget.board.getGem(pos1.row, pos1.col);
    final gem2 = widget.board.getGem(pos2.row, pos2.col);

    Position bombPos;
    GemType targetColor;

    if (gem1?.powerUp == PowerUpType.colorBomb) {
      bombPos = pos1;
      targetColor = gem2!.type;
    } else {
      bombPos = pos2;
      targetColor = gem1!.type;
    }

    final clearPositions = widget.board.activateColorBomb(bombPos, targetColor);

    // Notify about the color bomb
    widget.onPowerUp?.call('COLOR BLAST!');

    // Animate the clear effect
    _animatingPositions.clear();
    for (final pos in clearPositions) {
      _animatingPositions.add(pos);
      _gemScales[pos] = 1.15;
      _gemOpacities[pos] = 0.7;
    }
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 120));

    // Fade out
    for (final pos in clearPositions) {
      _gemScales[pos] = 0.3;
      _gemOpacities[pos] = 0.0;
    }
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 150));

    // Remove all cleared gems
    int points = clearPositions.length * 100;
    for (final pos in clearPositions) {
      widget.board.grid[pos.row][pos.col] = null;
    }
    widget.board.score += points;
    widget.onScoreUpdate?.call(points, widget.board.combo);

    _gemScales.clear();
    _gemOpacities.clear();

    // Apply gravity and fill
    await _applyGravityAndFill();

    // Process any cascading matches
    await _processMatches();
  }

  /// Helper to apply gravity and fill empty spaces with animation
  Future<void> _applyGravityAndFill() async {
    final gemSize = _gemSize;

    // Apply gravity and get movement data
    final movements = widget.board.applyGravity();

    // Set up offsets so gems appear to start from their old positions
    _animatingPositions.clear();
    _gemOffsets.clear();
    for (final col in movements.keys) {
      for (final (fromRow, toRow) in movements[col]!) {
        final pos = Position(toRow, col);
        _gemOffsets[pos] = Offset(0, (fromRow - toRow) * gemSize);
        _animatingPositions.add(pos);
      }
    }

    setState(() {});
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
      for (int row = 0; row < count; row++) {
        final pos = Position(row, col);
        _gemScales[pos] = 0.0;
        _animatingPositions.add(pos);
      }
    }

    setState(() {});
    await Future.delayed(const Duration(milliseconds: 20));

    // Animate new gems popping in
    for (final pos in _animatingPositions) {
      _gemScales[pos] = 1.0;
    }
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 110));

    _gemOffsets.clear();
    _gemScales.clear();
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

  Future<void> _processMatches({Position? swapPosition}) async {
    var matches = widget.board.findMatches(swapPosition: swapPosition);

    while (matches.isNotEmpty) {
      // Find positions that will be cleared vs those that will get power-ups
      final positionsToRemove = <Position>{};
      final powerUpPositions = <Position>{};

      for (final match in matches) {
        if (match.powerUpType != PowerUpType.none && match.powerUpPosition != null) {
          powerUpPositions.add(match.powerUpPosition!);
          for (final pos in match.positions) {
            if (pos != match.powerUpPosition) {
              positionsToRemove.add(pos);
            }
          }
        } else {
          positionsToRemove.addAll(match.positions);
        }
      }

      // Track matched positions for animation - gentle highlight
      _animatingPositions.clear();
      for (final pos in positionsToRemove) {
        _animatingPositions.add(pos);
        _gemScales[pos] = 1.05;
        _gemOpacities[pos] = 0.8;
      }
      // Power-up positions get a special highlight
      for (final pos in powerUpPositions) {
        _animatingPositions.add(pos);
        _gemScales[pos] = 1.15; // More prominent
        _gemOpacities[pos] = 1.0;
      }
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 60));

      // Fade out gems being removed, pulse power-up positions
      for (final pos in positionsToRemove) {
        _gemScales[pos] = 0.8;
        _gemOpacities[pos] = 0.0;
      }
      for (final pos in powerUpPositions) {
        _gemScales[pos] = 1.2; // Growing effect
      }
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 90));

      // Remove matches and update score
      final result = widget.board.removeMatches(matches);
      widget.onScoreUpdate?.call(result.points, widget.board.combo);

      // Notify about power-ups created
      for (final entry in result.powerUpsCreated.entries) {
        final powerUpType = entry.value;
        switch (powerUpType) {
          case PowerUpType.lineHorizontal:
          case PowerUpType.lineVertical:
            widget.onPowerUp?.call('LINE BOMB!');
            break;
          case PowerUpType.radial:
            widget.onPowerUp?.call('RADIAL BLAST!');
            break;
          case PowerUpType.colorBomb:
            widget.onPowerUp?.call('COLOR BOMB!');
            break;
          case PowerUpType.none:
            break;
        }
      }

      // Notify about power-ups activated
      for (final pos in result.powerUpsActivated) {
        widget.onPowerUp?.call('BOOM!');
      }

      // Reset scales for power-up gems (they now have their new appearance)
      for (final pos in powerUpPositions) {
        _gemScales[pos] = 1.0;
      }

      _gemScales.clear();
      _gemOpacities.clear();

      // Apply gravity and fill
      await _applyGravityAndFill();

      // Increment combo and check for chain matches
      widget.board.combo++;
      matches = widget.board.findMatches();
      swapPosition = null; // Only use swap position for first match
    }

    _animatingPositions.clear();
    widget.board.combo = 0;
  }
}
