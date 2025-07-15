// ignore_for_file: use_build_context_synchronously, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
// ignore: unused_import
import 'package:zeus/pages/member_pages/report_page.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  bool _hasPlan = false;
  bool _isTrainer = false;
  // ignore: unused_field
  String _registrationStatus = '';
  Map<String, dynamic>? _planData;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    final uid = user!.uid;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    _isTrainer = userDoc.data()?['userType'] == 'Trainer';

    if (!_isTrainer) {
      final regSnap = await FirebaseFirestore.instance
          .collection('registrations')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();

      _registrationStatus = regSnap.docs.isNotEmpty
          ? regSnap.docs.first.data()['status']?.toString().toLowerCase() ?? ''
          : '';

      final planDoc = await FirebaseFirestore.instance
          .collection('workout_plans')
          .doc(uid)
          .get();

      if (planDoc.exists) {
        _hasPlan = true;
        _planData = planDoc.data();
      }
    }

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

  void _showWorkoutDetails(String workoutName) {
    final details = _generateWorkoutSchedule(workoutName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.blueAccent, Colors.lightBlueAccent],
                ),
              ),
              child: const Icon(Icons.fitness_center,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(workoutName,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  color: Colors.blueAccent),
              const SizedBox(width: 12),
              Text('${details['days']} times per week',
                  style: Theme.of(context).textTheme.bodyLarge),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.access_time, color: Colors.blueAccent),
              const SizedBox(width: 12),
              Text('${details['minutes']} minutes per session',
                  style: Theme.of(context).textTheme.bodyLarge),
            ]),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: const Text("Add to Calendar"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size.fromHeight(50),
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
                    content: Text('$workoutName saved to your calendar 🗓️'),
                    backgroundColor: Colors.blueAccent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.redAccent)),
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

  List<Map<String, dynamic>> _getRecommendations(String? goal, String? level) {
    final g = (goal ?? '').toLowerCase();
    final l = (level ?? '').toLowerCase();

    if (g.contains('loss')) {
      return [
        {'title': 'Jumping Jacks', 'icon': Icons.directions_run},
        {'title': 'Treadmill Walk', 'icon': Icons.directions_walk},
        {'title': 'Bodyweight Circuit', 'icon': Icons.fitness_center},
      ];
    } else if (g.contains('gain') && l.contains('intermediate')) {
      return [
        {'title': 'Dumbbell Press', 'icon': Icons.fitness_center},
        {'title': 'Barbell Squat', 'icon': Icons.accessibility},
        {'title': 'Incline Bench', 'icon': Icons.sports_gymnastics},
      ];
    } else if (g.contains('muscle')) {
      return [
        {'title': 'Deadlift', 'icon': Icons.fitness_center},
        {'title': 'Bench Press', 'icon': Icons.sports_gymnastics},
        {'title': 'Pull-Ups', 'icon': Icons.accessibility_new},
      ];
    } else if (g.contains('maintain')) {
      return [
        {'title': 'Yoga Session', 'icon': Icons.self_improvement},
        {'title': 'HIIT', 'icon': Icons.flash_on},
        {'title': 'Light Dumbbell Circuit', 'icon': Icons.fitness_center},
      ];
    } else {
      return [
        {'title': 'General Fitness Routine', 'icon': Icons.fitness_center},
        {'title': 'Cardio Mix', 'icon': Icons.directions_run},
      ];
    }
  }

  Widget _buildWorkoutCard(String title, IconData iconData) {
    return InkWell(
      onTap: () => _showWorkoutDetails(title),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(iconData, size: 36, color: Colors.blueGrey),
          const SizedBox(width: 16),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500))),
          const Icon(Icons.chevron_right_rounded),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goal = _planData?['What is your fitness goal?'];
    final level = _planData?['Select Fitness Level'];
    final suggestions = _hasPlan ? _getRecommendations(goal, level) : [];

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isTrainer && _hasPlan) ...[
                  const Text("Recommended Workouts",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...suggestions
                      .map((s) => _buildWorkoutCard(s['title'], s['icon'])),
                  const SizedBox(height: 24),
                ],
                const Text("Your Workout Calendar",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) =>
                      isSameDay(_selectedDay ?? DateTime.now(), day),
                  onDaySelected: (selected, focused) => setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  }),
                  eventLoader: (day) =>
                      _events[DateTime(day.year, day.month, day.day)] ?? [],
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                        color: Colors.blue.shade100, shape: BoxShape.circle),
                    selectedDecoration: const BoxDecoration(
                        color: Colors.blue, shape: BoxShape.circle),
                    markerDecoration: const BoxDecoration(
                        color: Colors.blueAccent, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedDay != null &&
                    _events[_selectedDay!] != null &&
                    _events[_selectedDay!]!.isNotEmpty)
                  ..._events[_selectedDay!]!.map((e) => ListTile(
                        leading: Icon(
                          e['completed']
                              ? Icons.check_circle
                              : Icons.fitness_center,
                          color: e['completed'] ? Colors.green : Colors.grey,
                        ),
                        title: Text(e['workout']),
                        subtitle: Text("${e['minutes']} min"),
                        trailing: e['completed']
                            ? const Text("✅ Done",
                                style: TextStyle(color: Colors.green))
                            : TextButton.icon(
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user!.uid)
                                      .collection('calendar')
                                      .doc(e['id'])
                                      .update({'completed': true});
                                  _initializeData();
                                },
                                icon: const Icon(Icons.check),
                                label: const Text("Mark Done"),
                              ),
                      ))
              ],
            ),
          );
  }
}
