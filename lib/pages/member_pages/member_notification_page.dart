import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MemberNotificationPage extends StatefulWidget {
  final String userId;
  const MemberNotificationPage({super.key, required this.userId});

  @override
  State<MemberNotificationPage> createState() => _MemberNotificationPageState();
}

class _MemberNotificationPageState extends State<MemberNotificationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _hasIncrementedSeen = false;

  Future<void> _incrementSeenCount(List<DocumentSnapshot> docs) async {
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final seenBy = Map<String, dynamic>.from(data['seenBy'] ?? {});
      final currentCount = seenBy[widget.userId] ?? 0;

      await _firestore.collection('announcements').doc(doc.id).update({
        'seenBy.${widget.userId}': currentCount + 1,
      });
    }
  }

  Widget _buildNotificationCard(DocumentSnapshot doc, bool isNew) {
    final data = doc.data() as Map<String, dynamic>;
    final text = data['text'] ?? '';
    final ts = data['timestamp'] as Timestamp?;
    final timeStr = ts != null
        ? DateFormat('MMM d, h:mm a').format(ts.toDate())
        : '';

    return Card(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/zeus_logo.png',
                  height: 24,
                  width: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  "Admin",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: isNew
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeStr,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'New',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeStr,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.check_circle,
                            size: 14, color: Colors.green),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title:
            const Text("Notifications", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('announcements')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          final newNotifs = <DocumentSnapshot>[];
          final oldNotifs = <DocumentSnapshot>[];

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final seenBy = Map<String, dynamic>.from(data['seenBy'] ?? {});
            final seenCount = seenBy[widget.userId] ?? 0;

            if (seenCount < 2) {
              newNotifs.add(doc);
            } else {
              oldNotifs.add(doc);
            }
          }

          // Increment seen count only once per page load
          if (!_hasIncrementedSeen && newNotifs.isNotEmpty) {
            _hasIncrementedSeen = true;
            _incrementSeenCount(newNotifs);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Center(
                    child: Text(
                      'New Notifications',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (newNotifs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: Text(
                        'No new notifications',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ...newNotifs
                    .map((doc) => _buildNotificationCard(doc, true))
                    .toList(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Center(
                    child: Text(
                      'Previous Notifications',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                ...oldNotifs
                    .map((doc) => _buildNotificationCard(doc, false))
                    .toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}
