// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'registration_page.dart';

class ManageProfilePage extends StatefulWidget {
  const ManageProfilePage({super.key});

  @override
  State<ManageProfilePage> createState() => _ManageProfilePageState();
}

class _ManageProfilePageState extends State<ManageProfilePage> {
  File? _profileImage;
  String? _selectedSex;
  DateTime? _birthday;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  String? _oldHeight;
  String? _oldWeight;

  bool _isMember = false;
  String? _registrationDocId;

  final ImagePicker _picker = ImagePicker();
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    final planDoc = await FirebaseFirestore.instance
        .collection('workout_plans')
        .doc(user!.uid)
        .get();

    if (userDoc.exists) {
      final userData = userDoc.data()!;
      setState(() {
        _firstNameController.text = userData['firstName'] ?? '';
        _lastNameController.text = userData['lastName'] ?? '';
        _selectedSex = userData['sex'];
        // Load birthday - could be Timestamp or DateTime
        if (userData['birthday'] != null) {
          if (userData['birthday'] is Timestamp) {
            _birthday = (userData['birthday'] as Timestamp).toDate();
          } else if (userData['birthday'] is DateTime) {
            _birthday = userData['birthday'] as DateTime;
          }
        }
        if ((userData['profileImagePath'] ?? '').isNotEmpty) {
          _profileImage = File(userData['profileImagePath']);
        }
      });
    }

    // Load height and weight from workout_plans (planning page data)
    if (planDoc.exists) {
      final planData = planDoc.data()!;
      setState(() {
        // These come from PlanningPage
        if (planData.containsKey('Height')) {
          _heightController.text = planData['Height']?.toString() ?? '';
        }
        if (planData.containsKey('Weight')) {
          _weightController.text = planData['Weight']?.toString() ?? '';
        }
      });
    }

    // Also check if height/weight exists in user document (for backward compatibility)
    if (userDoc.exists) {
      final userData = userDoc.data()!;
      setState(() {
        // Only set if not already set from workout_plans
        if (_heightController.text.isEmpty && userData['height'] != null) {
          _heightController.text = userData['height']?.toString() ?? '';
        }
        if (_weightController.text.isEmpty && userData['weight'] != null) {
          _weightController.text = userData['weight']?.toString() ?? '';
        }
      });
    }

    // Check membership status
    bool isActive = false;
    String? regId;
    if (userDoc.exists) {
      isActive = userDoc.data()!['membershipStatus'] == 'Active';
      if (isActive) {
        final regSnapshot = await FirebaseFirestore.instance
            .collection('registrations')
            .where('userId', isEqualTo: user!.uid)
            .where('status', isEqualTo: 'accepted')
            .limit(1)
            .get();
        if (regSnapshot.docs.isNotEmpty) {
          regId = regSnapshot.docs.first.id;
        }
      }
    }

    setState(() {
      _isMember = isActive;
      _registrationDocId = regId;
    });

