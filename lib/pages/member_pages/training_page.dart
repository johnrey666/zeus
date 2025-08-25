import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

      eventMap[dateOnly]!.add(data);
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
              return {
                'id': doc.id,
                'title': data['workout'],
                'time': TimeOfDay.fromDateTime(ts).format(context),
                'image': data['image'] ?? 'assets/images/workout.jpg',
                'minutes': data['minutes'] ?? 0,
                'timestamp': ts,
                'completed': data['completed'] ?? false,
              };
            }).toList());
  }

  Future<void> _markAsDone(String id) async {
    final uid = user!.uid;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('training')
        .doc(id)
        .update({'completed': true});
  }

  void _showWorkoutModal(Map<String, dynamic> workout) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Wrap(
            runSpacing: 20,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 24),
                  Text(
                    "Workout Schedule",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                workout['title'],
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    "${DateFormat('jm').format(workout['timestamp'])} | ${workout['minutes']} minutes",
                    style: GoogleFonts.poppins(color: Colors.grey.shade600),
                  ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: workout['completed']
                    ? ElevatedButton(
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
                          'Done',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () async {
                          await _markAsDone(workout['id']);
                          Navigator.of(context).pop(true);
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 0),
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Ink(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(14)),
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
            ],
          ),
        ),
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
              TableCalendar(
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
                calendarFormat: CalendarFormat.week,
                startingDayOfWeek: StartingDayOfWeek.monday,
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.blue.shade200,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  weekendTextStyle: GoogleFonts.poppins(color: Colors.black),
                  defaultTextStyle: GoogleFonts.poppins(color: Colors.black),
                  outsideTextStyle:
                      GoogleFonts.poppins(color: Colors.grey.shade400),
                ),
                headerStyle: HeaderStyle(
                  titleTextStyle: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  formatButtonVisible: false,
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    final hasWorkout = _workoutEvents.keys.any(
                      (d) => DateUtils.isSameDay(d, date),
                    );
                    if (hasWorkout) {
                      return Positioned(
                        bottom: 1,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
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
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    );
                  }
                  return Column(
                    children: workouts.map((workout) {
                      return GestureDetector(
                        onTap: () => _showWorkoutModal(workout),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F8F8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  workout['image'],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(Icons.fitness_center,
                                          size: 60,
                                          color: Colors.grey.shade400),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(workout['title'],
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${workout['time']} | ${workout['minutes']} minutes",
                                      style: GoogleFonts.poppins(
                                          color: Colors.grey, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              if (workout['completed'])
                                const Icon(Icons.check_circle,
                                    color: Colors.green, size: 24),
                            ],
                          ),
                        ),
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
}
