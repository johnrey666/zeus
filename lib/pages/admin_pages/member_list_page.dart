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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
    _searchController.addListener(_filterSearchResults);
  }

  Future<void> _fetchMembers() async {
    setState(() => _isLoading = true);
    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'Member')
          .get();
      final allUsers =
          userSnapshot.docs.map((d) => {'id': d.id, 'data': d.data()}).toList();

      final regSnapshot = await FirebaseFirestore.instance
          .collection('registrations')
          .where('status', isEqualTo: 'accepted')
          .get();

      final regMap = <String, Map<String, dynamic>>{};
      for (var regDoc in regSnapshot.docs) {
        final regData = regDoc.data();
        final userId = regData['userId'] as String;
        final currentTimestamp = regData['timestamp'] as Timestamp?;

        if (regMap.containsKey(userId)) {
          final existingTimestamp = regMap[userId]!['timestamp'] as Timestamp?;
          if (currentTimestamp != null &&
              (existingTimestamp == null ||
                  currentTimestamp
                      .toDate()
                      .isAfter(existingTimestamp.toDate()))) {
            regMap[userId] = regData;
          }
        } else {
          regMap[userId] = regData;
        }
      }

      List<Map<String, dynamic>> enrichedMembers = [];

      for (var user in allUsers) {
        final userId = user['id'] as String;
        final userData = user['data'] as Map<String, dynamic>;
        final regData = regMap[userId];

        String statusBadge = "Member";
        String dateJoined = userData['startDate'] ?? 'Not Registered';
        String? endDate;
        double? amount;

        if (regData != null) {
          dateJoined = regData['startDate'] ?? dateJoined;
          endDate = regData['endDate'];
          amount = (regData['amount'] as num?)?.toDouble() ??
              userData['amount']?.toDouble();

          if (endDate != null) {
            final endDateParsed = DateTime.tryParse(endDate);
            final now = DateTime.now();
            if (endDateParsed != null && now.isAfter(endDateParsed)) {
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
          'data': {
            ...userData,
            'startDate': dateJoined,
            'endDate': endDate,
            'amount': amount,
          },
          'badge': statusBadge,
        });
      }

      if (mounted) {
        setState(() {
          _allMembers = enrichedMembers;
          _filteredMembers = List.from(enrichedMembers);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      // Optionally show error snackbar
    }
  }

  void _filterSearchResults() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = List.from(_allMembers);
      } else {
        _filteredMembers = _allMembers.where((member) {
          final data = member['data'] as Map<String, dynamic>;
          final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
              .toLowerCase();
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
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final userData = userDoc.data();

    if (userData == null ||
        userData['memberId'] == null ||
        userData['memberId'].toString().isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('QR Code', style: TextStyle(color: Colors.black)),
          content: const Text("No QR code available.",
              style: TextStyle(color: Colors.black)),
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

  Future<void> _deleteMember(String userId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title:
            const Text('Delete Member?', style: TextStyle(color: Colors.black)),
        content: const Text(
            'This will permanently delete the member and their registration records.',
            style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.blue)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .delete();
                final regSnapshot = await FirebaseFirestore.instance
                    .collection('registrations')
                    .where('userId', isEqualTo: userId)
                    .where('status', isEqualTo: 'accepted')
                    .get();
                for (var regDoc in regSnapshot.docs) {
                  await regDoc.reference.delete();
                }
                _fetchMembers();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Member deleted successfully.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting member: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditModal(String userId, Map<String, dynamic> userData) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final nowFormatted = dateFormat.format(DateTime.now());

    final firstNameController =
        TextEditingController(text: userData['firstName'] ?? '');
    final lastNameController =
        TextEditingController(text: userData['lastName'] ?? '');
    final startDateController = TextEditingController(
      text: (userData['startDate'] ?? 'Not Registered') == 'Not Registered'
          ? nowFormatted
          : userData['startDate'] ?? nowFormatted,
    );
    final endDateController = TextEditingController(
      text: (userData['endDate'] ?? 'Not Registered') == 'Not Registered'
          ? nowFormatted
          : userData['endDate'] ?? nowFormatted,
    );
    final amountController =
        TextEditingController(text: userData['amount']?.toString() ?? '');

    Future<void> _pickDate(
        BuildContext context, TextEditingController controller) async {
      final initialDateStr = controller.text;
      DateTime initialDate = DateTime.now();
      if (initialDateStr != 'Not Registered' && initialDateStr.isNotEmpty) {
        final parsed = DateTime.tryParse(initialDateStr);
        if (parsed != null) initialDate = parsed;
      }
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
                  foregroundColor:
                      MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.pressed))
                      return Colors.green;
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
        title: const Text("Edit Member Info",
            style: TextStyle(color: Colors.black)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                cursorColor: Colors.blue,
                decoration:
                    blackInputDecoration.copyWith(labelText: "First Name"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: lastNameController,
                cursorColor: Colors.blue,
                decoration:
                    blackInputDecoration.copyWith(labelText: "Last Name"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: startDateController,
                cursorColor: Colors.blue,
                readOnly: true,
                decoration:
                    blackInputDecoration.copyWith(labelText: "Date of Joining"),
                onTap: () => _pickDate(context, startDateController),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: endDateController,
                cursorColor: Colors.blue,
                readOnly: true,
                decoration:
                    blackInputDecoration.copyWith(labelText: "Plan Expiry"),
                onTap: () => _pickDate(context, endDateController),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                cursorColor: Colors.blue,
                keyboardType: TextInputType.number,
                decoration:
                    blackInputDecoration.copyWith(labelText: "Amount (₱)"),
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
                  startDateController.text.trim().isEmpty ||
                  endDateController.text.trim().isEmpty ||
                  amountController.text.trim().isEmpty ||
                  double.tryParse(amountController.text.trim()) == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Please fill in all fields correctly.")),
                );
                return;
              }

              final String firstName = firstNameController.text.trim();
              final String lastName = lastNameController.text.trim();
              final String startDate = startDateController.text.trim();
              final String endDate = endDateController.text.trim();
              final double amount = double.parse(amountController.text.trim());

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .update({
                'firstName': firstName,
                'lastName': lastName,
                'endDate': endDate,
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
                  'startDate': startDate,
                  'endDate': endDate,
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
    final styleName =
        GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500);

    return Scaffold(
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
      body: SafeArea(
        top: true,
        bottom: false,
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                      MaterialPageRoute(
                          builder: (context) => const MemberSignUpPage()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
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
                        Text('Add Member',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredMembers.isEmpty
                        ? const Center(child: Text("No members found"))
                        : ListView.builder(
                            itemCount: _paginatedMembers().length,
                            itemBuilder: (context, index) {
                              final member = _paginatedMembers()[index];
                              final userId = member['userId'];
                              final data =
                                  member['data'] as Map<String, dynamic>;
                              final name =
                                  '${data['firstName']} ${data['lastName']}';
                              final badge = member['badge'];

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
                                  leading: const Icon(Icons.person_outline,
                                      color: Colors.black),
                                  title: Text(name, style: styleName),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: badgeColor,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                badge,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: badgeTextColor,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text("Name:",
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                    Text(name),
                                                    const SizedBox(height: 10),
                                                    const Text(
                                                        "Date of Joining:",
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                    Text(data['startDate'] ??
                                                        'Not Registered'),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text("Plan Expiry:",
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                    Text(data['endDate'] ??
                                                        'Not Registered'),
                                                    const SizedBox(height: 10),
                                                    const Text("Amount:",
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                    Text(
                                                      data['amount'] != null &&
                                                              data['amount']
                                                                  is num
                                                          ? 'P${(data['amount'] as num).toStringAsFixed(0)}'
                                                          : 'Not Registered',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: () => _showEditModal(
                                                    userId, data),
                                                icon: const Icon(Icons.edit,
                                                    color: Colors.black,
                                                    size: 18),
                                                label: const Text("Edit",
                                                    style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 13)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8)),
                                                  elevation: 2,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              ElevatedButton.icon(
                                                onPressed: () =>
                                                    _showQrModal(userId),
                                                icon: const Icon(Icons.qr_code,
                                                    color: Colors.black,
                                                    size: 18),
                                                label: const Text("QR Code",
                                                    style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 13)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8)),
                                                  elevation: 2,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    _deleteMember(userId),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8)),
                                                  elevation: 2,
                                                ),
                                                child: const Icon(Icons.delete,
                                                    color: Colors.red,
                                                    size: 18),
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
              if (!_isLoading && _filteredMembers.length > _itemsPerPage)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _currentPage > 0
                          ? () => setState(() => _currentPage--)
                          : null,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                      child: const Text("Previous"),
                    ),
                    Text(
                        "Page ${_currentPage + 1} of ${(_filteredMembers.length / _itemsPerPage).ceil()}"),
                    TextButton(
                      onPressed: (_currentPage + 1) * _itemsPerPage <
                              _filteredMembers.length
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
