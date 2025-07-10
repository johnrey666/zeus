import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

class QRPage extends StatefulWidget {
  const QRPage({super.key});

  @override
  State<QRPage> createState() => _QRPageState();
}

class _QRPageState extends State<QRPage> {
  final user = FirebaseAuth.instance.currentUser;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, String> _attendanceMap = {};
  bool _hasTimedInToday = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('attendance')
        .get();

    final Map<DateTime, String> tempMap = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = data['time']?.toDate();
      if (timestamp != null) {
        final key = DateTime(timestamp.year, timestamp.month, timestamp.day);
        tempMap[key] = _formatTime(timestamp);

        if (_isToday(key)) {
          _hasTimedInToday = true;
        }
      }
    }

    setState(() {
      _attendanceMap = tempMap;
    });
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _timeIn() async {
    if (user == null || _hasTimedInToday) return;

    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('attendance')
        .doc(todayKey.toString())
        .set({
      'time': Timestamp.fromDate(now),
    });

    setState(() {
      _attendanceMap[todayKey] = _formatTime(now);
      _hasTimedInToday = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Time-in recorded successfully.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final timeInToday =
        _attendanceMap[DateTime(today.year, today.month, today.day)];

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
            eventLoader: (day) {
              final key = DateTime(day.year, day.month, day.day);
              return _attendanceMap.containsKey(key) ? [true] : [];
            },
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.access_time, size: 48, color: Colors.blueAccent),
                  const SizedBox(height: 12),
                  Text(
                    _hasTimedInToday
                        ? "You timed in at $timeInToday today"
                        : "You haven’t timed in today yet",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _hasTimedInToday ? null : _timeIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _hasTimedInToday ? Colors.grey : Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text("Time In Now"),
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
