// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'planning_page.dart';

class HealthDeclarationPage extends StatefulWidget {
  const HealthDeclarationPage({super.key});

  @override
  State<HealthDeclarationPage> createState() => _HealthDeclarationPageState();
}

class _HealthDeclarationPageState extends State<HealthDeclarationPage> {
  final Map<String, bool> _healthConditions = {
    'Heart Disease': false,
    'High Blood Pressure': false,
    'Diabetes': false,
    'Asthma': false,
    'Joint Problems': false,
    'Back Pain': false,
    'Previous Injuries': false,
    'Pregnancy': false,
    'None': false,
  };

  final Map<String, bool> _medications = {
    'Blood Pressure Medication': false,
    'Blood Thinners': false,
    'Diabetes Medication': false,
    'Pain Medication': false,
    'None': false,
  };

  final Map<String, bool> _activityRestrictions = {
    'No Heavy Lifting': false,
    'No High Impact': false,
    'No Bending': false,
    'Limited Range of Motion': false,
    'None': false,
  };

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          'Health Declaration',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade200.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.health_and_safety,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Medical Survey',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Help us personalize your workouts safely',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Health Conditions',
              'Do you have any of the following conditions?',
              _healthConditions,
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Medications',
              'Are you currently taking any of the following medications?',
              _medications,
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Activity Restrictions',
              'Do you have any activity restrictions?',
              _activityRestrictions,
            ),
            const SizedBox(height: 40),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isLoading
                      ? [Colors.grey.shade400, Colors.grey.shade400]
                      : [const Color(0xFF9DCEFF), const Color(0xFF92A3FD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: _isLoading
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.blue.shade200.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveHealthDeclaration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Continue to Workout Planning',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        // Navigate to planning page even if skipped
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PlanningPage()),
                        );
                      },
                child: Text(
                  'Skip for now',
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    String subtitle,
    Map<String, bool> options,
  ) {
    IconData icon;
    Color iconColor;
    
    if (title == 'Health Conditions') {
      icon = Icons.favorite;
      iconColor = Colors.red.shade300;
    } else if (title == 'Medications') {
      icon = Icons.medication;
      iconColor = Colors.orange.shade300;
    } else {
      icon = Icons.warning;
      iconColor = Colors.amber.shade300;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ...options.entries.map((entry) {
          final isSelected = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                setState(() {
                  // If "None" is selected, unselect all others
                  if (entry.key == 'None') {
                    options.forEach((key, value) {
                      options[key] = false;
                    });
                    options['None'] = true;
                  } else {
                    // Unselect "None" if any other option is selected
                    options['None'] = false;
                    options[entry.key] = !isSelected;
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Colors.blue.shade300
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isSelected ? Colors.blue.shade300 : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected ? Colors.black : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
        ],
      ),
    );
  }

  Future<void> _saveHealthDeclaration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Get selected conditions (excluding "None" if other options are selected)
      final selectedConditions = _healthConditions.entries
          .where((e) => e.value && e.key != 'None')
          .map((e) => e.key)
          .toList();

      final selectedMedications = _medications.entries
          .where((e) => e.value && e.key != 'None')
          .map((e) => e.key)
          .toList();

      final selectedRestrictions = _activityRestrictions.entries
          .where((e) => e.value && e.key != 'None')
          .map((e) => e.key)
          .toList();

      final hasNoConditions = _healthConditions['None'] == true;
      final hasNoMedications = _medications['None'] == true;
      final hasNoRestrictions = _activityRestrictions['None'] == true;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'healthConditions': hasNoConditions ? [] : selectedConditions,
        'medications': hasNoMedications ? [] : selectedMedications,
        'activityRestrictions': hasNoRestrictions ? [] : selectedRestrictions,
        'healthDeclarationCompleted': true,
        'healthDeclarationUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Health information saved successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Always navigate to planning page after health declaration
        // Use pushReplacement to replace the health declaration page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PlanningPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving health information: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

