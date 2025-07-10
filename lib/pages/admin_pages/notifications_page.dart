import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications, size: 60, color: Colors.redAccent),
          SizedBox(height: 12),
          Text('Announcements', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}
