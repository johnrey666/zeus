// ignore_for_file: use_build_context_synchronously, prefer_const_constructors

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _selectedBodyPart = 'Abs';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final uid = user!.uid;
    final calendarSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('calendar')
        .get();

    final Map<DateTime, List<Map<String, dynamic>>> tempEvents = {};
    for (var doc in calendarSnapshot.docs) {
      final data = doc.data();
      final timestamp = data['timestamp']?.toDate();
      if (timestamp != null) {
        final key = DateTime(timestamp.year, timestamp.month, timestamp.day);
        tempEvents.putIfAbsent(key, () => []);
        tempEvents[key]!.add({...data, 'id': doc.id});
      }
    }

    setState(() {
      _events = tempEvents;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  void _showWorkoutDetails(String workoutName) {
    final details = _generateWorkoutSchedule(workoutName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  _getWorkoutImage(workoutName),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    IconlyLight.activity,
                    size: 80,
                    color: Colors.blue.shade300,
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),
            SizedBox(height: 16),
            Text(
              workoutName,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade900,
              ),
            ),
            SizedBox(height: 12),
            Divider(color: Colors.grey.shade200),
            Row(
              children: [
                Icon(IconlyLight.calendar,
                    color: Colors.blue.shade300, size: 20),
                SizedBox(width: 8),
                Text(
                  '${details['days']} times per week',
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(IconlyLight.time_circle,
                    color: Colors.blue.shade300, size: 20),
                SizedBox(width: 8),
                Text(
                  '${details['minutes']} minutes per session',
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
              ],
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(IconlyLight.plus, size: 20),
              label: Text(
                "Add to Calendar",
                style: GoogleFonts.poppins(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade300,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: () async {
                final date = DateTime.now();
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('calendar')
                    .add({
                  'workout': workoutName,
                  'days': details['days'],
                  'minutes': details['minutes'],
                  'timestamp': Timestamp.fromDate(date),
                  'completed': false,
                });
                Navigator.pop(context);
                _initializeData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '$workoutName saved to calendar!',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.blue.shade300,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: EdgeInsets.all(16),
                  ),
                );
              },
            ).animate().slideY(begin: 0.2, end: 0, duration: 300.ms),
            SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: GoogleFonts.poppins(
                  color: Colors.redAccent,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _generateWorkoutSchedule(String workout) {
    final lower = workout.toLowerCase();
    if (lower.contains('deadlift')) return {'days': 2, 'minutes': 45};
    if (lower.contains('yoga')) return {'days': 3, 'minutes': 30};
    if (lower.contains('hiit')) return {'days': 4, 'minutes': 20};
    if (lower.contains('bench')) return {'days': 2, 'minutes': 40};
    if (lower.contains('cardio')) return {'days': 5, 'minutes': 25};
    return {'days': 3, 'minutes': 30};
  }

  String _getWorkoutImage(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('plank')) return 'assets/images/plank.jpg';
    if (lower.contains('crunch')) return 'assets/images/crunches.jpg';
    if (lower.contains('push-up') || lower.contains('push up'))
      return 'assets/images/push_up.jpg';
    if (lower.contains('bench')) return 'assets/images/bench_press.jpg';
    if (lower.contains('yoga')) return 'assets/images/yoga.jpg';
    if (lower.contains('cardio') ||
        lower.contains('jump') ||
        lower.contains('jumping')) return 'assets/images/jumping_jacks.jpg';
    if (lower.contains('squat')) return 'assets/images/squat.jpg';
    if (lower.contains('lunge')) return 'assets/images/lunge.jpg';
    if (lower.contains('bicep') || lower.contains('arm raise'))
      return 'assets/images/bicep_curl.jpg';
    if (lower.contains('cable')) return 'assets/images/cable_flyes.jpg';
    if (lower.contains('warm-up') || lower.contains('skipping'))
      return 'assets/images/warm_up.jpg';
    if (lower.contains('fullbody')) return 'assets/images/fullbody.jpg';
    if (lower.contains('lowerbody')) return 'assets/images/lowerbody.jpg';
    if (lower.contains('ab workout')) return 'assets/images/crunches.jpg';
    return 'assets/images/workout.jpg';
  }

  Widget buildWorkoutChip(String title) {
    return GestureDetector(
      onTap: () => _showWorkoutDetails(title),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 10),
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withOpacity(0.2),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  _getWorkoutImage(title),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    IconlyLight.activity,
                    size: 48,
                    color: Colors.blue.shade300,
                  ),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
            Icon(IconlyLight.arrow_right_2,
                color: Colors.grey.shade600, size: 24),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0),
    );
  }

  Widget buildBodyFocusSection() {
    final workoutsByBody = {
      'Abs': ['Incline Push-Ups', 'Plank', 'Crunches'],
      'Arms': ['Arm Raises', 'Bicep Curls'],
      'Chest': ['Push-Ups', 'Bench Press'],
      'Legs': ['Squats', 'Lunges'],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Body Focus",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade900,
          ),
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: workoutsByBody.keys.map((category) {
            final selected = _selectedBodyPart == category;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(
                    category,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  selected: selected,
                  selectedColor: Colors.blue.shade100,
                  backgroundColor: Colors.grey.shade100,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (_) =>
                      setState(() => _selectedBodyPart = category),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 16),
        ...workoutsByBody[_selectedBodyPart]!
            .map((title) => buildWorkoutChip(title))
            .toList(),
      ],
    );
  }

  Widget buildStretchSection() {
    final stretches = ['Warm-up', 'Jumping Jack', 'Skipping', 'Arm Raises'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Stretch & Warm Up",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade900,
          ),
        ),
        SizedBox(height: 16),
        ...stretches.map((title) => buildWorkoutChip(title)).toList(),
      ],
    );
  }

  Widget buildProgramCards() {
    final programs = [
      {'title': 'Fullbody Workout', 'desc': '7 Exercises | 30 mins'},
      {'title': 'Lowerbody Workout', 'desc': '6 Exercises | 25 mins'},
      {'title': 'AB Workout', 'desc': '5 Exercises | 15 mins'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 10),
            Text(
              "What Do You Want to Train",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade900,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        ...programs.map((program) {
          return GestureDetector(
            onTap: () => _showWorkoutDetails(program['title']!),
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(vertical: 10),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade100.withOpacity(0.2),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    program['title']!,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    program['desc']!,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Colors.blue.shade300))
          : SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon:
                          Icon(IconlyLight.search, color: Colors.blue.shade300),
                      hintText: 'Search workouts...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: Colors.blue.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                    ),
                    style: GoogleFonts.poppins(fontSize: 16),
                  ).animate().fadeIn(duration: 300.ms),
                  SizedBox(height: 24),
                  Text(
                    "Workout Calendar",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  SizedBox(height: 16),
                  TableCalendar(
                    focusedDay: _focusedDay,
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    calendarFormat: CalendarFormat.week,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selected, focused) {
                      setState(() {
                        _selectedDay = selected;
                        _focusedDay = focused;
                      });
                    },
                    eventLoader: _getEventsForDay,
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.blue.shade300,
                        shape: BoxShape.circle,
                      ),
                      weekendTextStyle:
                          GoogleFonts.poppins(color: Colors.grey.shade600),
                      defaultTextStyle:
                          GoogleFonts.poppins(color: Colors.blue.shade900),
                      outsideTextStyle:
                          GoogleFonts.poppins(color: Colors.grey.shade400),
                    ),
                    headerStyle: HeaderStyle(
                      titleTextStyle: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade900,
                      ),
                      formatButtonVisible: false,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.1, end: 0),
                  SizedBox(height: 24),
                  Text(
                    "Suggested Workout",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  SizedBox(height: 16),
                  ...['Arm Raises', 'Incline Push-Ups', 'Cable Flyes', 'Plank']
                      .map((title) => buildWorkoutChip(title)),
                  SizedBox(height: 24),
                  buildBodyFocusSection(),
                  SizedBox(height: 24),
                  buildStretchSection(),
                  SizedBox(height: 24),
                  buildProgramCards(),
                ],
              ),
            ),
    );
  }
}
