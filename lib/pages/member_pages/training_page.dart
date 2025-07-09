import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'planning_page.dart';
import 'report_page.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  bool _hasPlan = false;
  Map<String, dynamic>? _planData;
  final user = FirebaseAuth.instance.currentUser;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  @override
  void initState() {
    super.initState();
    _fetchWorkoutPlan();
    _fetchCalendarData();
  }

  Future<void> _fetchWorkoutPlan() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('workout_plans')
        .doc(user!.uid)
        .get();

    if (doc.exists) {
      setState(() {
        _hasPlan = true;
        _planData = doc.data();
      });
    }
  }

  Future<void> _fetchCalendarData() async {
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('calendar')
        .get();

    final Map<DateTime, List<Map<String, dynamic>>> tempEvents = {};

    for (var doc in snapshot.docs) {
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
    });
  }

  void _navigateToPlanner({bool isEditing = false}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PlanningPage(existingData: isEditing ? _planData : null),
      ),
    );
    if (result == true) _fetchWorkoutPlan();
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
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fitness_center, size: 40, color: Colors.blueAccent),
              const SizedBox(height: 12),
              Text(workoutName,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text('${details['days']} times per week'),
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text('${details['minutes']} minutes per session'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.save_alt),
                label: const Text("Add to Calendar"),
                onPressed: () async {
                  final now = DateTime.now();
                  final date = DateTime(now.year, now.month, now.day);

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
                  _fetchCalendarData();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('$workoutName saved to your calendar')),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, dynamic> _generateWorkoutSchedule(String workout) {
    final lower = workout.toLowerCase();
    if (lower.contains('deadlift')) {
      return {'days': 2, 'minutes': 45};
    } else if (lower.contains('yoga')) {
      return {'days': 3, 'minutes': 30};
    } else if (lower.contains('hiit')) {
      return {'days': 4, 'minutes': 20};
    } else if (lower.contains('bench')) {
      return {'days': 2, 'minutes': 40};
    } else if (lower.contains('cardio')) {
      return {'days': 5, 'minutes': 25};
    }
    return {'days': 3, 'minutes': 30}; // Default
  }

  @override
  Widget build(BuildContext context) {
    final goal = _planData?['What is your fitness goal?'];
    final level = _planData?['Select Fitness Level'];
    final suggestions = _hasPlan ? _getRecommendations(goal, level) : const [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasPlan
                      ? 'Workout Plan Set!'
                      : 'Customize Your Workout Plan',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text('Move. Sweat. Conquer!',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 14),
                Center(
                  child: _hasPlan
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            FilledButton.tonal(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const ReportPage()),
                                );
                              },
                              child: const Text("View Report"),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  _navigateToPlanner(isEditing: true),
                              child: const Text("Edit Plan"),
                            ),
                          ],
                        )
                      : FilledButton.icon(
                          icon: const Icon(Icons.add),
                          onPressed: () => _navigateToPlanner(),
                          label: const Text('Create Plan'),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_hasPlan)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Recommended Workouts",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...suggestions
                    .map((s) => _buildWorkoutCard(s['title'], s['icon'])),
              ],
            ),
          const SizedBox(height: 24),
          const Text("Your Workout Calendar",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) =>
                isSameDay(_selectedDay ?? DateTime.now(), day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            eventLoader: (day) {
              final key = DateTime(day.year, day.month, day.day);
              return _events[key] ?? [];
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                  color: Colors.blue.shade100, shape: BoxShape.circle),
              selectedDecoration:
                  BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              markerDecoration: const BoxDecoration(
                  color: Colors.blueAccent, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedDay != null)
            ...(_events[_selectedDay!] ?? []).map((e) => ListTile(
                  leading: Icon(
                      e['completed']
                          ? Icons.check_circle
                          : Icons.fitness_center,
                      color: e['completed'] ? Colors.green : Colors.grey),
                  title: Text(e['workout']),
                  subtitle: Text("${e['minutes']} min"),
                  trailing: e['completed']
                      ? const Text("Done",
                          style: TextStyle(color: Colors.green))
                      : TextButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user!.uid)
                                .collection('calendar')
                                .doc(e['id'])
                                .update({'completed': true});
                            _fetchCalendarData();
                          },
                          child: const Text("Mark Done"),
                        ),
                )),
        ],
      ),
    );
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
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(iconData, size: 36, color: Colors.blueGrey),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
