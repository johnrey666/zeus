import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return SafeArea(
      child: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;

          final height =
              double.tryParse(userData?['height'].toString() ?? '') ?? 0;
          final weight =
              double.tryParse(userData?['weight'].toString() ?? '') ?? 0;
          final bmi = (height > 0 && weight > 0)
              ? weight / ((height / 100) * (height / 100))
              : 0;

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('workout_plans')
                .doc(userId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data?.data() == null) {
                return const Center(child: Text("No workout data available."));
              }

              final planData = snapshot.data!.data() as Map<String, dynamic>;
              final weekPlan = Map<String, dynamic>.from(
                  planData["Set Up Your Workout Plan"] ?? {});
              final barData = _generateChartData(weekPlan);

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('calendar')
                    .orderBy('timestamp')
                    .snapshots(),
                builder: (context, progressSnapshot) {
                  final progressData = progressSnapshot.data?.docs ?? [];
                  final lineSpots = progressData.asMap().entries.map((e) {
                    final completed = e.value['completed'] == true;
                    return FlSpot(e.key.toDouble(), completed ? 1 : 0);
                  }).toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionCard(
                          title: "Health Summary",
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _healthTile("Height", "${height.toStringAsFixed(0)} cm", Icons.height),
                              _healthTile("Weight", "${weight.toStringAsFixed(0)} kg", Icons.monitor_weight),
                              _healthTile("BMI", bmi.toStringAsFixed(1), Icons.favorite),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _sectionCard(
                          title: "Weekly Workout Overview",
                          child: AspectRatio(
                            aspectRatio: 1.6,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: 1,
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (val, _) => Text(
                                        _dayInitial(val.toInt()),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: barData,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (lineSpots.isNotEmpty) ...[
                          _sectionCard(
                            title: "Overall Progress",
                            child: SizedBox(
                              height: 180,
                              child: LineChart(LineChartData(
                                gridData: FlGridData(show: true),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    isCurved: true,
                                    color: Colors.greenAccent.shade700,
                                    dotData: FlDotData(show: true),
                                    belowBarData: BarAreaData(
                                        show: true,
                                        color: Colors.greenAccent.shade100),
                                    spots: lineSpots,
                                    barWidth: 3,
                                  )
                                ],
                                titlesData: FlTitlesData(show: false),
                              )),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        _sectionCard(
                          title: "Daily Breakdown",
                          child: Column(
                            children: _orderedDays().map((day) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading:
                                    Icon(Icons.calendar_today, color: Colors.blue.shade600),
                                title: Text(day),
                                trailing: Text(weekPlan[day] ?? "-"),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(blurRadius: 8, color: Colors.black12, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _healthTile(String label, String value, IconData icon) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: Icon(icon, color: Colors.blue.shade700),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  List<BarChartGroupData> _generateChartData(Map<String, dynamic> plan) {
    return List.generate(7, (i) {
      final day = _weekday(i);
      final type = plan[day] ?? 'Rest';
      return BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: type == 'Rest' ? 0 : 1,
          color: _workoutColor(type),
          width: 20,
          borderRadius: BorderRadius.circular(6),
        )
      ]);
    });
  }

  static List<String> _orderedDays() => [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];

  static String _weekday(int i) => _orderedDays()[i];

  static String _dayInitial(int index) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return days[index];
  }

  static Color _workoutColor(String type) {
    switch (type) {
      case 'Cardio':
        return Colors.redAccent;
      case 'Strength':
        return Colors.blue;
      case 'Flexibility':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
