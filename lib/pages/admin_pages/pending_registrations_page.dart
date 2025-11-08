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
  final int _pageSize = 3; // Reduced to 3 as suggested to help prevent overflow

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _acceptRequest(
      String docId, Map<String, dynamic> data, BuildContext context) async {
    try {
      final startDateStr =
          data['startDate'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      final startDate = DateTime.parse(startDateStr);
      final endDateStr = DateFormat('yyyy-MM-dd')
          .format(startDate.add(const Duration(days: 30)));

      final plan = data['plan'] ?? '';
      double amount = 0;
      final RegExp priceRegex = RegExp(r'(\d+)PHP');
      final match = priceRegex.firstMatch(plan);
      if (match != null) {
        amount = double.tryParse(match.group(1)!) ?? 0;
      }

      // Update registration record
      await FirebaseFirestore.instance
          .collection('registrations')
          .doc(docId)
          .update({
        'status': 'accepted',
        'startDate': startDateStr,
        'endDate': endDateStr,
        'amount': amount,
      });

      // Add sales record
      await FirebaseFirestore.instance.collection('sales').add({
        'userId': data['userId'],
        'amount': amount,
        'date': startDateStr,
        'source': 'Registration',
        'plan': plan,
      });

      // Update user record
      final userId = data['userId'];
      if (userId != null && userId.toString().isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'membershipStatus': 'Active',
          'plan': plan,
          'amount': amount,
          'startDate': startDateStr,
          'endDate': endDateStr,
        });

        await FirebaseFirestore.instance.collection('notifications').add({
          'toUserId': userId,
          'text':
              '🎉 You have successfully registered! You can now communicate with your Trainer.',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registration Accepted"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error accepting registration: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _cancelMembership(
      String docId, Map<String, dynamic> data, BuildContext context) async {
    try {
      // Update registration record
      await FirebaseFirestore.instance
          .collection('registrations')
          .doc(docId)
          .update({
        'status': 'cancelled',
        'cancelDate': Timestamp.now(),
      });

      // Update user record
      final userId = data['userId'];
      if (userId != null && userId.toString().isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'membershipStatus': 'Cancelled',
        });

        await FirebaseFirestore.instance.collection('notifications').add({
          'toUserId': userId,
          'text': 'Your membership has been cancelled.',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Membership Cancelled"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error cancelling membership: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _deleteRequest(String docId, BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('registrations')
          .doc(docId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registration Declined"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error deleting registration: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  void _showEnlargedImage(Uint8List imageBytes) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            Center(
              child: Image.memory(
                imageBytes,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 40,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailsModal(BuildContext context, Map<String, dynamic> data,
      bool showButtons, String docId) {
    final name = data['name'] ?? 'No Name';
    final plan = data['plan'] ?? '-';
    final startDate = data['startDate'] ?? '-';
    final paymentMethod = data['paymentMethod'] ?? '-';
    final base64Image = data['proofImageBase64'];
    final endDateStr = data['endDate'] ?? '-';

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
                _infoRow("Expires", endDateStr, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text("Proof of Payment",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: proofBytes != null
                    ? GestureDetector(
                        onTap: () => _showEnlargedImage(proofBytes!),
                        child: Image.memory(
                          proofBytes,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
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
                          await _deleteRequest(docId, context);
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
                          await _acceptRequest(docId, data, context);
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
              ] else ...[
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _cancelMembership(docId, data, context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Cancel Membership"),
                  ),
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

        return ListView(
          shrinkWrap: true,
          children: [
            Text(title, style: headerStyle),
            const SizedBox(height: 12),
            ...paginatedDocs.map((doc) => _buildCard(doc, showButtons)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(
                  bottom: 20.0), // Extra bottom padding for safety
              child: Row(
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
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final pendingStream = FirebaseFirestore.instance
        .collection('registrations')
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots();

    final acceptedStream = FirebaseFirestore.instance
        .collection('registrations')
        .where('status', isEqualTo: 'accepted')
        .where('endDate', isGreaterThanOrEqualTo: todayStr)
        .orderBy('endDate', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: true,
        bottom:
            true, // Enabled bottom SafeArea to prevent overlap/overflow issues
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
