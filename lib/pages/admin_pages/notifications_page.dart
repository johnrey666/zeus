import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final TextEditingController _controller = TextEditingController();

  Future<void> postAnnouncement() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await FirebaseFirestore.instance.collection('announcements').add({
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'adminName': 'Admin', 
      'readBy': [],
    });

    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.campaign, size: 50),
          const SizedBox(height: 10),
          Text('Create new announcement',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Announcement text', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    cursorColor: Colors.blue,
                    decoration: const InputDecoration.collapsed(hintText: ''),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: postAnnouncement,
                    child: Container(
                      width: 70,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('POST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text('Past Announcements', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('announcements')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final docs = snapshot.data!.docs;

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final dt = (data['timestamp'] as Timestamp?)?.toDate();
                  final date = dt != null ? DateFormat.yMd().format(dt) : '...';
                  final time = dt != null ? DateFormat.jm().format(dt) : '...';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
  radius: 12,
  backgroundImage: AssetImage('assets/zeus_logo.png'),
  backgroundColor: Colors.transparent,
),

                              const SizedBox(width: 6),
                              Text(data['adminName'] ?? 'Admin', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                              const Spacer(),
                              Text(date, style: GoogleFonts.poppins(fontSize: 12)),
                              const SizedBox(width: 6),
                              Text(time, style: GoogleFonts.poppins(fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
  data['text'] ?? '',
  textAlign: TextAlign.justify,
  style: GoogleFonts.poppins(fontSize: 14),
),

                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
