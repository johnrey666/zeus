import 'package:flutter/material.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 60, color: Colors.grey),
          SizedBox(height: 12),
          Text('Your reports will show up here.', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
