// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  String? _selectedTrainerId;
  File? _proofImage;

  final List<String> _plans = [
    '1 month - 650PHP',
    '1 m w/ trainer - 1650PHP',
    '1 m w/ treadmill - 1300PHP',
  ];

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDateController.text =
            "${picked.year}-${picked.month}-${picked.day}";
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
        _selectedTrainerId == null ||
        _proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please complete all fields and upload proof")),
      );
      return;
    }

    final bytes = await _proofImage!.readAsBytes();
    final base64Image = base64Encode(bytes);

    final registrationData = {
      'userId': user.uid,
      'name': name,
      'plan': _selectedPlan,
      'startDate': date,
      'paymentMethod': _selectedPayment,
      'trainerId': _selectedTrainerId,
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
    return Scaffold(
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
            _styledDropdown<String>(
              icon: Icons.credit_card,
              value: _selectedPlan,
              hint: "Select Plan",
              items: _plans
                  .map((plan) => DropdownMenuItem(
                        value: plan,
                        child: Text(plan),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedPlan = value),
            ),
            const SizedBox(height: 20),
            _sectionTitle("Select Trainer"),
            _buildTrainerDropdown(),
            const SizedBox(height: 20),
            _sectionTitle("Start Date"),
            TextField(
              controller: _startDateController,
              readOnly: true,
              onTap: () => _pickDate(context),
              decoration: _inputDecoration(Icons.calendar_today, "Select Date"),
            ),
            const SizedBox(height: 20),
            _sectionTitle("Payment Method"),
            Row(
              children: [
                Radio<String>(
                  value: 'Gcash',
                  groupValue: _selectedPayment,
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
              "* Send payment to 09853886411 and upload proof.",
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
                    borderRadius: BorderRadius.circular(12)),
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
              child: ElevatedButton(
                onPressed: _submitRegistration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text("Register",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainerDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'Trainer')
          .snapshots(),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final trainers = snapshot.data?.docs ?? [];

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : _styledDropdown<String>(
                  key: ValueKey(trainers.length),
                  icon: Icons.fitness_center,
                  value: _selectedTrainerId,
                  hint: "Choose Trainer",
                  items: trainers.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text("${data['firstName']} ${data['lastName']}"),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => _selectedTrainerId = value),
                ),
        );
      },
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
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87));
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
