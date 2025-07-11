import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TrainerWorkoutPlanPage extends StatefulWidget {
  const TrainerWorkoutPlanPage({super.key});

  @override
  State<TrainerWorkoutPlanPage> createState() =>
      _TrainerWorkoutPlanPageState();
}

class _TrainerWorkoutPlanPageState extends State<TrainerWorkoutPlanPage> {
  final ScrollController _scrollController = ScrollController();
  final List<DateTime> _allDates = [];
  DateTime _selectedDate = DateTime.now();
  String _currentMonthYear = "";

  @override
  void initState() {
    super.initState();
    _generateYearDates();
    _currentMonthYear = DateFormat('MMMM yyyy').format(_selectedDate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday();
      _scrollController.addListener(_updateMonthYearOnScroll);
    });
  }

  void _generateYearDates() {
    DateTime start = DateTime(DateTime.now().year, 1, 1);
    for (int i = 0; i < 365; i++) {
      _allDates.add(start.add(Duration(days: i)));
    }
  }

  void _scrollToToday() {
    int todayIndex = _allDates.indexWhere((d) =>
        d.year == DateTime.now().year &&
        d.month == DateTime.now().month &&
        d.day == DateTime.now().day);
    if (todayIndex != -1) {
      _scrollController.jumpTo(todayIndex * 60); // 60 = item width
    }
  }

  void _updateMonthYearOnScroll() {
    const itemWidth = 60.0;
    final index = (_scrollController.offset / itemWidth).round().clamp(0, _allDates.length - 1);
    final date = _allDates[index];
    final newMonth = DateFormat('MMMM yyyy').format(date);

    if (_currentMonthYear != newMonth) {
      setState(() {
        _currentMonthYear = newMonth;
      });
    }
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Calendar Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentMonthYear,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: _allDates.length,
                      itemBuilder: (context, index) {
                        final date = _allDates[index];
                        final isSelected = _isSameDate(date, _selectedDate);

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDate = date;
                              _currentMonthYear =
                                  DateFormat('MMMM yyyy').format(date);
                            });
                          },
                          child: Container(
                            width: 60,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              children: [
                                Text(
                                  DateFormat('E').format(date),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.green
                                          : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    date.day.toString(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isSelected
                                          ? Colors.green
                                          : Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Scrollable Workout Plan Section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("MONDAY",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const _WorkoutRow(workouts: [
                      _WorkoutItem("Running", Icons.directions_run),
                      _WorkoutItem("Stretching", Icons.accessibility_new),
                      _WorkoutItem("Dumbbell Squats", Icons.fitness_center),
                    ]),
                    const SizedBox(height: 30),
                    const Text("WEDNESDAY",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const _WorkoutRow(workouts: [
                      _WorkoutItem("Treadmill", Icons.directions_run),
                      _WorkoutItem("Lunges", Icons.accessibility_new),
                      _WorkoutItem("Shoulder Press", Icons.fitness_center),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutItem {
  final String label;
  final IconData icon;

  const _WorkoutItem(this.label, this.icon);
}

class _WorkoutRow extends StatelessWidget {
  final List<_WorkoutItem> workouts;

  const _WorkoutRow({super.key, required this.workouts});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: workouts.map((workout) {
          return Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  workout.icon,
                  size: 30,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                workout.label,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Icon(Icons.check_box, color: Colors.green, size: 20),
            ],
          );
        }).toList(),
      ),
    );
  }
}
