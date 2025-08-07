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
  String? _selectedGender;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

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
        _phoneController.text = userData['phone'] ?? '';
        _ageController.text = userData['age'] ?? '';
        _selectedGender = userData['gender'];
        if ((userData['profileImagePath'] ?? '').isNotEmpty) {
          _profileImage = File(userData['profileImagePath']);
        }

        _heightController.text = userData['height'] ?? '';
        _weightController.text = userData['weight'] ?? '';
      });
    }

    if (planDoc.exists) {
      final planData = planDoc.data()!;
      setState(() {
        if (planData.containsKey('Height')) {
          _heightController.text = planData['Height'] ?? '';
        }
        if (planData.containsKey('Weight')) {
          _weightController.text = planData['Weight'] ?? '';
        }
      });
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _profileImage = File(picked.path);
      });
    }
  }

  Future<void> _saveProfile() async {
  if (user == null) return;

  final userData = {
    'firstName': _firstNameController.text.trim(),
    'lastName': _lastNameController.text.trim(),
    'phone': _phoneController.text.trim(),
    'age': _ageController.text.trim(),
    'gender': _selectedGender,
    'height': _heightController.text.trim(),
    'weight': _weightController.text.trim(),
    'profileImagePath': _profileImage?.path ?? '',
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

    // 🔹 Update workout_plans collection
    await FirebaseFirestore.instance
        .collection('workout_plans')
        .doc(userId)
        .set(planData, SetOptions(merge: true));

    _showModernSnackBar("✅ Profile updated successfully");
  } catch (e) {
    _showModernSnackBar("❌ Failed to update profile. Try again.");
    debugPrint("Error saving profile: $e");
  }
}

  Future<void> _handleSubscription() async {
    if (user == null) return;

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
                  _buildLabel("Phone Number"),
                  _buildTextField(Icons.phone, 'Phone Number', _phoneController),
                  const SizedBox(height: 16),
                  _buildLabel("Age"),
                  _buildTextField(Icons.cake, 'Age', _ageController),
                  const SizedBox(height: 16),
                  _buildLabel("Gender"),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _buildGenderOption("Male")),
                      const SizedBox(width: 0),
                      Expanded(child: _buildGenderOption("Female")),
                    ],
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
                onTap: _handleSubscription,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text("Subscribe to Plan",
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white)),
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
      cursorColor: Colors.blue, // 🔵 Blue cursor color
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

  Widget _buildGenderOption(String gender) {
  return SizedBox(
    height: 42,
    child: ChoiceChip(
      label: Text(gender, style: GoogleFonts.poppins()),
      selected: _selectedGender == gender,
      onSelected: (_) => setState(() => _selectedGender = gender),
      selectedColor: Colors.blueAccent,
      backgroundColor: Colors.grey[300],
      labelStyle: TextStyle(
        color: _selectedGender == gender ? Colors.white : Colors.black,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
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
