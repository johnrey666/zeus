// ignore_for_file: prefer_const_constructors, unnecessary_brace_in_string_interps

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'training_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  DateTime _selectedWeekday = DateTime.now();
  Map<DateTime, List<Map<String, dynamic>>> _allWorkouts = {};
  double _height = 0, _weight = 0;
  int? _tappedSpotIndex;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
    _loadUserBodyInfo();
  }

  Future<void> _loadWorkouts() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('training')
        .orderBy('timestamp')
        .get();
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (var d in snap.docs) {
      final data = d.data();
      final ts = (data['timestamp'] as Timestamp).toDate();
      final day = DateTime(ts.year, ts.month, ts.day);
      map.putIfAbsent(day, () => []);
      final completed = data['completed'] ?? false;
      final setsCompleted = data['setsCompleted'] as int? ?? 0;
      final totalSets = data['sets'] as int? ?? 3;
      final restObserved = data['restIntervalsObserved'] as bool? ?? false;
      
      // Only count as truly completed if all sets done and rest intervals observed
      final isFullyCompleted = completed && 
          setsCompleted >= totalSets && 
          restObserved;
      
      map[day]!.add({
        'id': d.id,
        'title': data['workout'],
        'image': data['image'] ?? 'assets/images/workout.jpg',
        'timestamp': ts,
        'minutes': data['minutes'] ?? 0,
        'completed': isFullyCompleted,
        'setsCompleted': setsCompleted,
        'totalSets': totalSets,
        'restIntervalsObserved': restObserved,
      });
    }
    setState(() {
      _allWorkouts = map;
    });
  }

  Future<void> _loadUserBodyInfo() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('workout_plans')
        .doc(uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _height = double.tryParse(data['Height'] ?? '0') ?? 0;
        _weight = double.tryParse(data['Weight'] ?? '0') ?? 0;
      });
    }
  }

  double get _bmi => (_weight > 0 && _height > 0)
      ? _weight / ((_height / 100) * (_height / 100))
      : 0;

  List<Map<String, dynamic>> get todayAndFutureWorkouts {
    final today = DateTime.now();
    return _allWorkouts.entries
        .where((e) =>
            !e.key.isBefore(DateTime(today.year, today.month, today.day)))
        .expand((e) => e.value)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // ===== FIXED: Build spots for a fixed Mon-Sun week =====
    final now = DateTime.now();
    // Get Monday of current week
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    final List<DateTime> weekDays = List.generate(
      7,
      (i) => DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + i),
    );

    final spots = <FlSpot>[];
    for (int i = 0; i < 7; i++) {
      final day = weekDays[i];
      final key = DateTime(day.year, day.month, day.day);
      final todaysWorkouts = _allWorkouts[key] ?? [];
      // Only count fully completed workouts (all sets + rest intervals)
      final completed = todaysWorkouts.where((w) {
        final isCompleted = w['completed'] == true;
        final setsCompleted = w['setsCompleted'] as int? ?? 0;
        final totalSets = w['totalSets'] as int? ?? 3;
        final restObserved = w['restIntervalsObserved'] as bool? ?? false;
        return isCompleted && setsCompleted >= totalSets && restObserved;
      }).length;
      spots.add(FlSpot(i.toDouble(), completed.toDouble()));
    }
    // ======================================================

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FB),
      body: SafeArea(
        top: true,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPerformanceOverview(spots, weekDays),
              SizedBox(height: 24),
              _buildWorkoutScheduleCard(),
              SizedBox(height: 24),
              _buildUpcomingWorkouts(),
              SizedBox(height: 24),
              _buildWeeklySchedule(),
              SizedBox(height: 24),
              _buildBMIIndicator(),
              SizedBox(height: 24),
              _buildExercises(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceOverview(List<FlSpot> spots, List<DateTime> dayKeys) {
    return _sectionCard(
      title: "Performance Overview",
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    // Use fixed labels Mon..Sun
                    const labels = [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun'
                    ];
                    if (idx >= 0 && idx < labels.length) {
                      return Text(
                        labels[idx],
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      );
                    }
                    return Text('');
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (value, meta) =>
                      Text('${value.toInt()}', style: TextStyle(fontSize: 10)),
                ),
              ),
              rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Colors.black,
                barWidth: 3,
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    final isTapped = _tappedSpotIndex == index;
                    return FlDotCirclePainter(
                      radius: isTapped ? 6 : 4,
                      color: isTapped ? Colors.red : Colors.blue,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchCallback: (event, response) {
                if (!event.isInterestedForInteractions ||
                    response == null ||
                    response.lineBarSpots == null) {
                  setState(() => _tappedSpotIndex = null);
                  return;
                }
                setState(() =>
                    _tappedSpotIndex = response.lineBarSpots!.first.spotIndex);
              },
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: Colors.black87,
                getTooltipItems: (spotsData) => spotsData.map((spot) {
                  final idx = spot.spotIndex;
                  // Map idx to the fixed week day key safely
                  DateTime day;
                  if (idx >= 0 && idx < dayKeys.length) {
                    day = DateTime(dayKeys[idx].year, dayKeys[idx].month,
                        dayKeys[idx].day);
                  } else {
                    day = DateTime.now();
                  }
                  final workouts = _allWorkouts[day]
                          ?.where((w) {
                            final isCompleted = w['completed'] == true;
                            final setsCompleted = w['setsCompleted'] as int? ?? 0;
                            final totalSets = w['totalSets'] as int? ?? 3;
                            final restObserved = w['restIntervalsObserved'] as bool? ?? false;
                            return isCompleted && setsCompleted >= totalSets && restObserved;
                          })
                          .toList() ??
                      [];
                  final titles = workouts.map((w) => w['title']).join(', ');
                  return LineTooltipItem(
                    "${DateFormat('EEE, MMM d').format(day)}\n$titles",
                    const TextStyle(color: Colors.white),
                  );
                }).toList(),
              ),
            ),
            minY: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutScheduleCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: _whiteBoxDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Daily Workout Schedule',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          GestureDetector(
            onTap: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => TrainingPage(initialDate: DateTime.now())),
              );
              if (updated == true) _loadWorkouts();
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Check',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingWorkouts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Upcoming Workout",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        SizedBox(height: 12),
        ...todayAndFutureWorkouts.map((w) {
          final isToday = DateUtils.isSameDay(w['timestamp'], DateTime.now());
          return _workoutTile(w['title'],
              DateFormat('MMM d, hh:mma').format(w['timestamp']), isToday, w);
        }),
      ],
    );
  }

  Widget _workoutTile(
      String title, String subtitle, bool active, Map<String, dynamic> w) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: _whiteBoxDecoration(),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: active ? null : Colors.grey,
          backgroundImage: AssetImage(w['image']),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Container(
          width: 50,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)])
                : null,
            color: active ? null : Colors.grey.shade300,
          ),
          child: Switch(
            value: active,
            onChanged: (_) {},
            activeTrackColor: Colors.transparent,
            inactiveTrackColor: Colors.transparent,
            thumbColor: MaterialStateProperty.all<Color>(Colors.white),
            trackOutlineColor:
                MaterialStateProperty.all<Color>(Colors.transparent),
          ),
        ),
        onTap: () async {
          final updated = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (_) => TrainingPage(initialDate: w['timestamp'])),
          );
          if (updated == true) _loadWorkouts();
        },
      ),
    );
  }

  Widget _buildWeeklySchedule() => _sectionCard(
        title: "Weekly Schedule",
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(7, (i) {
            final day = DateTime.now()
                .subtract(Duration(days: DateTime.now().weekday - 1 - i));
            final isSel = DateUtils.isSameDay(day, _selectedWeekday);
            return GestureDetector(
              onTap: () => setState(() => _selectedWeekday = day),
              child: CircleAvatar(
                radius: 20,
                backgroundColor:
                    isSel ? Colors.blue.shade50 : Colors.grey.shade200,
                child: Text(
                  ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                  style:
                      TextStyle(color: isSel ? Colors.black : Colors.black54),
                ),
              ),
            );
          }),
        ),
      );

  Widget _buildBMIIndicator() => _sectionCard(
        title: "BMI",
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                if (_bmi > 0) {
                  final category = _getBMICategory(_bmi);
                  final message = _getBMIDescription(_bmi);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      title: Text("BMI Category",
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold)),
                      content: Text(
                        "$category: $message",
                        style: TextStyle(color: Colors.black87),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Text("OK"),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  // FIXED: Wrapped Text in Flexible with overflow: TextOverflow.ellipsis for responsive truncation
                  Flexible(
                    child: Text(
                      _bmi > 0
                          ? "${_bmi.toStringAsFixed(1)} - ${_getBMICategory(_bmi)}"
                          : '—',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_bmi > 0) ...[
                    SizedBox(width: 8),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getBMICategoryColor(_bmi),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                _bmiBarSegment(15, Colors.indigo),
                _bmiBarSegment(16, Colors.blue),
                _bmiBarSegment(18.5, Colors.green),
                _bmiBarSegment(25, Colors.orange),
                _bmiBarSegment(30, Colors.red),
              ],
            ),
            SizedBox(height: 4),
            Text(
              "Height: ${_height.toStringAsFixed(1)} cm, Weight: ${_weight.toStringAsFixed(1)} kg",
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 8),
          ],
        ),
      );

  String _getBMICategory(double bmi) {
    if (bmi < 16) return "Severely Underweight";
    if (bmi < 18.5) return "Underweight";
    if (bmi < 25) return "Normal Weight";
    if (bmi < 30) return "Overweight";
    return "Obesity";
  }

  Color _getBMICategoryColor(double bmi) {
    if (bmi < 16) return Colors.indigo;
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }

  String _getBMIDescription(double bmi) {
    if (bmi < 16) return "BMI less than 16 is considered severely underweight.";
    if (bmi < 18.5) return "BMI between 16 and 18.5 is considered underweight.";
    if (bmi < 25) return "BMI between 18.5 and 24.9 is considered normal.";
    if (bmi < 30) return "BMI between 25 and 29.9 is considered overweight.";
    return "BMI of 30 or more is considered obese.";
  }

  Widget _buildExercises() {
    final allWorkouts = _allWorkouts[DateTime(_selectedWeekday.year,
            _selectedWeekday.month, _selectedWeekday.day)] ??
        [];
    // Filter to only fully completed workouts
    final workouts = allWorkouts.where((w) {
      final isCompleted = w['completed'] == true;
      final setsCompleted = w['setsCompleted'] as int? ?? 0;
      final totalSets = w['totalSets'] as int? ?? 3;
      final restObserved = w['restIntervalsObserved'] as bool? ?? false;
      return isCompleted && setsCompleted >= totalSets && restObserved;
    }).toList();
    if (workouts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text("No workouts for this day.",
              style: TextStyle(fontSize: 14, color: Colors.black54)),
        ),
      );
    }
    return _sectionCard(
      title: "Exercises",
      child: Column(
        children: workouts.map((w) {
          return Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
                color: Color(0xFFEFF3FF),
                borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                  backgroundImage: AssetImage(w['image']), radius: 25),
              title: Text(w['title']),
              subtitle: Text(DateFormat('hh:mma').format(w['timestamp'])),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          TrainingPage(initialDate: w['timestamp'])),
                );
                if (updated == true) _loadWorkouts();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  BoxDecoration _whiteBoxDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              blurRadius: 8,
              color: Colors.black12.withOpacity(0.06),
              offset: Offset(0, 4))
        ],
      );

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _whiteBoxDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }

  Widget _bmiBarSegment(double width, Color color) =>
      Expanded(flex: width.toInt(), child: Container(height: 6, color: color));
}
