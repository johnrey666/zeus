// ignore_for_file: prefer_const_constructors

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

          final double height =
              double.tryParse(userData?['height'].toString() ?? '') ?? 0;
          final double weight =
              double.tryParse(userData?['weight'].toString() ?? '') ?? 0;
          final double bmi = (height > 0 && weight > 0)
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
              final chartData = _generateChartData(weekPlan);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Health Summary",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _healthTile(
                            "Height", "${height.toStringAsFixed(0)} cm"),
                        const SizedBox(width: 16),
                        _healthTile(
                            "Weight", "${weight.toStringAsFixed(0)} kg"),
                        const SizedBox(width: 16),
                        _healthTile("BMI", bmi.toStringAsFixed(1)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text("Weekly Workout Overview",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    AspectRatio(
                      aspectRatio: 1.7,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: 1,
                          barTouchData: BarTouchData(enabled: true),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, _) => Text(
                                  _dayInitial(value.toInt()),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: chartData,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text("Daily Breakdown",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    ..._orderedDays().map((day) {
                      return ListTile(
                        leading: Icon(Icons.fitness_center,
                            color: Colors.blue.shade600),
                        title: Text(day),
                        trailing: Text(weekPlan[day] ?? "-"),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
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

  Widget _healthTile(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
