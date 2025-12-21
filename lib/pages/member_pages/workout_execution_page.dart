// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WorkoutExecutionPage extends StatefulWidget {
  final Map<String, dynamic> workout;
  const WorkoutExecutionPage({super.key, required this.workout});

  @override
  State<WorkoutExecutionPage> createState() => _WorkoutExecutionPageState();
}

class _WorkoutExecutionPageState extends State<WorkoutExecutionPage> {
  final user = FirebaseAuth.instance.currentUser;
  int _currentSet = 0;
  int _restSecondsRemaining = 0;
  Timer? _restTimer;
  bool _isResting = false;
  List<bool> _completedSets = [];
  bool _allSetsCompleted = false;
  bool _restIntervalsObserved = true;

  int get totalSets => widget.workout['sets'] as int? ?? 3;
  int get repsPerSet => widget.workout['reps'] as int? ?? 10;
  int get restSeconds => widget.workout['restSeconds'] as int? ?? 60;

  @override
  void initState() {
    super.initState();
    _completedSets = List.filled(totalSets, false);
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final currentUser = user;
    if (currentUser == null) return;

    try {
      final workoutId = widget.workout['id'] as String?;
      if (workoutId == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('training')
          .doc(workoutId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final setsCompleted = data['setsCompleted'] as int? ?? 0;
        final completedSetsList = List<bool>.from(data['completedSets'] ?? []);
        final restObserved = data['restIntervalsObserved'] as bool? ?? false;

        setState(() {
          _currentSet = setsCompleted;
          _completedSets = completedSetsList.length == totalSets
              ? completedSetsList
              : List.filled(totalSets, false);
          _restIntervalsObserved = restObserved;
          _allSetsCompleted = _completedSets.every((completed) => completed);
        });
      }
    } catch (e) {
      debugPrint('Error loading progress: $e');
    }
  }

  void _startRestTimer() {
    if (_restTimer != null) {
      _restTimer!.cancel();
    }

    setState(() {
      _isResting = true;
      _restSecondsRemaining = restSeconds;
      _restIntervalsObserved = false;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSecondsRemaining > 0) {
        setState(() {
          _restSecondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isResting = false;
          _restIntervalsObserved = true;
        });
      }
    });
  }

  Future<void> _completeSet(int setIndex) async {
    final currentUser = user;
    if (currentUser == null) return;

    setState(() {
      _completedSets[setIndex] = true;
      _currentSet = setIndex + 1;
      _allSetsCompleted = _completedSets.every((completed) => completed);
    });

    // Save progress
    try {
      final workoutId = widget.workout['id'] as String?;
      if (workoutId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('training')
            .doc(workoutId)
            .update({
          'setsCompleted': _currentSet,
          'completedSets': _completedSets,
        });
      }
    } catch (e) {
      debugPrint('Error saving progress: $e');
    }

    // Start rest timer if not the last set
    if (setIndex < totalSets - 1) {
      _startRestTimer();
    } else {
      setState(() {
        _restIntervalsObserved = true;
      });
    }
  }

  Future<void> _markWorkoutComplete() async {
    final currentUser = user;
    if (currentUser == null) return;

    // Validate completion
    if (!_allSetsCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please complete all ${totalSets} sets before marking as done.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_restIntervalsObserved && _currentSet < totalSets) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please observe all rest intervals before completing the workout.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final workoutId = widget.workout['id'] as String?;
      final workoutTitle = widget.workout['title'] as String? ??
          widget.workout['workout'] as String;
      final workoutTimestamp = widget.workout['timestamp'] as DateTime?;

      if (workoutId != null) {
        // Update training
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('training')
            .doc(workoutId)
            .update({
          'completed': true,
          'setsCompleted': totalSets,
          'completedSets': _completedSets,
          'restIntervalsObserved': _restIntervalsObserved,
          'completedAt': FieldValue.serverTimestamp(),
        });

        // Update calendar
        if (workoutTimestamp != null) {
          final calendarQuery = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .collection('calendar')
              .where('timestamp',
                  isEqualTo: Timestamp.fromDate(workoutTimestamp))
              .where('workout', isEqualTo: workoutTitle)
              .get();

          for (var doc in calendarQuery.docs) {
            await doc.reference.update({
              'completed': true,
              'completedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Workout completed successfully! 🎉',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate completion
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error completing workout: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workoutName = widget.workout['title'] as String? ??
        widget.workout['workout'] as String? ??
        'Workout';
    final workoutImage =
        widget.workout['image'] as String? ?? 'assets/images/workout.jpg';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          workoutName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Workout Image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                workoutImage,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.fitness_center, size: 80),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Workout Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoCard('Sets', totalSets.toString(), Icons.repeat),
                _buildInfoCard(
                    'Reps', repsPerSet.toString(), Icons.fitness_center),
                _buildInfoCard('Rest', '${restSeconds}s', Icons.timer),
              ],
            ),
            const SizedBox(height: 32),

            // Rest Timer
            if (_isResting)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade300, width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      'Rest Time',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${_restSecondsRemaining}s',
                      style: GoogleFonts.poppins(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        _restTimer?.cancel();
                        setState(() {
                          _isResting = false;
                          _restIntervalsObserved = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade300,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Skip Rest', style: GoogleFonts.poppins()),
                    ),
                  ],
                ),
              ),
            if (_isResting) const SizedBox(height: 24),

            // Sets List
            Text(
              'Sets Progress',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(totalSets, (index) {
              final isCompleted = _completedSets[index];
              final isCurrent = index == _currentSet && !_isResting;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green.shade50
                      : isCurrent
                          ? Colors.blue.shade50
                          : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCompleted
                        ? Colors.green.shade300
                        : isCurrent
                            ? Colors.blue.shade300
                            : Colors.grey.shade300,
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCompleted
                          ? Icons.check_circle
                          : isCurrent
                              ? Icons.play_circle
                              : Icons.radio_button_unchecked,
                      color: isCompleted
                          ? Colors.green
                          : isCurrent
                              ? Colors.blue
                              : Colors.grey,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set ${index + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            '$repsPerSet reps',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isCompleted && isCurrent)
                      ElevatedButton(
                        onPressed: () => _completeSet(index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Complete', style: GoogleFonts.poppins()),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 32),

            // Complete Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _allSetsCompleted ? _markWorkoutComplete : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _allSetsCompleted ? Colors.green : Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _allSetsCompleted
                      ? 'Mark Workout as Complete'
                      : 'Complete All Sets First',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
