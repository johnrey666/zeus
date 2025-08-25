import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class QRPage extends StatefulWidget {
  const QRPage({super.key});

  @override
  State<QRPage> createState() => _QRPageState();
}

class _QRPageState extends State<QRPage> {
  String fullName = '';
  String memberId = '';
  Stream<QuerySnapshot<Map<String, dynamic>>>? attendanceStream;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();

      if (userData != null) {
        final fetchedMemberId = userData['memberId'] ?? '';
        final fetchedName =
            '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}';

        setState(() {
          memberId = fetchedMemberId;
          fullName = fetchedName;
        });

        _initializeAttendanceStream(fetchedMemberId);
      }
    }
  }

  void _initializeAttendanceStream(String memberId) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final entriesRef = FirebaseFirestore.instance
        .collection('attendance')
        .doc(today)
        .collection('entries');

    setState(() {
      attendanceStream = entriesRef
          .where('memberId', isEqualTo: memberId)
          .snapshots(); // No index needed
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: memberId.isEmpty || attendanceStream == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: attendanceStream,
              builder: (context, snapshot) {
                String timeIn = 'N/A';
                String timeOut = 'N/A';
                String date = DateFormat('MM/dd/yy').format(DateTime.now());

                if (snapshot.hasError) {
                  print("❌ Error fetching attendance: ${snapshot.error}");
                  timeIn = timeOut = date = 'Error';
                } else if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasData) {
                  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                      snapshot.data!.docs.toList();

                  if (docs.isNotEmpty) {
                    // ✅ Safely get the latest document without .reduce()
                    QueryDocumentSnapshot<Map<String, dynamic>> latestDoc =
                        docs[0];

                    for (final doc in docs) {
                      final ts = doc.data()['timestamp'] as Timestamp?;
                      final latestTs =
                          latestDoc.data()['timestamp'] as Timestamp?;
                      if (ts != null &&
                          latestTs != null &&
                          ts.compareTo(latestTs) > 0) {
                        latestDoc = doc;
                      }
                    }

                    final data = latestDoc.data();
                    print("✅ Attendance data found: $data");

                    if (data.containsKey('timeIn')) {
                      timeIn = _formatTo12Hour(data['timeIn']);
                    }
                    if (data.containsKey('timeOut')) {
                      timeOut = _formatTo12Hour(data['timeOut']);
                    }
                    if (data['timestamp'] is Timestamp) {
                      date = DateFormat('MM/dd/yy')
                          .format((data['timestamp'] as Timestamp).toDate());
                    }
                  } else {
                    print("ℹ️ No attendance data found for today.");
                  }
                }

                return SafeArea(
                  top: true,
                  bottom: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          fullName,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'ID: $memberId',
                          style:
                              const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 40),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.shade300, width: 2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: QrImageView(
                              data: memberId,
                              version: QrVersions.auto,
                              size: 250.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Scan this code for attendance',
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                const Text('Check In',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Text(timeIn),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Check Out',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Text(timeOut),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Date',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Text(date),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatTo12Hour(dynamic timeStr) {
    if (timeStr == null || timeStr.toString().trim().isEmpty) return 'N/A';
    try {
      DateTime parsed;
      if (timeStr.toString().length <= 5) {
        parsed = DateFormat("HH:mm").parse(timeStr.toString());
      } else {
        parsed = DateFormat("HH:mm:ss").parse(timeStr.toString());
      }
      return DateFormat("h:mm a").format(parsed);
    } catch (_) {
      return 'N/A';
    }
  }
}
