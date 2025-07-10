import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zeus/pages/chat_page.dart';

class MessagePage extends StatelessWidget {
  const MessagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('registrations')
            .where('status', isEqualTo: 'accepted')
            .where('userId', isEqualTo: currentUser.uid)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No trainer assigned yet.'));
          }

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(docs.first['trainerId'])
                .get(),
            builder: (ctx2, snap2) {
              if (!snap2.hasData) return const SizedBox();
              final data = snap2.data!.data() as Map<String, dynamic>;
              final trainerId = snap2.data!.id;
              final name = '${data['firstName']} ${data['lastName']}';
              final avatar = data['profileImagePath'] ?? '';

              return ListView(
                children: [
                  _connectionTile(
                    context: context,
                    name: name,
                    userId: trainerId,
                    avatar: avatar,
                  )
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _connectionTile({
    required BuildContext context,
    required String name,
    required String userId,
    String? avatar,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.blueGrey[100],
          backgroundImage: (avatar != null && avatar.isNotEmpty)
              ? NetworkImage(avatar)
              : null,
          child: (avatar == null || avatar.isEmpty)
              ? Text(name[0], style: const TextStyle(fontSize: 18))
              : null,
        ),
        title: Text(name, style: GoogleFonts.poppins(fontSize: 16)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatPage(
                peerId: userId,
                peerName: name,
                peerAvatar: avatar ?? '',
              ),
            ),
          );
        },
      ),
    );
  }
}
