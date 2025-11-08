// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController _memberNameController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();

  String? _selectedPlan;
  String? _selectedPayment = 'Gcash';
  File? _proofImage;

  final List<String> _plans = [
    '1 month - 650PHP',
    '1 m w/ treadmill - 1300PHP',
    '1 month with trainer - 1650PHP',
  ];

  DateTime? _pickedStartDate;

  @override
  void initState() {
    super.initState();
    _checkAccess();
    _loadUserName();
  }

  Future<void> _checkAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check for active membership
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists && userDoc.data()?['membershipStatus'] == 'Active') {
      if (mounted) {
        _showSnackBar("🎉 You're already a member!");
        Navigator.pop(context);
      }
      return;
    }

    // Check for pending registration
    final regSnapshot = await FirebaseFirestore.instance
        .collection('registrations')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (regSnapshot.docs.isNotEmpty && mounted) {
      _showSnackBar("⏳ You already have a pending registration.");
      Navigator.pop(context);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final firstName = doc['firstName'] ?? '';
      final lastName = doc['lastName'] ?? '';
      if (mounted) {
        setState(() {
          _memberNameController.text = "$firstName $lastName";
        });
      }
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: ButtonStyle(
                foregroundColor:
                    MaterialStateProperty.resolveWith<Color>((states) {
                  if (states.contains(MaterialState.pressed))
                    return Colors.green;
                  return Colors.green;
                }),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _pickedStartDate = picked;
        _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pickProofImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _proofImage = File(picked.path);
      });
    }
  }

  Future<void> _submitRegistration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = _memberNameController.text.trim();
    final date = _startDateController.text.trim();

    if (name.isEmpty ||
        date.isEmpty ||
        _selectedPlan == null ||
        _proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please complete all fields and upload proof")),
      );
      return;
    }

    final bytes = await _proofImage!.readAsBytes();
    final base64Image = base64Encode(bytes);

    // Calculate end date (1 month after start)
    final startDate = _pickedStartDate ?? DateTime.now();
    final endDate =
        DateTime(startDate.year, startDate.month + 1, startDate.day);

    final registrationData = {
      'userId': user.uid,
      'name': name,
      'plan': _selectedPlan,
      'startDate': date,
      'endDate': DateFormat('yyyy-MM-dd').format(endDate),
      'paymentMethod': _selectedPayment,
      'proofImageBase64': base64Image,
      'status': 'pending',
      'timestamp': Timestamp.now(),
    };

    await FirebaseFirestore.instance
        .collection('registrations')
        .add(registrationData);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Registration submitted for approval.")),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.blue,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FA),
        appBar: AppBar(
          title: const Text('Membership Registration'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("Member"),
              _styledTextField(
                controller: _memberNameController,
                hint: "Enter Member Name",
                icon: Icons.person,
              ),
              const SizedBox(height: 20),
              _sectionTitle("Membership Plan"),
              LayoutBuilder(
                builder: (context, constraints) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: _styledDropdown<String>(
                      icon: Icons.credit_card,
                      value: _selectedPlan,
                      hint: "Select Plan",
                      items: _plans
                          .map((plan) => DropdownMenuItem(
                                value: plan,
                                child:
                                    Text(plan, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedPlan = value),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              _sectionTitle("Start Date"),
              TextField(
                controller: _startDateController,
                readOnly: true,
                onTap: () => _pickDate(context),
                decoration:
                    _inputDecoration(Icons.calendar_today, "Select Date"),
              ),
              const SizedBox(height: 20),
              _sectionTitle("Payment Method"),
              Row(
                children: [
                  Radio<String>(
                    value: 'Gcash',
                    groupValue: _selectedPayment,
                    activeColor: Colors.blue,
                    onChanged: (value) =>
                        setState(() => _selectedPayment = value),
                  ),
                  const Icon(Icons.account_balance_wallet, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text("Gcash"),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                "* Send payment to 09********** and upload proof.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickProofImage,
                icon: const Icon(Icons.upload_rounded),
                label: const Text("Upload GCash Receipt"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 1,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_proofImage != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_proofImage!, height: 160),
                  ),
                ),
              const SizedBox(height: 30),
              Center(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: _submitRegistration,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child:
                        const Text("Register", style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _styledDropdown<T>({
    Key? key,
    required IconData icon,
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      key: key,
      value: value,
      hint: Text(hint),
      items: items,
      onChanged: onChanged,
      decoration: _inputDecoration(icon, ''),
      borderRadius: BorderRadius.circular(12),
      isExpanded: true,
    );
  }

  Widget _styledTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: _inputDecoration(icon, hint),
      cursorColor: Colors.blue,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: Colors.black87,
        ));
  }

  InputDecoration _inputDecoration(IconData? icon, String hint) {
    return InputDecoration(
      prefixIcon: icon != null ? Icon(icon) : null,
      hintText: hint,
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
