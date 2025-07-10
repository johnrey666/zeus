import 'package:flutter/material.dart';

class AttendancePage extends StatelessWidget {
  const AttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code, size: 60, color: Colors.green),
          SizedBox(height: 12),
          Text('Attendance Monitoring', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}
