// ignore_for_file: unused_local_variable, unused_import

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import 'sales_tracking_page.dart';

class DashboardPage extends StatefulWidget {
  final VoidCallback onNavigateToAttendance;
  final VoidCallback onNavigateToMembers;
  final VoidCallback onNavigateToPending;

  const DashboardPage({
    super.key,
    required this.onNavigateToAttendance,
    required this.onNavigateToMembers,
    required this.onNavigateToPending,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  double todaysRevenue = 0;
  int totalMembers = 0;
  int checkInsToday = 0;
  int activeMemberships = 0;
  List<Map<String, dynamic>> monthlySales = [];

  @override
  void initState() {
    super.initState();
    _listenToDashboardData();
  }

  void _listenToDashboardData() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    FirebaseFirestore.instance
        .collection('sales')
        .snapshots()
        .listen((salesSnap) {
      double todayTotal = 0;
      Map<String, double> monthMap = {};

      for (var doc in salesSnap.docs) {
        final data = doc.data();
        final dateStr = data['date'] ?? '';
        final date = DateTime.tryParse(dateStr) ?? DateTime(1970);
        final amount = (data['amount'] ?? 0).toDouble();

        if (DateFormat('yyyy-MM-dd').format(date) == today) {
          todayTotal += amount;
        }

        final label = DateFormat('MMMM yyyy').format(date);
        monthMap[label] = (monthMap[label] ?? 0) + amount;
      }

      final sortedMap = monthMap.entries.toList()
        ..sort((a, b) => DateFormat('MMMM yyyy')
            .parse(a.key)
            .compareTo(DateFormat('MMMM yyyy').parse(b.key)));

      setState(() {
        todaysRevenue = todayTotal;
        monthlySales =
            sortedMap.map((e) => {'month': e.key, 'amount': e.value}).toList();
      });
    });

    FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((usersSnap) {
      int members =
          usersSnap.docs.where((u) => u['userType'] == 'Member').length;

      setState(() {
        totalMembers = members;
      });
    });

    FirebaseFirestore.instance
        .collection('registrations')
        .snapshots()
        .listen((regSnap) {
      int accepted = regSnap.docs
          .where((r) => r['status']?.toString().toLowerCase() == 'accepted')
          .length;

      setState(() {
        activeMemberships = accepted;
      });
    });

    FirebaseFirestore.instance
        .collection('attendance')
        .doc(today)
        .collection('entries')
        .snapshots()
        .listen((entriesSnap) {
      int checkIns = entriesSnap.docs
          .where((doc) =>
              doc['timeIn'] != null && doc['timeIn'].toString().isNotEmpty)
          .length;

      setState(() {
        checkInsToday = checkIns;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final textTheme = GoogleFonts.poppinsTextTheme();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
      body: SafeArea(
        top: true,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildStatCard(
                    "Total Members",
                    totalMembers.toDouble(),
                    const Icon(Icons.people, color: Colors.black),
                    onTap: widget.onNavigateToMembers,
                  ),
                  _buildStatCard(
                    "Today's Revenue",
                    todaysRevenue,
                    const Text('₱',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                    onTap: widget.onNavigateToPending,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Row 2
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildVerticalCountCard(
                    "Check-ins Today",
                    checkInsToday,
                    Icons.qr_code,
                    width: (size.width - 56) / 2,
                    onTap: widget.onNavigateToAttendance,
                  ),
                  _buildVerticalCountCard(
                    "Active Memberships",
                    activeMemberships,
                    Icons.trending_up,
                    width: (size.width - 56) / 2,
                    onTap: widget.onNavigateToPending,
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Sales Tracking card (subpage - still pushes)
              _buildActionCard(
                icon: Icons.trending_up,
                title: "Sales Tracking",
                subtitle: "View daily sales and revenue reports",
                buttonLabel: "Open Sales Tracking",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SalesTrackingPage()),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Attendance shortcut card (uses the provided callback to switch tab)
              _buildActionCard(
                icon: Icons.qr_code,
                title: "QR Attendance",
                subtitle: "Manage QR code check-in system",
                buttonLabel: "Open QR Attendance",
                onPressed: widget.onNavigateToAttendance,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, double value, Widget icon,
      {VoidCallback? onTap}) {
    final isCurrency = title.toLowerCase().contains("revenue");
    final currencyFormatter =
        NumberFormat.currency(locale: 'en_PH', symbol: '₱');

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: (MediaQuery.of(context).size.width - 56) / 2,
        child: Container(
          height: 100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Stack(
            children: [
              Align(alignment: Alignment.centerRight, child: icon),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6D5F5F))),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isCurrency
                          ? currencyFormatter.format(value)
                          : value.toInt().toString(),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6D5F5F)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalCountCard(String title, int count, IconData icon,
      {required double width, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Stack(
          children: [
            Align(
                alignment: Alignment.centerRight,
                child: Icon(icon, color: Colors.black)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6D5F5F))),
                const Spacer(),
                Text('$count',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6D5F5F))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: Colors.black),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: onPressed,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(buttonLabel,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
