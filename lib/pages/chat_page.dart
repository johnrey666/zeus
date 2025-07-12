import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String peerAvatar;

  const ChatPage({
    super.key,
    required this.peerId,
    required this.peerName,
    this.peerAvatar = '',
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  final TextEditingController _msgController = TextEditingController();
  late String conversationId;
  String? _plan;
  String? _expiration;
  bool _showInfo = false;

  @override
  void initState() {
    super.initState();
    conversationId = getConversationId(currentUser.uid, widget.peerId);
    _loadRegistrationInfo();
  }

  static String getConversationId(String a, String b) {
    return a.hashCode <= b.hashCode ? '${a}_$b' : '${b}_$a';
  }

  Future<void> _loadRegistrationInfo() async {
    final regSnap = await FirebaseFirestore.instance
        .collection('registrations')
        .where('status', isEqualTo: 'accepted')
        .where('userId', isEqualTo: currentUser.uid)
        .where('trainerId', isEqualTo: widget.peerId)
        .get();

    if (regSnap.docs.isNotEmpty) {
      final data = regSnap.docs.first.data();
      final timestamp = data['timestamp'] as Timestamp?;
      final expiry = timestamp?.toDate().add(const Duration(days: 30));
      setState(() {
        _plan = data['plan'];
        _expiration =
            expiry != null ? DateFormat('yyyy-MM-dd').format(expiry) : 'N/A';
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('messages')
        .doc(conversationId)
        .collection('chats')
        .add({
      'senderId': currentUser.uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final infoStyle =
        GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 0.4,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.peerAvatar.isNotEmpty
                  ? NetworkImage(widget.peerAvatar)
                  : null,
              child: widget.peerAvatar.isEmpty
                  ? Text(widget.peerName[0],
                      style: const TextStyle(color: Colors.white))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.peerName,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.black87)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              setState(() {
                _showInfo = !_showInfo;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showInfo)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.grey.shade100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Plan: ${_plan ?? 'Loading...'}", style: infoStyle),
                  const SizedBox(height: 4),
                  Text("Expires: ${_expiration ?? 'Loading...'}",
                      style: infoStyle),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .doc(conversationId)
                  .collection('chats')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == currentUser.uid;
                    final message = data['text'] ?? '';
                    final timestamp = data['timestamp'] as Timestamp?;
                    final time = timestamp != null
                        ? DateFormat('h:mm a').format(timestamp.toDate())
                        : '';

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.7),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xFF4A90E2)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              message,
                              style: GoogleFonts.poppins(
                                color: isMe ? Colors.white : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 6, right: 6, bottom: 6),
                            child: Text(time,
                                style: GoogleFonts.poppins(
                                    fontSize: 10, color: Colors.grey[600])),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: _msgController,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Type your message...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF4A90E2),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
