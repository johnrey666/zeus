import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'member_login_page.dart';
// ignore: unused_import
import 'package:zeus/pages/member_pages/planning_page.dart';
import 'package:zeus/pages/member_pages/health_declaration_page.dart';

class MemberSignUpPage extends StatefulWidget {
  const MemberSignUpPage({super.key});

  @override
  State<MemberSignUpPage> createState() => _MemberSignUpPageState();
}

class _MemberSignUpPageState extends State<MemberSignUpPage> {
  bool _isPasswordHidden = true;
  bool _isConfirmPasswordHidden = true;
  bool _isLoading = false;
  bool _isVerificationCodeSent = false;
  String? _generatedCode;
  bool _isCodeVerified = false;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String? _selectedGender;

  final Color primaryColor = const Color(0xFF4A90E2);

  // Replace with your Gmail credentials
  final String gmailUsername = 'ayaeubion@gmail.com'; // Your Gmail address
  final String gmailAppPassword =
      'nesq ezsj dqmn sunf'; // Your 16-character App Password

  String _generateRandomMemberId() {
    final rand = Random.secure();
    final number = rand.nextInt(90000000) + 10000000;
    return 'MBR$number';
  }

  String _generateVerificationCode() {
    final rand = Random();
    return (100000 + rand.nextInt(900000)).toString(); // 6-digit code
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _sendVerificationCode() async {
    final email = _emailController.text.trim();

    if (email.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showMessage("Please enter a valid email.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Check internet connection first
    final hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      setState(() {
        _isLoading = false;
      });
      _showMessage(
          "No internet connection. Please check your network and try again.");
      return;
    }

    try {
      // Generate verification code
      _generatedCode = _generateVerificationCode();

      // Set up Gmail SMTP server with timeout
      final smtpServer = gmail(gmailUsername, gmailAppPassword);

      // Create the email message
      final message = Message()
        ..from = Address(gmailUsername, 'Zeus Fitness App')
        ..recipients.add(email)
        ..subject = 'Your Verification Code'
        ..text = 'Your verification code is: $_generatedCode';

      // Send the email with timeout
      final sendReport = await send(message, smtpServer)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        throw TimeoutException(
            'Email sending timed out. Please check your internet connection.');
      });

      print('Message sent: $sendReport');

      setState(() {
        _isVerificationCodeSent = true;
        _isLoading = false; // Reset loading state on success
      });
      _showMessage(
          "Verification code sent to $email. Please check your inbox or spam folder.");
    } on SocketException catch (e) {
      _showMessage(
          "Network error: Unable to connect to email server. Please check your internet connection and try again.");
      print('SocketException: $e');
    } on TimeoutException catch (e) {
      _showMessage(
          "Request timed out. Please check your internet connection and try again.");
      print('TimeoutException: $e');
    } on MailerException catch (e) {
      _showMessage("Failed to send verification code: ${e.message}");
      print('MailerException: $e');
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('failed host lookup') ||
          errorMsg.contains('No address associated with hostname')) {
        _showMessage(
            "Network error: Cannot reach email server. Please check your internet connection. If using an emulator, ensure it has network access.");
      } else {
        _showMessage("Error sending verification code: ${e.toString()}");
      }
      print('Error: $e');
    } finally {
      // Always reset loading state
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _verifyCode() {
    final enteredCode = _codeController.text.trim();
    if (enteredCode.isEmpty) {
      _showMessage("Please enter the verification code.");
      return;
    }

    if (enteredCode == _generatedCode) {
      setState(() {
        _isCodeVerified = true;
      });
      _showMessage("Code verified successfully!");
    } else {
      _showMessage("Invalid verification code.");
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showWelcomeBanner() {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 20,
        right: 20,
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.celebration, color: Colors.blue, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Welcome!",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Account created successfully. Let’s personalize your workout.",
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () => entry.remove());
  }

  void _signUp() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (!_isCodeVerified) {
      _showMessage("Please verify the code first.");
      return;
    }

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        _ageController.text.trim().isEmpty ||
        _selectedGender == null) {
      _showMessage("All fields are required, including age and gender.");
      return;
    }

    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 13 || age > 120) {
      _showMessage("Please enter a valid age (13-120).");
      return;
    }

