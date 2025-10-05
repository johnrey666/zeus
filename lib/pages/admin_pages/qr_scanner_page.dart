import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool scanned = false;

  @override
  void reassemble() {
    super.reassemble();
    controller?.pauseCamera();
    controller?.resumeCamera();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (scanned) return;
      scanned = true;

      final memberId = scanData.code;
      log('Scanned: $memberId');

      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('memberId', isEqualTo: memberId)
          .get();

      if (userQuery.docs.isEmpty) {
        _showMessage('User not found.');
        return;
      }

      final userData = userQuery.docs.first.data();
      final userId = userQuery.docs.first.id;

      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final attendanceDocRef =
          FirebaseFirestore.instance.collection('attendance').doc(today);
      final entriesRef = attendanceDocRef.collection('entries');

      // Ensure the parent attendance doc exists with a dummy field
      await attendanceDocRef.set({'exists': true}, SetOptions(merge: true));

      final entryQuery =
          await entriesRef.where('memberId', isEqualTo: memberId).get();

      if (entryQuery.docs.isEmpty) {
        // First scan = TIME IN
        await entriesRef.add({
          'memberId': memberId,
          'firstName': userData['firstName'],
          'lastName': userData['lastName'],
          'timeIn': DateFormat('HH:mm').format(now),
          'timeOut': '',
          'timestamp': now,
          'userId': userId,
        });
        _showMessage('Time In successful!');
      } else {
        final doc = entryQuery.docs.first;
        final data = doc.data();
        if (data['timeOut'] == null || data['timeOut'].toString().isEmpty) {
          // Second scan = TIME OUT
          await entriesRef.doc(doc.id).update({
            'timeOut': DateFormat('HH:mm').format(now),
          });
          _showMessage('Time Out successful!');
        } else {
          _showMessage('Already Timed Out.');
        }
      }
    });
  }

  void _showMessage(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("Attendance"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text("OK", style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR Code")),
      body: QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
        overlay: QrScannerOverlayShape(
          borderColor: Colors.blueAccent,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: 300,
        ),
      ),
    );
  }
}
