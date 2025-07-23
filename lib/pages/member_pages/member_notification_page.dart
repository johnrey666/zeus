import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MemberNotificationPage extends StatefulWidget {
  const MemberNotificationPage({super.key});

  @override
  State<MemberNotificationPage> createState() => _MemberNotificationPageState();
}

class _MemberNotificationPageState extends State<MemberNotificationPage> {
  String? uid;

  @override
  void initState() {
    super.initState();
    getCurrentUserUid();
  }

  Future<void> getCurrentUserUid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        uid = user.uid;
      });
    }
  }

  void markAsRead(String docId, List readBy) async {
    if (uid != null && !readBy.contains(uid)) {
      await FirebaseFirestore.instance.collection('announcements').doc(docId).update({
        'readBy': FieldValue.arrayUnion([uid])
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          final newNotifs = docs.where((doc) => !(doc['readBy'] as List).contains(uid)).toList();
          final oldNotifs = docs.where((doc) => (doc['readBy'] as List).contains(uid)).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (newNotifs.isNotEmpty) ...[
                  Text('New Notifications', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  ...newNotifs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final dt = (data['timestamp'] as Timestamp?)?.toDate();
                    final date = dt != null ? DateFormat.yMd().format(dt) : '';
                    final time = dt != null ? DateFormat.jm().format(dt) : '';
                    return GestureDetector(
                      onTap: () => markAsRead(doc.id, data['readBy']),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
                                  const SizedBox(width: 6),
                                  Text(data['adminName'] ?? 'Admin', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text('New', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(data['text'], style: GoogleFonts.poppins(fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('$date • $time', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 30),
                ],
                Text('Previous Notifications', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                ...oldNotifs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final dt = (data['timestamp'] as Timestamp?)?.toDate();
                  final date = dt != null ? DateFormat.yMd().format(dt) : '';
                  final time = dt != null ? DateFormat.jm().format(dt) : '';
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
                              const SizedBox(width: 6),
                              Text(data['adminName'] ?? 'Admin', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(data['text'], style: GoogleFonts.poppins(fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('$date • $time', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}
