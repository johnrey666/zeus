// ... imports
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../login/member/member_signup_page.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MemberListPage extends StatefulWidget {
  const MemberListPage({super.key});

  @override
  State<MemberListPage> createState() => _MemberListPageState();
}

class _MemberListPageState extends State<MemberListPage> {
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 0;
  final int _itemsPerPage = 10;
  List<Map<String, dynamic>> _allMembers = [];
  List<Map<String, dynamic>> _filteredMembers = [];

  @override
  void initState() {
    super.initState();
    _fetchMembers();
    _searchController.addListener(_filterSearchResults);
  }

  Future<void> _fetchMembers() async {
    final userSnapshot = await FirebaseFirestore.instance.collection('users').get();
    final allUsers = userSnapshot.docs.where((d) => d['userType'] == 'Member');

    List<Map<String, dynamic>> enrichedMembers = [];

    for (var userDoc in allUsers) {
      final userId = userDoc.id;
      final userData = userDoc.data();

      final registrationSnap = await FirebaseFirestore.instance
          .collection('registrations')
          .where('userId', isEqualTo: userId)
          .get();

      final acceptedRegs = registrationSnap.docs
          .where((doc) => doc['status'] == 'accepted')
          .toList()
        ..sort((a, b) {
          final aTime = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime(2000);
          final bTime = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });

      String statusBadge = "Member";
      String dateJoined = 'N/A';
      String? expiryDate;

      if (acceptedRegs.isNotEmpty) {
        final regData = acceptedRegs.first.data();
        dateJoined = regData['startDate'] ?? 'N/A';
        expiryDate = regData['planExpiry'];

        if (expiryDate != null) {
          final planExpiry = DateTime.tryParse(expiryDate);
          final now = DateTime.now();
          if (planExpiry != null && now.isAfter(planExpiry)) {
            statusBadge = "Inactive";
          } else {
            statusBadge = "Active";
          }
        } else {
          statusBadge = "Active";
        }
      }

      enrichedMembers.add({
        'userId': userId,
        'userData': userData,
        'badge': statusBadge,
        'dateJoined': dateJoined,
      });
    }

    setState(() {
      _allMembers = enrichedMembers;
      _filteredMembers = List.from(enrichedMembers);
    });
  }

  void _filterSearchResults() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = List.from(_allMembers);
      } else {
        _filteredMembers = _allMembers.where((member) {
          final data = member['userData'] as Map<String, dynamic>;
          final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.toLowerCase();
          return name.contains(query);
        }).toList();
      }
      _currentPage = 0;
    });
  }

  List<Map<String, dynamic>> _paginatedMembers() {
    final start = _currentPage * _itemsPerPage;
    final end = start + _itemsPerPage;
    return _filteredMembers.sublist(
      start,
      end > _filteredMembers.length ? _filteredMembers.length : end,
    );
  }

