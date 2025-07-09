import 'package:flutter/material.dart';

class QRPage extends StatelessWidget {
  const QRPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2, size: 60, color: Colors.grey),
          SizedBox(height: 12),
          Text('Scan a QR code to continue.', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
