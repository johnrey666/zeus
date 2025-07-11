import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zeus/pages/chat_page.dart';

class TrainerMessagePage extends StatelessWidget {
  const TrainerMessagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('registrations')
              .where('status', isEqualTo: 'accepted')
              .where('trainerId', isEqualTo: currentUser.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'No members connected yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (_, index) {
                final memberId = docs[index]['userId'];
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(memberId)
                      .get(),
                  builder: (ctx, userSnapshot) {
                    if (!userSnapshot.hasData) return const SizedBox();
                    final data =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    final name = '${data['firstName']} ${data['lastName']}';
                    final avatar = data['profileImagePath'] ?? '';

                    return _connectionTile(
                      context: context,
                      name: name,
                      userId: memberId,
                      avatar: avatar,
                    );
                  },
                );
              },
            );
          },
        ),
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
      color: Colors.white, // ✅ Ensure white background for the card
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blueGrey[100],
                backgroundImage: (avatar != null && avatar.isNotEmpty)
                    ? NetworkImage(avatar)
                    : null,
                child: (avatar == null || avatar.isEmpty)
                    ? Text(name[0], style: const TextStyle(fontSize: 18))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