    if (password != confirmPassword) {
      _showMessage("Passwords do not match.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create user in Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;

      if (user != null) {
        final generatedMemberId = _generateRandomMemberId();
        final qrCodeValue = 'member:${user.uid}:$generatedMemberId';

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'userType': 'Member',
          'memberId': generatedMemberId,
          'age': age,
          'gender': _selectedGender,
          'createdAt': FieldValue.serverTimestamp(),
          'qrCode': qrCodeValue,
        });

        _showWelcomeBanner();
        await Future.delayed(const Duration(milliseconds: 1000));

        // Navigate to health declaration first, then planning
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const HealthDeclarationPage(),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? "An error occurred.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isSignUpButtonEnabled() {
    return _firstNameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _ageController.text.trim().isNotEmpty &&
        _selectedGender != null &&
        _isCodeVerified;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 30),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade200,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person_add,
                          size: 70, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Member Sign Up',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstNameController,
                      cursorColor: Colors.blue,
                      decoration: _inputDecoration(Icons.person, "First Name"),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _lastNameController,
                      cursorColor: Colors.blue,
                      decoration: _inputDecoration(Icons.person, "Last Name"),
                      onChanged: (_) => setState({} as VoidCallback),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      cursorColor: Colors.blue,
                      decoration:
                          _inputDecoration(Icons.email_outlined, "Email"),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 100,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendVerificationCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
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
                          : const Text(
                              "Send Code",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                            ),
                    ),
                  ),
                ],
              ),
              if (_isVerificationCodeSent) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        cursorColor: Colors.blue,
                        decoration: _inputDecoration(
                            Icons.vpn_key, "Enter Verification Code"),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 100,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Verify",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _isCodeVerified
                        ? "Code verified successfully!"
                        : "Please enter the 6-digit code sent to your email.",
                    style: TextStyle(
                      color:
                          _isCodeVerified ? Colors.green : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      cursorColor: Colors.blue,
                      decoration: _inputDecoration(Icons.calendar_today, "Age"),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: _inputDecoration(Icons.person, "Gender"),
                      items: ['Male', 'Female', 'Other'].map((String gender) {
                        return DropdownMenuItem<String>(
                          value: gender,
                          child: Text(gender),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          _selectedGender = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: _isPasswordHidden,
                cursorColor: Colors.blue,
                decoration: _passwordDecoration(
                  Icons.lock_outline,
                  "Create password",
                  _isPasswordHidden,
                  () {
                    setState(() {
                      _isPasswordHidden = !_isPasswordHidden;
                    });
                  },
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _isConfirmPasswordHidden,
                cursorColor: Colors.blue,
                decoration: _passwordDecoration(
                  Icons.lock_outline,
                  "Confirm password",
                  _isConfirmPasswordHidden,
                  () {
                    setState(() {
                      _isConfirmPasswordHidden = !_isConfirmPasswordHidden;
                    });
                  },
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 40),
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _isLoading || !_isSignUpButtonEnabled()
                        ? null
                        : _signUp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isSignUpButtonEnabled()
                              ? [
                                  const Color(0xFF9DCEFF),
                                  const Color(0xFF92A3FD)
                                ]
                              : [Colors.grey.shade400, Colors.grey.shade400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(2, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Sign Up",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Wrap(
                  children: [
                    const Text(
                      "Already have an account? ",
                      style: TextStyle(color: Colors.black),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MemberLoginPage()),
                        );
                      },
                      child: const Text(
                        "Login",
                        style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(IconData icon, String hint) {
    return InputDecoration(
      prefixIcon: Icon(icon),
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  InputDecoration _passwordDecoration(
    IconData icon,
    String hint,
    bool isHidden,
    VoidCallback toggleVisibility,
  ) {
    return InputDecoration(
      prefixIcon: Icon(icon),
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      suffixIcon: IconButton(
        icon: Icon(
          isHidden ? Icons.visibility_off : Icons.visibility,
          color: Colors.grey,
        ),
        onPressed: toggleVisibility,
      ),
    );
  }
}