void _showQrModal(String userId) async {
  // Step 1: Load user document
  final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
  final userData = userDoc.data();

  if (userData == null || userData['memberId'] == null || userData['memberId'].toString().isEmpty) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('QR Code', style: TextStyle(color: Colors.black)),
        content: const Text("No QR code available.", style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return;
  }

  final firstName = userData['firstName'] ?? '';
  final lastName = userData['lastName'] ?? '';
  final memberId = userData['memberId'];

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('QR Code', style: TextStyle(color: Colors.black)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$firstName $lastName",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            memberId,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          QrImageView(
            data: memberId,
            version: QrVersions.auto,
            size: 200.0,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close", style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

  void _showEditModal(String userId, Map<String, dynamic> userData) {
  final firstNameController = TextEditingController(text: userData['firstName']);
  final lastNameController = TextEditingController(text: userData['lastName']);
  final dateJoinedController = TextEditingController(
      text: userData['dateJoined'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final planExpiryController = TextEditingController(
      text: userData['planExpiry'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final amountController = TextEditingController(text: userData['amount']?.toString() ?? '');

  final dateFormat = DateFormat('yyyy-MM-dd');

  Future<void> _pickDate(BuildContext context, TextEditingController controller) async {
    final initialDate = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            dialogBackgroundColor: Colors.white,
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: ButtonStyle(
                foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                  if (states.contains(MaterialState.pressed)) return Colors.green;
                  return Colors.green; // OK button color
                }),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller.text = dateFormat.format(picked);
    }
  }

  const blackInputDecoration = InputDecoration(
    labelStyle: TextStyle(color: Colors.black),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black),
    ),
  );

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.white,
      title: const Text("Edit Member Info", style: TextStyle(color: Colors.black)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstNameController,
              cursorColor: Colors.blue,
              decoration: blackInputDecoration.copyWith(labelText: "First Name"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lastNameController,
              cursorColor: Colors.blue,
              decoration: blackInputDecoration.copyWith(labelText: "Last Name"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: dateJoinedController,
              cursorColor: Colors.blue,
              readOnly: true,
              decoration: blackInputDecoration.copyWith(labelText: "Date of Joining"),
              onTap: () => _pickDate(context, dateJoinedController),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: planExpiryController,
              cursorColor: Colors.blue,
              readOnly: true,
              decoration: blackInputDecoration.copyWith(labelText: "Plan Expiry"),
              onTap: () => _pickDate(context, planExpiryController),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              cursorColor: Colors.blue,
              keyboardType: TextInputType.number,
              decoration: blackInputDecoration.copyWith(labelText: "Amount (₱)"),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.red)),
        ),
        GestureDetector(
          onTap: () async {
            if (firstNameController.text.trim().isEmpty ||
                lastNameController.text.trim().isEmpty ||
                dateJoinedController.text.trim().isEmpty ||
                planExpiryController.text.trim().isEmpty ||
                amountController.text.trim().isEmpty ||
                double.tryParse(amountController.text.trim()) == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please fill in all fields correctly.")),
              );
              return;
            }

            final String firstName = firstNameController.text.trim();
            final String lastName = lastNameController.text.trim();
            final String dateJoined = dateJoinedController.text.trim();
            final String planExpiry = planExpiryController.text.trim();
            final double amount = double.parse(amountController.text.trim());

            await FirebaseFirestore.instance.collection('users').doc(userId).update({
              'firstName': firstName,
              'lastName': lastName,
              'planExpiry': planExpiry,
              'amount': amount,
            });

            final registrationSnapshot = await FirebaseFirestore.instance
                .collection('registrations')
                .where('userId', isEqualTo: userId)
                .where('status', isEqualTo: 'accepted')
                .get();

            if (registrationSnapshot.docs.isNotEmpty) {
              final regDoc = registrationSnapshot.docs.first;
              await regDoc.reference.update({
                'startDate': dateJoined,
                'planExpiry': planExpiry,
                'amount': amount,
              });
            }

            Navigator.pop(context);
            _fetchMembers();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              "Save",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final styleName = GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                cursorColor: Colors.blue,
                decoration: InputDecoration(
                  hintText: "Search members...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MemberSignUpPage()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add, color: Colors.white),
                        SizedBox(width: 6),
                        Text('Add Member', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _filteredMembers.isEmpty
                    ? const Center(child: Text("No members found"))
                    : ListView.builder(
                        itemCount: _paginatedMembers().length,
                        itemBuilder: (context, index) {
                          final member = _paginatedMembers()[index];
                          final userId = member['userId'];
                          final data = member['userData'] as Map<String, dynamic>;
                          final name = '${data['firstName']} ${data['lastName']}';
                          final badge = member['badge'];
                          final dateJoined = member['dateJoined'];

                          Color badgeColor;
                          Color badgeTextColor;
                          switch (badge) {
                            case "Active":
                              badgeColor = Colors.green[100]!;
                              badgeTextColor = Colors.green;
                              break;
                            case "Inactive":
                              badgeColor = Colors.red[100]!;
                              badgeTextColor = Colors.red;
                              break;
                            default:
                              badgeColor = Colors.grey[300]!;
                              badgeTextColor = Colors.black87;
                          }

                          return Card(
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ExpansionTile(
                              leading: const Icon(Icons.person_outline, color: Colors.black),
                              title: Text(name, style: styleName),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: badgeColor,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            badge,
                                            style: TextStyle(fontSize: 12, color: badgeTextColor, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text("Name:", style: TextStyle(fontWeight: FontWeight.bold)),
                                                Text(name),
                                                const SizedBox(height: 10),
                                                const Text("Date of Joining:", style: TextStyle(fontWeight: FontWeight.bold)),
                                                Text(dateJoined),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text("Plan Expiry:", style: TextStyle(fontWeight: FontWeight.bold)),
                                                Text(data['planExpiry'] ?? 'N/A'),
                                                const SizedBox(height: 10),
                                                const Text("Amount:", style: TextStyle(fontWeight: FontWeight.bold)),
                                                Text('Php ${data['amount'] ?? 'N/A'}'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () => _showEditModal(userId, data),
                                            icon: const Icon(Icons.edit, color: Colors.black, size: 18),
                                            label: const Text("Edit", style: TextStyle(color: Colors.black, fontSize: 13)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              elevation: 2,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          ElevatedButton.icon(
                                            onPressed: () => _showQrModal(userId),
                                            icon: const Icon(Icons.qr_code, color: Colors.black, size: 18),
                                            label: const Text("QR Code", style: TextStyle(color: Colors.black, fontSize: 13)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              elevation: 2,
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (_filteredMembers.length > _itemsPerPage)
  Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      TextButton(
        onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
        style: TextButton.styleFrom(
          foregroundColor: Colors.blue,
        ),
        child: const Text("Previous"),
      ),
      Text("Page ${_currentPage + 1} of ${(_filteredMembers.length / _itemsPerPage).ceil()}"),
      TextButton(
        onPressed: (_currentPage + 1) * _itemsPerPage < _filteredMembers.length
            ? () => setState(() => _currentPage++)
            : null,
        style: TextButton.styleFrom(
          foregroundColor: Colors.blue,
        ),
        child: const Text("Next"),
      ),
    ],
  ),

            ],
          ),
        ),
      ),
    );
  }
}
