import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendancePage extends StatelessWidget {
  const AttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final attendanceRef = FirebaseFirestore.instance
        .collection('attendance')
        .doc(todayDocId)
        .collection('entries');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'QR CODE SCANNER',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Scan members QR Code for quick check in/check out',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              Container(
                height: 180,
                width: 180,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black12)],
                ),
                child: const Icon(Icons.qr_code_scanner, size: 120, color: Colors.black87),
              ),
              const SizedBox(height: 16),

              GestureDetector(
  onTap: () {
    // Start QR Scanner logic
  },
  child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 4,
          offset: const Offset(2, 2),
        ),
      ],
    ),
    child: const Text(
      'Start QR Scanner',
      style: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    ),
  ),
),

              const SizedBox(height: 24),

              StreamBuilder<QuerySnapshot>(
                stream: attendanceRef.snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];

                  final checkInsCount = docs.length;

                  // Safe currentlyInGym count
                  final currentlyInGym = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final timeOut = data['timeOut'];
                    return timeOut == null || timeOut.toString().isEmpty;
                  }).length;

                  // Peak Hour and Avg Duration
                  Map<String, int> hourlyCount = {};
                  List<int> durationsInMinutes = [];

                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final timestamp = (data['timestamp'] as Timestamp).toDate();
                    final hour = DateFormat.H().format(timestamp);
                    hourlyCount[hour] = (hourlyCount[hour] ?? 0) + 1;

                    if (data.containsKey('timeIn') && data.containsKey('timeOut')) {
                      try {
                        final timeIn = DateFormat('HH:mm').parse(data['timeIn']);
                        final timeOut = DateFormat('HH:mm').parse(data['timeOut']);
                        final duration = timeOut.difference(timeIn).inMinutes;
                        if (duration > 0) durationsInMinutes.add(duration);
                      } catch (_) {}
                    }
                  }

                  final peakHour = hourlyCount.entries.isEmpty
                      ? '-'
                      : DateFormat('h:00 a').format(DateTime(
                          0,
                          1,
                          1,
                          int.parse(hourlyCount.entries
                              .reduce((a, b) => a.value > b.value ? a : b)
                              .key),
                        ));

                  final avgDuration = durationsInMinutes.isEmpty
                      ? '-'
                      : '${(durationsInMinutes.reduce((a, b) => a + b) ~/ durationsInMinutes.length)} mins';

                  return Column(
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: _buildStatCard(
                              icon: Icons.calendar_today,
                              title: "Today's Check-ins",
                              value: '$checkInsCount',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: _buildStatCard(
                              icon: Icons.group,
                              title: 'Currently In Gym',
                              value: '$currentlyInGym',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Flexible(
                            child: _buildStatCard(
                              icon: Icons.access_time,
                              title: 'Peak Hour',
                              value: peakHour,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: _buildStatCard(
                              icon: Icons.timer_outlined,
                              title: 'Avg Duration',
                              value: avgDuration,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Today's Attendance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),

              StreamBuilder<QuerySnapshot>(
                stream: attendanceRef.orderBy('timestamp', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final docs = snapshot.data!.docs;

                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 2,
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.black87,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text("${data['firstName']} ${data['lastName']}"),
                          subtitle: Text(
                            'Check-in: ${_formatTo12Hour(data['timeIn'])} | Check-out: ${_formatTo12Hour(data['timeOut'])}',
                          ),
                          trailing: Text(DateFormat('MM/dd/yy').format((data['timestamp'] as Timestamp).toDate())),
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

  String _formatTo12Hour(dynamic timeStr) {
    if (timeStr == null || timeStr.toString().trim().isEmpty) return '-';
    try {
      final parsed = DateFormat("HH:mm").parse(timeStr.toString());
      return DateFormat("h:mm a").format(parsed);
    } catch (_) {
      return '-';
    }
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    const textColor = Color(0xFF6D5F5F);

    return Container(
      height: 90,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black12)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: textColor)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
          ),
          Icon(icon, size: 28),
        ],
      ),
    );
  }
}
