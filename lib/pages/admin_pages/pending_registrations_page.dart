import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class PendingRegistrationsPage extends StatefulWidget {
  const PendingRegistrationsPage({super.key});

  @override
  State<PendingRegistrationsPage> createState() =>
      _PendingRegistrationsPageState();
}

class _PendingRegistrationsPageState extends State<PendingRegistrationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _pendingPage = 0;
  int _acceptedPage = 0;
  final int _pageSize = 4;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _acceptRequest(String docId, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('registrations')
        .doc(docId)
        .update({'status': 'accepted'});

    final userId = data['userId'];
    final plan = data['plan'] ?? '';
    double amount = 0;
    final RegExp priceRegex = RegExp(r'(\d+)PHP');
    final match = priceRegex.firstMatch(plan);
    if (match != null) {
      amount = double.tryParse(match.group(1)!) ?? 0;
    }

    final timestamp = DateTime.now();
    final startDateStr = DateFormat('yyyy-MM-dd').format(timestamp);

    // Add sales record
    await FirebaseFirestore.instance.collection('sales').add({
      'userId': userId,
      'amount': amount,
      'date': startDateStr,
      'source': 'Registration',
      'plan': plan,
    });

    // Update user record
    if (userId != null && userId.toString().isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'membershipStatus': 'Active',
        'plan': plan,
        'amount': amount,
        'startDate': startDateStr,
        'planExpiry': DateFormat('yyyy-MM-dd')
            .format(timestamp.add(const Duration(days: 30))),
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'toUserId': userId,
        'text':
            '🎉 You have successfully registered! You can now communicate with your Trainer.',
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
                        onPressed: () async {
                          Navigator.pop(context);
                          await _deleteRequest(docId);
                        },
                        child: const Text("Delete",
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _acceptRequest(docId, data);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 58, 136, 61),
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

  Widget _buildCard(QueryDocumentSnapshot doc, bool showButtons) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'No Name';
    final plan = data['plan'] ?? '-';
    final headerStyle = GoogleFonts.poppins(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: Colors.blueGrey.shade900,
    );
    final subStyle = GoogleFonts.poppins(
      fontSize: 14,
      color: Colors.blueGrey.shade600,
    );
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Text(name, style: headerStyle.copyWith(fontSize: 16)),
        subtitle: Text("Plan: $plan", style: subStyle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _showDetailsModal(context, data, showButtons, doc.id),
      ),
    );
  }

  Widget _buildTabContent(String title, Stream<QuerySnapshot> stream, int page,
      Function(int) setPage, bool showButtons) {
    final headerStyle = GoogleFonts.poppins(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: Colors.blueGrey.shade900,
    );
    final subStyle = GoogleFonts.poppins(
      fontSize: 14,
      color: Colors.blueGrey.shade600,
    );
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final total = docs.length;
        final startIndex = page * _pageSize;
        final endIndex = (startIndex + _pageSize).clamp(0, total);
        final paginatedDocs = docs.skip(startIndex).take(_pageSize).toList();

        if (total == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('No ${title.toLowerCase()} registrations.',
                style: subStyle),
          );
        }

        final displayStart = startIndex + 1;
        final displayEnd = startIndex + paginatedDocs.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: headerStyle),
            const SizedBox(height: 12),
            ...paginatedDocs.map((doc) => _buildCard(doc, showButtons)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: page > 0 ? () => setPage(page - 1) : null,
                  child: const Text('Previous'),
                ),
                Text('$displayStart - $displayEnd of $total'),
                TextButton(
                  onPressed:
                      paginatedDocs.length == _pageSize && endIndex < total
                          ? () => setPage(page + 1)
                          : null,
                  child: const Text('Next'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final thirtyDaysAgo = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 30)),
    );

    final pendingStream = FirebaseFirestore.instance
        .collection('registrations')
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots();

    final acceptedStream = FirebaseFirestore.instance
        .collection('registrations')
        .where('status', isEqualTo: 'accepted')
        .where('timestamp', isGreaterThan: thirtyDaysAgo)
        .orderBy('timestamp', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'Active'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildTabContent(
                      "Pending Registrations",
                      pendingStream,
                      _pendingPage,
                      (int newPage) => setState(() => _pendingPage = newPage),
                      true,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildTabContent(
                      "Active Membership",
                      acceptedStream,
                      _acceptedPage,
                      (int newPage) => setState(() => _acceptedPage = newPage),
                      false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
