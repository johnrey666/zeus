import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class QRPage extends StatefulWidget {
  const QRPage({super.key});

  @override
  State<QRPage> createState() => _QRPageState();
}

class _QRPageState extends State<QRPage> {
  final user = FirebaseAuth.instance.currentUser;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _hasTimedInToday = false;
  bool _hasTimedOutToday = false;
  String? _timeInDisplay;
  String? _timeOutDisplay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _fetchTodayAttendance();
  }

  Future<void> _fetchTodayAttendance() async {
    if (user == null) return;

    final todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final doc = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(todayDocId)
        .collection('entries')
        .doc(user!.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _hasTimedInToday = data.containsKey('timeIn');
        _hasTimedOutToday = data.containsKey('timeOut');
        _timeInDisplay = data['timeIn'] ?? '';
        _timeOutDisplay = data['timeOut'] ?? '';
      });
    }
  }

  Future<void> _handleTimeIn() async {
    if (user == null) return;

    final now = DateTime.now();
    final todayDocId = DateFormat('yyyy-MM-dd').format(now);

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    final userData = userDoc.data();

    await FirebaseFirestore.instance
        .collection('attendance')
        .doc(todayDocId)
        .collection('entries')
        .doc(user!.uid)
        .set({
      'timeIn': DateFormat.Hm().format(now),
      'firstName': userData?['firstName'] ?? '',
      'lastName': userData?['lastName'] ?? '',
      'timestamp': now,
    });

    setState(() {
      _hasTimedInToday = true;
      _timeInDisplay = DateFormat.Hm().format(now);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Time-in recorded successfully.")),
    );
  }

  Future<void> _handleTimeOut() async {
    if (user == null) return;

    final now = DateTime.now();
    final todayDocId = DateFormat('yyyy-MM-dd').format(now);

    await FirebaseFirestore.instance
        .collection('attendance')
        .doc(todayDocId)
        .collection('entries')
        .doc(user!.uid)
        .update({
      'timeOut': DateFormat.Hm().format(now),
    });

    setState(() {
      _hasTimedOutToday = true;
      _timeOutDisplay = DateFormat.Hm().format(now);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Time-out recorded successfully.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text("Attendance Tracker",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) =>
                isSameDay(_selectedDay ?? DateTime.now(), day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                  color: Colors.blue.shade100, shape: BoxShape.circle),
              selectedDecoration:
                  BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              markerDecoration: const BoxDecoration(
                  color: Colors.green, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  const Icon(Icons.access_time,
                      size: 48, color: Colors.blueAccent),
                  const SizedBox(height: 12),
                  Text(
                    _hasTimedInToday
                        ? _hasTimedOutToday
                            ? "You timed in at $_timeInDisplay and out at $_timeOutDisplay today"
                            : "You timed in at $_timeInDisplay today"
                        : "You haven’t timed in today yet",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _hasTimedInToday
                        ? (_hasTimedOutToday ? null : _handleTimeOut)
                        : _handleTimeIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _hasTimedOutToday ? Colors.grey : Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(
                        _hasTimedInToday ? "Time Out Now" : "Time In Now"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
