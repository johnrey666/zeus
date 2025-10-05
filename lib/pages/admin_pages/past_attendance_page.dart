import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PastAttendancePage extends StatefulWidget {
  const PastAttendancePage({super.key});

  @override
  State<PastAttendancePage> createState() => _PastAttendancePageState();
}

class _PastAttendancePageState extends State<PastAttendancePage> {
  String? selectedDateId;
  List<String> dateIds = [];
  int currentPage = 0;
  static const int pageSize = 10;

  @override
  Widget build(BuildContext context) {
    final attendanceCol = FirebaseFirestore.instance.collection('attendance');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Attendance'),
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: attendanceCol.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No attendance records found.'));
          }

          // Sort and extract date IDs
          final sortedDocs = List.from(docs)
            ..sort((a, b) => b.id.compareTo(a.id));
          dateIds = sortedDocs.map((doc) => doc.id).toList().cast<String>();

          // Set default selected date if not set
          selectedDateId ??= dateIds.first;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dropdown for date selection
                Row(
                  children: [
                    const Text(
                      "Select Date: ",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: selectedDateId,
                      items: dateIds.map((id) {
                        String formatted;
                        try {
                          formatted = DateFormat('MMM d, yyyy')
                              .format(DateTime.parse(id));
                        } catch (_) {
                          formatted = id;
                        }
                        return DropdownMenuItem(
                          value: id,
                          child: Text(formatted),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedDateId = val;
                          currentPage = 0;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Attendance entries for selected date
                Expanded(
                  child: FutureBuilder<QuerySnapshot>(
                    future: attendanceCol
                        .doc(selectedDateId)
                        .collection('entries')
                        .orderBy('timestamp', descending: true)
                        .get(),
                    builder: (context, entrySnap) {
                      if (!entrySnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final entries = entrySnap.data!.docs;
                      if (entries.isEmpty) {
                        return const Center(
                            child: Text('No entries for this date.'));
                      }

                      // Pagination logic
                      final totalPages = (entries.length / pageSize).ceil();
                      final start = currentPage * pageSize;
                      final end = (start + pageSize) > entries.length
                          ? entries.length
                          : (start + pageSize);
                      final pageEntries = entries.sublist(start, end);

                      return Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              itemCount: pageEntries.length,
                              itemBuilder: (context, idx) {
                                final doc = pageEntries[idx];
                                final data = doc.data() as Map<String, dynamic>;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Colors.black87,
                                      child: Icon(Icons.person,
                                          color: Colors.white),
                                    ),
                                    title: Text(
                                        "${data['firstName']} ${data['lastName']}"),
                                    subtitle: Text(
                                      'Check-in: ${_formatTo12Hour(data['timeIn'])} | '
                                      'Check-out: ${_formatTo12Hour(data['timeOut'])}',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Pagination controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: currentPage > 0
                                    ? () {
                                        setState(() {
                                          currentPage--;
                                        });
                                      }
                                    : null,
                              ),
                              Text('Page ${currentPage + 1} of $totalPages'),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: currentPage < totalPages - 1
                                    ? () {
                                        setState(() {
                                          currentPage++;
                                        });
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _formatTo12Hour(dynamic timeStr) {
    if (timeStr == null || timeStr.toString().trim().isEmpty) return '-';
    try {
      final parsed = DateFormat("HH:mm").parse(timeStr.toString());
      return DateFormat("h:mm a").format(parsed);
    } catch (_) {
      return '-';
    }
  }
}