    // Store old values for change detection
    _oldHeight = _heightController.text.trim();
    _oldWeight = _weightController.text.trim();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _profileImage = File(picked.path);
      });
    }
  }

  int _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return 0;
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    final monthDifference = now.month - birthDate.month;
    if (monthDifference < 0 ||
        (monthDifference == 0 && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _saveProfile() async {
    if (user == null) return;

    final userData = {
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'sex': _selectedSex,
      'birthday': _birthday != null ? Timestamp.fromDate(_birthday!) : null,
      'profileImagePath': _profileImage?.path ?? '',
      // Save height/weight to user document as well for consistency
      'height': _heightController.text.trim(),
      'weight': _weightController.text.trim(),
    };

    final planData = {
      'Height': _heightController.text.trim(),
      'Weight': _weightController.text.trim(),
    };

    final userId = user!.uid;

    try {
      // 🔹 Update users collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(userData, SetOptions(merge: true));

      // 🔹 Update workout_plans collection (from planning page)
      await FirebaseFirestore.instance
          .collection('workout_plans')
          .doc(userId)
          .set(planData, SetOptions(merge: true));

      _showModernSnackBar("✅ Profile updated successfully");

      // Check if body info changed to trigger suggestions reload
      final newHeight = _heightController.text.trim();
      final newWeight = _weightController.text.trim();
      final changed = _oldHeight != newHeight || _oldWeight != newWeight;

      // Update old values
      _oldHeight = newHeight;
      _oldWeight = newWeight;

      // Pop with flag if body info changed
      Navigator.pop(context, {'reloadSuggestions': changed});
    } catch (e) {
      _showModernSnackBar("❌ Failed to update profile. Try again.");
      debugPrint("Error saving profile: $e");
    }
  }

  Future<void> _handleMembershipAction() async {
    if (user == null) return;

    if (_isMember) {
      // Show confirmation dialog for cancel
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Cancel Membership'),
            content:
                const Text('Are you sure you want to cancel your membership?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Confirm',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        await _cancelMembership();
      }
    } else {
      // Check for pending registration
      final regSnapshot = await FirebaseFirestore.instance
          .collection('registrations')
          .where('userId', isEqualTo: user!.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (regSnapshot.docs.isNotEmpty) {
        _showModernSnackBar("⏳ You already have a pending registration.");
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RegistrationPage()),
      );
    }
  }

  Future<void> _cancelMembership() async {
    if (_registrationDocId == null || user == null) return;

    try {
      // Update registration record
      await FirebaseFirestore.instance
          .collection('registrations')
          .doc(_registrationDocId!)
          .update({
        'status': 'cancelled',
        'cancelDate': Timestamp.now(),
      });

      // Update user record
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({
        'membershipStatus': 'Cancelled',
      });

      // Add notification
      await FirebaseFirestore.instance.collection('notifications').add({
        'toUserId': user!.uid,
        'text': 'Your membership has been cancelled.',
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showModernSnackBar("Membership cancelled successfully.");
      setState(() {
        _isMember = false;
        _registrationDocId = null;
      });
    } catch (e) {
      _showModernSnackBar("❌ Error cancelling membership. Try again.");
      debugPrint("Error cancelling membership: $e");
    }
  }

  void _showModernSnackBar(String message) {
    final snackBar = SnackBar(
      backgroundColor: Colors.black87,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
              child:
                  Text(message, style: const TextStyle(color: Colors.white))),
        ],
      ),
      duration: const Duration(seconds: 3),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text('Manage Profile',
            style: GoogleFonts.poppins(
                color: Colors.black87, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _saveProfile),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileImageBox(),
                  const SizedBox(height: 24),
                  _buildLabel("Name"),
                  Row(
                    children: [
                      Expanded(
                          child: _buildTextField(Icons.person, 'First Name',
                              _firstNameController)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildTextField(
                              Icons.person, 'Last Name', _lastNameController)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLabel("Age"),
                  const SizedBox(height: 6),
                  // Age display - non-editable (calculated from birthday)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cake, color: Colors.grey),
                        const SizedBox(width: 16),
                        Text(
                          _birthday != null
                              ? '${_calculateAge(_birthday)} years old'
                              : 'Not specified',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: _birthday != null
                                  ? Colors.black87
                                  : Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel("Sex"),
                  const SizedBox(height: 6),
                  // Sex display - non-editable
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, color: Colors.grey),
                        const SizedBox(width: 16),
                        Text(
                          _selectedSex ?? 'Not specified',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: _selectedSex != null
                                  ? Colors.black87
                                  : Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildLabel("Body Info"),
                  Row(
                    children: [
                      Expanded(
                          child: _buildTextField(
                              Icons.height, 'Height (cm)', _heightController)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildTextField(Icons.monitor_weight,
                              'Weight (kg)', _weightController)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: InkWell(
                onTap: _handleMembershipAction,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: _isMember
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
                          ),
                    color: _isMember ? Colors.red : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _isMember ? "Cancel Membership" : "Subscribe to Plan",
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      IconData icon, String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      cursorColor: Colors.blue,
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        hintText: hint,
        hintStyle: GoogleFonts.poppins(),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child:
          Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildProfileImageBox() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: Colors.grey[200],
              backgroundImage:
                  _profileImage != null ? FileImage(_profileImage!) : null,
              child: _profileImage == null
                  ? const Icon(Icons.person, size: 45, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 12),
            Text("Upload Profile Picture",
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
