// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/cupertino.dart';

class TrainingPage extends StatefulWidget {
  final DateTime? initialDate;
  const TrainingPage({super.key, this.initialDate});

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  final user = FirebaseAuth.instance.currentUser;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, List<Map<String, dynamic>>> _workoutEvents = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _selectedDay = widget.initialDate!;
      _focusedDay = widget.initialDate!;
    }
    _fetchAllWorkouts();
  }

  Future<void> _fetchAllWorkouts() async {
    final uid = user!.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('training')
        .get();

    final Map<DateTime, List<Map<String, dynamic>>> eventMap = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final ts = (data['timestamp'] as Timestamp).toDate();
      final dateOnly = DateTime(ts.year, ts.month, ts.day);

      if (!eventMap.containsKey(dateOnly)) {
        eventMap[dateOnly] = [];
      }

      eventMap[dateOnly]!.add({...data, 'id': doc.id});
    }

    setState(() {
      _workoutEvents = eventMap;
    });
  }

  Stream<List<Map<String, dynamic>>> _getWorkoutsForDay(DateTime day) {
    final uid = user!.uid;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('training')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThan: Timestamp.fromDate(end))
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              final ts = (data['timestamp'] as Timestamp).toDate();

              final sets = data['sets'] as int? ?? 3;
              final reps = data['reps'] as int? ?? 10;
              final restSeconds = data['restSeconds'] as int? ?? 15;
              final durationSeconds = data['durationSeconds'] as int? ?? 180;
              final isWarmupOrStretch =
                  data['isWarmupOrStretch'] as bool? ?? false;
              final durationMinutes = isWarmupOrStretch
                  ? (durationSeconds / 60).ceil()
                  : data['duration'] as int? ?? 3;

              return {
                'id': doc.id,
                'title': data['workout'],
                'image': data['image'] ?? 'assets/images/workout.jpg',
                'timestamp': ts,
                'completed': data['completed'] ?? false,
                'duration': durationMinutes,
                'durationSeconds': durationSeconds,
                'isWarmupOrStretch': isWarmupOrStretch,
                'sets': sets,
                'reps': reps,
                'restSeconds': restSeconds,
              };
            }).toList());
  }

  Future<void> _markAsDone(Map<String, dynamic> workout) async {
    final uid = user!.uid;
    final trainingId = workout['id'];
    final workoutTitle = workout['title'];
    final workoutTimestamp = workout['timestamp'] as DateTime;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('training')
        .doc(trainingId)
        .update({'completed': true});

    final calendarQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('calendar')
        .where('timestamp', isEqualTo: Timestamp.fromDate(workoutTimestamp))
        .where('workout', isEqualTo: workoutTitle)
        .get();

    for (var doc in calendarQuery.docs) {
      await doc.reference.update({'completed': true});
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isPastDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final compareDate = DateTime(date.year, date.month, date.day);
    return compareDate.isBefore(today);
  }

  void _showWorkoutModal(Map<String, dynamic> workout) {
    final duration = workout['duration'] as int? ?? 3;
    final durationSeconds = workout['durationSeconds'] as int? ?? 180;
    final workoutDate = workout['timestamp'] as DateTime;
    final isToday = _isToday(workoutDate);
    final isPastDate = _isPastDate(workoutDate);
    final isCompleted = workout['completed'] == true;
    final isWarmupOrStretch = workout['isWarmupOrStretch'] == true;
    bool timerCompleted = false;
    bool timerStarted = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          backgroundColor: Colors.white,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        workout['title'],
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        timerCompleted = false;
                        timerStarted = false;
                        Navigator.pop(context);
                      },
                      child: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      isToday ? Icons.today : Icons.calendar_today,
                      color: isToday ? Colors.green : Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isToday
                          ? "Today"
                          : "${workoutDate.day}/${workoutDate.month}/${workoutDate.year}",
                      style: GoogleFonts.poppins(
                        color: isToday ? Colors.green : Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight:
                            isToday ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.access_time, color: Colors.grey, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      isWarmupOrStretch
                          ? "${(durationSeconds / 60).toStringAsFixed(1)} mins"
                          : "$duration mins total",
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                // Display sets/reps info
                if (!isWarmupOrStretch)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        _buildSetInfoItem(
                          icon: Icons.repeat,
                          text: "${workout['sets']} sets",
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 16),
                        _buildSetInfoItem(
                          icon: Icons.fitness_center,
                          text: "${workout['reps']} reps",
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 16),
                        _buildSetInfoItem(
                          icon: Icons.timer,
                          text: "${workout['restSeconds']}s rest",
                          color: Colors.orange.shade700,
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildSetInfoItem(
                      icon: Icons.whatshot,
                      text: "Warm-up/Stretching",
                      color: Colors.orange.shade700,
                      isWarmup: true,
                    ),
                  ),
                if (!isToday && !isCompleted)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isPastDate
                          ? Colors.red.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPastDate
                            ? Colors.red.shade200
                            : Colors.orange.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPastDate ? Icons.error_outline : Icons.info_outline,
                          color: isPastDate
                              ? Colors.red.shade700
                              : Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isPastDate
                                ? 'This workout is from a past date and cannot be marked as done.'
                                : 'This workout is scheduled for another day. You can only start workouts scheduled for today.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isPastDate
                                  ? Colors.red.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                if (isToday && !isCompleted)
                  _WorkoutTimerSection(
                    workout: workout,
                    onTimerComplete: () {
                      setModalState(() {
                        timerCompleted = true;
                      });
                    },
                    onTimerStart: () {
                      setModalState(() {
                        timerStarted = true;
                      });
                    },
                  )
                else if (isCompleted)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green.shade700, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Workout Completed',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                if (isToday && !isCompleted)
                  _WorkoutActionButtons(
                    workout: workout,
                    isPastDate: isPastDate,
                    timerCompleted: timerCompleted,
                    timerStarted: timerStarted,
                    onMarkAsDone: () async {
                      Navigator.pop(context);
                      await _markAsDone(workout);
                      _fetchAllWorkouts();
                    },
                  )
                else if (!isToday)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.grey.shade700,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Not Available Today',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
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

  Widget _buildSetInfoItem({
    required IconData icon,
    required String text,
    required Color color,
    bool isWarmup = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: true,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Workout Schedule",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    calendarFormat: CalendarFormat.month,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Month',
                      CalendarFormat.week: 'Week',
                    },
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    eventLoader: (day) =>
                        _workoutEvents[
                            DateTime(day.year, day.month, day.day)] ??
                        [],
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.blue.shade200,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.blue.shade300,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      defaultDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      weekendDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      outsideDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      markerDecoration: BoxDecoration(
                        color: Colors.amber.shade600,
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 3,
                      cellMargin: EdgeInsets.all(6),
                      defaultTextStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      weekendTextStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      outsideTextStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade400,
                      ),
                      todayTextStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      selectedTextStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    headerStyle: HeaderStyle(
                      titleTextStyle: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      formatButtonVisible: true,
                      formatButtonDecoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      formatButtonTextStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      leftChevronIcon: Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 28,
                      ),
                      rightChevronIcon: Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 28,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      dowBuilder: (context, day) {
                        final text = [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun'
                        ][day.weekday - 1];
                        return Center(
                          child: Text(
                            text,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        );
                      },
                      markerBuilder: (context, date, events) {
                        if (events.isNotEmpty) {
                          return Positioned(
                            bottom: 1,
                            child: Row(
                              children: List.generate(
                                events.length > 3 ? 3 : events.length,
                                (index) => Container(
                                  margin: EdgeInsets.symmetric(horizontal: 1),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade600,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 24),
              Text(
                _selectedDay.isBefore(DateTime(DateTime.now().year,
                        DateTime.now().month, DateTime.now().day))
                    ? "Past Workout"
                    : DateUtils.isSameDay(_selectedDay, DateTime.now())
                        ? "Today's Workout"
                        : "Upcoming Workout",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _getWorkoutsForDay(_selectedDay),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final workouts = snapshot.data ?? [];
                  if (workouts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        "No workouts scheduled for this day.",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: workouts.map((workout) {
                      final duration = workout['duration'] as int? ?? 3;
                      final isToday =
                          _isToday(workout['timestamp'] as DateTime);
                      final isCompleted = workout['completed'] == true;
                      final isWarmupOrStretch =
                          workout['isWarmupOrStretch'] == true;
                      final sets = workout['sets'] as int? ?? 3;
                      final reps = workout['reps'] as int? ?? 10;

                      return GestureDetector(
                        onTap: () => _showWorkoutModal(workout),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F8F8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCompleted
                                  ? Colors.green.shade300
                                  : isToday
                                      ? Colors.blue.shade300
                                      : Colors.grey.shade300,
                              width: isToday ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.asset(
                                      workout['image'],
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) => Icon(
                                              Icons.fitness_center,
                                              size: 60,
                                              color: Colors.grey.shade400),
                                    ),
                                  ),
                                  if (isWarmupOrStretch)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'Warm-up',
                                          style: GoogleFonts.poppins(
                                            fontSize: 8,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      workout['title'],
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      workout['isWarmupOrStretch'] == true
                                          ? "${(workout['durationSeconds'] / 60).toStringAsFixed(1)} mins"
                                          : "$duration mins total",
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (workout['sets'] != null &&
                                        !isWarmupOrStretch)
                                      Row(
                                        children: [
                                          _buildMiniSetInfo(
                                            icon: Icons.repeat,
                                            text: "$sets sets",
                                            color: Colors.blue.shade700,
                                          ),
                                          const SizedBox(width: 8),
                                          _buildMiniSetInfo(
                                            icon: Icons.fitness_center,
                                            text: "$reps reps",
                                            color: Colors.green.shade700,
                                          ),
                                          const SizedBox(width: 8),
                                          _buildMiniSetInfo(
                                            icon: Icons.timer,
                                            text:
                                                "${workout['restSeconds']}s rest",
                                            color: Colors.orange.shade700,
                                          ),
                                        ],
                                      )
                                    else if (isWarmupOrStretch)
                                      _buildMiniSetInfo(
                                        icon: Icons.whatshot,
                                        text: "Warm-up/Stretching",
                                        color: Colors.orange.shade700,
                                      ),
                                  ],
                                ),
                              ),
                              if (workout['completed'])
                                const Icon(Icons.check_circle,
                                    color: Colors.green, size: 24)
                              else if (isToday)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.play_arrow,
                                          color: Colors.blue.shade800,
                                          size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Start',
                                        style: GoogleFonts.poppins(
                                          color: Colors.blue.shade800,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .slideX(begin: 0.1, end: 0),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniSetInfo({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutTimerSection extends StatefulWidget {
  final Map<String, dynamic> workout;
  final VoidCallback onTimerComplete;
  final VoidCallback onTimerStart;

  const _WorkoutTimerSection({
    required this.workout,
    required this.onTimerComplete,
    required this.onTimerStart,
  });

  @override
  __WorkoutTimerSectionState createState() => __WorkoutTimerSectionState();
}

class __WorkoutTimerSectionState extends State<_WorkoutTimerSection>
    with SingleTickerProviderStateMixin {
  TimerState _timerState = TimerState.notStarted;
  int _currentSegment = 0;
  int _timeRemaining = 0;
  Timer? _timer;
  int _workoutPartDuration = 0;
  int _restDuration = 15;
  late AnimationController _animationController;
  late Animation<double> _animation;
  late final bool _isWarmupOrStretch; // Changed from final to late final

  @override
  void initState() {
    super.initState();
    // Initialize _isWarmupOrStretch in initState instead of constructor
    _isWarmupOrStretch = widget.workout['isWarmupOrStretch'] as bool? ?? false;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _initializeTimer();
  }

  void _initializeTimer() {
    final totalDuration = widget.workout['durationSeconds'] as int? ?? 180;

    if (_isWarmupOrStretch) {
      // Warm-up/Stretching has only 1 segment (no rest)
      _workoutPartDuration = totalDuration;
    } else {
      _workoutPartDuration =
          ((totalDuration - (2 * _restDuration)) / 3).floor();
    }

    _timeRemaining = _workoutPartDuration;
  }

  void _startTimer() {
    widget.onTimerStart();
    setState(() {
      _timerState = TimerState.running;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        setState(() {
          _timeRemaining--;
        });
      } else {
        _timer?.cancel();

        if (_isWarmupOrStretch) {
          // Warm-up/Stretching has only 1 segment
          setState(() {
            _timerState = TimerState.completed;
          });
          widget.onTimerComplete();
          _animationController.stop();
        } else if (_currentSegment < 5) {
          setState(() {
            _currentSegment++;
            if (_currentSegment % 2 == 0) {
              _timeRemaining = _workoutPartDuration;
            } else {
              _timeRemaining = _restDuration;
            }
          });
          _startTimer();
        } else {
          setState(() {
            _timerState = TimerState.completed;
          });
          widget.onTimerComplete();
          _animationController.stop();
        }
      }
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    _animationController.repeat(reverse: true);
    setState(() {
      _timerState = TimerState.notStarted;
      _currentSegment = 0;
      _timeRemaining = _workoutPartDuration;
    });
  }

  String _getSegmentName() {
    if (_isWarmupOrStretch) {
      return 'Warm-up/Stretching';
    }

    final totalSegments = 5;
    if (_currentSegment >= totalSegments) return 'Complete';

    if (_currentSegment % 2 == 0) {
      final setNumber = (_currentSegment ~/ 2) + 1;
      return 'Set $setNumber/3';
    } else {
      final restNumber = ((_currentSegment + 1) ~/ 2);
      return 'Rest $restNumber/2';
    }
  }

  String _getSegmentIcon() {
    if (_isWarmupOrStretch) {
      return '🔥';
    }

    if (_currentSegment >= 5) return '🏁';

    if (_currentSegment % 2 == 0) {
      return '💪'; // Work icon
    } else {
      return '⏱️'; // Rest icon
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  double _getProgress() {
    if (_isWarmupOrStretch) {
      final totalDuration = widget.workout['durationSeconds'] as int? ?? 45;
      return 1 - (_timeRemaining / totalDuration);
    }

    final totalSegments = 5;
    final segmentProgress = 1 -
        (_timeRemaining /
            (_currentSegment % 2 == 0 ? _workoutPartDuration : _restDuration));
    return (_currentSegment + segmentProgress) / totalSegments;
  }

  Color _getSegmentColor() {
    if (_timerState == TimerState.completed) return Colors.green.shade700;
    if (_isWarmupOrStretch) return Colors.orange.shade700;

    if (_currentSegment % 2 == 0) {
      return Colors.blue.shade700; // Set color
    } else {
      return Colors.orange.shade700; // Rest color
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Workout Timer',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: _getProgress(),
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(
            _timerState == TimerState.completed
                ? Colors.green
                : _getSegmentColor(),
          ),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _timerState == TimerState.completed
                ? Colors.green.shade50
                : _getSegmentColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _timerState == TimerState.completed
                  ? Colors.green.shade300
                  : _getSegmentColor(),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_timerState == TimerState.running)
                    Text(
                      _getSegmentIcon(),
                      style: const TextStyle(fontSize: 24),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _getSegmentName(),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _timerState == TimerState.completed
                          ? Colors.green.shade700
                          : _getSegmentColor(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_timerState == TimerState.completed)
                Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 64,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Timer Complete!',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                )
              else
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _timerState == TimerState.running
                          ? _animation.value
                          : 1.0,
                      child: child,
                    );
                  },
                  child: Column(
                    children: [
                      Text(
                        _formatTime(_timeRemaining),
                        style: GoogleFonts.poppins(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: _timerState == TimerState.running
                              ? _getSegmentColor()
                              : _getSegmentColor().withOpacity(0.8),
                        ),
                      ),
                      if (!_isWarmupOrStretch &&
                          _timerState == TimerState.running)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_currentSegment % 2 == 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border:
                                        Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Text(
                                    'WORK',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.orange.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.timer,
                                          size: 12,
                                          color: Colors.orange.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'REST',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_timerState == TimerState.notStarted)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade300.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: GestureDetector(
                        onTap: _startTimer,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Start Timer',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_timerState == TimerState.running)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: _getSegmentColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: _getSegmentColor()),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.time,
                                color: _getSegmentColor(),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Timer Running...',
                                style: GoogleFonts.poppins(
                                  color: _getSegmentColor(),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _resetTimer,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Icon(
                              Icons.replay,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (_timerState == TimerState.completed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Timer Complete!',
                            style: GoogleFonts.poppins(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkoutActionButtons extends StatelessWidget {
  final Map<String, dynamic> workout;
  final bool isPastDate;
  final bool timerCompleted;
  final bool timerStarted;
  final VoidCallback onMarkAsDone;

  const _WorkoutActionButtons({
    required this.workout,
    required this.isPastDate,
    required this.timerCompleted,
    required this.timerStarted,
    required this.onMarkAsDone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isPastDate || !timerCompleted ? null : onMarkAsDone,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isPastDate || !timerCompleted ? Colors.grey.shade300 : null,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isPastDate
                ? Text(
                    'Past Date - Cannot Complete',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : !timerStarted
                    ? Text(
                        'Start Timer First',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      )
                    : !timerCompleted
                        ? Text(
                            'Complete Timer First',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          )
                        : Ink(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
                              ),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(14)),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              constraints: const BoxConstraints(minHeight: 50),
                              child: Text(
                                'Mark as Done',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
          ),
        ),
        if (!isPastDate && !timerCompleted)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              timerStarted
                  ? 'Complete the timer first, then mark as done'
                  : 'Click "Start Timer" to begin',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: timerStarted
                    ? Colors.orange.shade600
                    : Colors.blue.shade600,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

enum TimerState {
  notStarted,
  running,
  completed,
}
