import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class PendingRegistrationsPage extends StatelessWidget {
  const PendingRegistrationsPage({super.key});

  Future<void> _acceptRequest(String docId, Map<String, dynamic> data) async {
  await FirebaseFirestore.instance
      .collection('registrations')
      .doc(docId)
      .update({'status': 'accepted'});

  final userId = data['userId'];
  final plan = data['plan'] ?? '';
  final timestamp = DateTime.now();

  // ✅ Extract price from plan text (e.g., '1 month - 650PHP')
  final RegExp priceRegex = RegExp(r'(\d+)PHP');
  final match = priceRegex.firstMatch(plan);
  double amount = 0;
  if (match != null) {
    amount = double.tryParse(match.group(1)!) ?? 0;
  }

  // ✅ Add sales entry
  await FirebaseFirestore.instance.collection('sales').add({
    'userId': userId,
    'amount': amount,
    'date': DateFormat('yyyy-MM-dd').format(timestamp),
    'source': 'Registration',
    'plan': plan,
  });

  // ✅ Update user status to Active
  if (userId != null && userId.toString().isNotEmpty) {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'membershipStatus': 'Active',
    });

    // ✅ Send notification
    await FirebaseFirestore.instance.collection('notifications').add({
      'toUserId': userId,
      'text': '🎉 You have successfully registered! You can now communicate with your Trainer.',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

  Future<void> _deleteRequest(String docId) async {
    await FirebaseFirestore.instance
        .collection('registrations')
        .doc(docId)
        .delete();
  }

  void _showDetailsModal(BuildContext context, Map<String, dynamic> data,
      bool showButtons, String docId) {
    final name = data['name'] ?? 'No Name';
    final plan = data['plan'] ?? '-';
    final startDate = data['startDate'] ?? '-';
    final paymentMethod = data['paymentMethod'] ?? '-';
    final base64Image = data['proofImageBase64'];
    final timestamp = data['timestamp'] as Timestamp?;
    final expiration = timestamp?.toDate().add(const Duration(days: 30));
    final expirationStr =
        expiration != null ? DateFormat('yyyy-MM-dd').format(expiration) : '-';

    Uint8List? proofBytes;
    if (base64Image != null && base64Image.isNotEmpty) {
      try {
        proofBytes = base64Decode(base64Image);
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Text(name,
                  style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _infoRow("Plan", plan),
              _infoRow("Start Date", startDate),
              _infoRow("Payment", paymentMethod),
              if (!showButtons)
                _infoRow("Expires", expirationStr, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text("Proof of Payment",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: proofBytes != null
                    ? Image.memory(
                        proofBytes,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                            child: Text('No proof image available')),
                      ),
              ),
              if (showButtons) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _deleteRequest(docId),
                        child: const Text("Delete",
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context); // Close the modal first
                          await _acceptRequest(docId, data);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade700,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Accept"),
                      ),
                    ),
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text("$title: ",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(color: color ?? Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerStyle = GoogleFonts.poppins(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: Colors.blueGrey.shade900,
    );

    final subStyle = GoogleFonts.poppins(
      fontSize: 14,
      color: Colors.blueGrey.shade600,
    );

    final thirtyDaysAgo = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 30)),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Pending Registrations", style: headerStyle),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('registrations')
                      .where('status', isEqualTo: 'pending')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text('No pending registration requests.',
                            style: subStyle),
                      );
                    }

                    return Column(
                      children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] ?? 'No Name';
                        final plan = data['plan'] ?? '-';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            title: Text(name,
                                style: headerStyle.copyWith(fontSize: 16)),
                            subtitle: Text("Plan: $plan", style: subStyle),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () =>
                                _showDetailsModal(context, data, true, doc.id),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Text("Accepted (last 30 days)", style: headerStyle),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('registrations')
                      .where('status', isEqualTo: 'accepted')
                      .where('timestamp', isGreaterThan: thirtyDaysAgo)
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text('No accepted registrations.',
                            style: subStyle),
                      );
                    }

                    return Column(
                      children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] ?? 'No Name';
                        final plan = data['plan'] ?? '-';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            title: Text(name,
                                style: headerStyle.copyWith(fontSize: 16)),
                            subtitle: Text("Plan: $plan", style: subStyle),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () =>
                                _showDetailsModal(context, data, false, doc.id),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
