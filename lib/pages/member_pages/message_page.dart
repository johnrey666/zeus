import 'package:flutter/material.dart';

class MessagePage extends StatelessWidget {
  const MessagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.message, size: 60, color: Colors.grey),
          SizedBox(height: 12),
          Text('No messages yet.', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
