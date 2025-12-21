import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WorkoutTimerWidget extends StatefulWidget {
  final int totalSeconds;
  final VoidCallback onComplete;
  final VoidCallback? onCancel;
  final bool isWarmupOrStretch; // If true, no rest intervals

  const WorkoutTimerWidget({
    super.key,
    required this.totalSeconds,
    required this.onComplete,
    this.onCancel,
    this.isWarmupOrStretch = false,
  });

  @override
  State<WorkoutTimerWidget> createState() => _WorkoutTimerWidgetState();
}

class _WorkoutTimerWidgetState extends State<WorkoutTimerWidget> {
  Timer? _timer;
  int _remainingSeconds = 0;
  int _currentPart = 1;
  bool _isResting = false;
  bool _isCompleted = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.totalSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_isCompleted) {
      // Reset if already completed
      setState(() {
        _remainingSeconds = widget.totalSeconds;
        _currentPart = 1;
        _isResting = false;
        _isCompleted = false;
        _isPaused = false;
      });
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;

      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          
          // For warm-up/stretch, no rest intervals - just countdown
          if (widget.isWarmupOrStretch) {
            if (_remainingSeconds == 0) {
              _isCompleted = true;
              timer.cancel();
              widget.onComplete();
            }
          } else {
            // Regular workout: Check if we need to switch to rest (at halfway point)
            final halfway = widget.totalSeconds ~/ 2;
            if (_remainingSeconds == halfway && !_isResting && _currentPart == 1) {
              _isResting = true;
              _remainingSeconds = 15; // 15 second rest
            } else if (_isResting && _remainingSeconds == 0) {
              // Rest finished, continue with second part
              _isResting = false;
              _currentPart = 2;
              _remainingSeconds = halfway;
            } else if (!_isResting && _remainingSeconds == 0 && _currentPart == 2) {
              // Workout completed
              _isCompleted = true;
              timer.cancel();
              widget.onComplete();
            }
          }
        }
      });
    });
  }

  void _pauseTimer() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = widget.totalSeconds;
      _currentPart = 1;
      _isResting = false;
      _isCompleted = false;
      _isPaused = false;
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = 1.0 - (_remainingSeconds / widget.totalSeconds);
    final halfway = widget.isWarmupOrStretch ? widget.totalSeconds : widget.totalSeconds ~/ 2;
    final firstPartProgress = widget.isWarmupOrStretch
        ? progress
        : _currentPart == 1 && !_isResting
            ? 1.0 - (_remainingSeconds / halfway)
            : _currentPart == 1 && _isResting
                ? 1.0
                : 0.5;
    final secondPartProgress = widget.isWarmupOrStretch
        ? progress
        : _currentPart == 2
            ? 0.5 + (1.0 - (_remainingSeconds / halfway)) * 0.5
            : firstPartProgress;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _isResting
            ? Colors.orange.shade50
            : _isCompleted
                ? Colors.green.shade50
                : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isResting
              ? Colors.orange.shade300
              : _isCompleted
                  ? Colors.green.shade300
                  : Colors.blue.shade300,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isResting)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pause_circle, color: Colors.orange.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Rest Time',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            )
          else if (_isCompleted)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Workout Complete!',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            )
          else if (!widget.isWarmupOrStretch)
            Text(
              'Part $_currentPart of 2',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.blue.shade700,
              ),
            )
          else
            Text(
              'Warm-up / Stretch',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.blue.shade700,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            _formatTime(_remainingSeconds),
            style: GoogleFonts.poppins(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: _isResting
                  ? Colors.orange.shade700
                  : _isCompleted
                      ? Colors.green.shade700
                      : Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 16),
          // Progress indicator
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: secondPartProgress.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isResting
                        ? Colors.orange.shade400
                        : _isCompleted
                            ? Colors.green.shade400
                            : Colors.blue.shade400,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_isCompleted)
            Text(
              widget.isWarmupOrStretch
                  ? 'Complete the warm-up/stretch'
                  : _isResting
                      ? 'Take a 15-second rest before continuing'
                      : 'Part $_currentPart: ${_formatTime(_currentPart == 1 ? _remainingSeconds.clamp(0, widget.totalSeconds ~/ 2) : _remainingSeconds)} remaining',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isCompleted && _remainingSeconds < widget.totalSeconds)
                IconButton(
                  icon: Icon(
                    _isPaused ? Icons.play_arrow : Icons.pause,
                    color: Colors.blue.shade700,
                  ),
                  onPressed: _pauseTimer,
                ),
              if (!_isCompleted && _remainingSeconds < widget.totalSeconds)
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.blue.shade700),
                  onPressed: _resetTimer,
                ),
              if (_remainingSeconds == widget.totalSeconds && !_isCompleted)
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: Text('Start Workout', style: GoogleFonts.poppins()),
                  onPressed: _startTimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade300,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

