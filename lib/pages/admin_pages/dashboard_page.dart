import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  double todaysEarning = 0;
  double monthlyEarning = 0;
  int memberCount = 0;
  int trainerCount = 0;

  List<Map<String, dynamic>> monthlySales = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final salesSnap = await FirebaseFirestore.instance.collection('sales').get();
    final usersSnap = await FirebaseFirestore.instance.collection('users').get();

    double todayTotal = 0;
    double monthTotal = 0;
    Map<String, double> monthMap = {};

    for (var doc in salesSnap.docs) {
      final data = doc.data();
      final date = DateTime.parse(data['date']);
      final amount = (data['amount'] ?? 0).toDouble();

      if (DateFormat('yyyy-MM-dd').format(date) == today) {
        todayTotal += amount;
      }
      if (date.isAfter(monthStart.subtract(const Duration(days: 1)))) {
        monthTotal += amount;
      }

      final label = DateFormat('MMM yyyy').format(date);
      monthMap[label] = (monthMap[label] ?? 0) + amount;
    }

    int members = 0;
    int trainers = 0;
    for (var user in usersSnap.docs) {
      final type = user['userType'];
      if (type == 'Member') members++;
      if (type == 'Trainer') trainers++;
    }

    setState(() {
      todaysEarning = todayTotal;
      monthlyEarning = monthTotal;
      memberCount = members;
      trainerCount = trainers;
      monthlySales = monthMap.entries
          .map((e) => {'month': e.key, 'amount': e.value})
          .toList();
      monthlySales.sort((a, b) => a['month'].compareTo(b['month']));
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatCard("Today’s Earnings", todaysEarning),
                  const SizedBox(width: 16),
                  _buildStatCard("This Month", monthlyEarning),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildCountCard("Members", memberCount, Icons.group,
                      width: (size.width - 56) / 2),
                  _buildCountCard("Trainers", trainerCount, Icons.fitness_center,
                      width: (size.width - 56) / 2),
                ],
              ),
              const SizedBox(height: 30),
              Text("Sales Graph",
                  style:
                      textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              AspectRatio(
                aspectRatio: 1.3,
                child: Card(
                  color: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: BarChart(
                      BarChartData(
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, _) => Text(
                                '${value.toInt()}',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, _) {
                                if (value.toInt() < monthlySales.length) {
                                  final label = monthlySales[value.toInt()]['month'];
                                  final parts = label.split(' ');
                                  return Column(
                                    children: [
                                      Text(parts[0],
                                          style: const TextStyle(fontSize: 10)),
                                      Text(parts[1],
                                          style: const TextStyle(fontSize: 10)),
                                    ],
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          topTitles:
                              AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles:
                              AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        barGroups: monthlySales
                            .asMap()
                            .entries
                            .map((entry) => BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value['amount'],
                                      width: 18,
                                      color: _getBarColor(entry.key),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                ))
                            .toList(),
                        gridData:
                            FlGridData(show: true, drawHorizontalLine: true),
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

  Color _getBarColor(int index) {
    const colors = [
      Colors.grey,
      Colors.purple,
      Colors.lightGreen,
      Colors.cyan,
      Colors.redAccent,
    ];
    return colors[index % colors.length];
  }

  Widget _buildStatCard(String title, double amount) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    return Expanded(
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                currencyFormatter.format(amount),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountCard(String title, int count, IconData icon,
      {required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$count',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
