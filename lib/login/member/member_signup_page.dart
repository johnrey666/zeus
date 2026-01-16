import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'member_login_page.dart';
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
  final TextEditingController _birthdayController = TextEditingController();

  DateTime? _selectedBirthday;
  String? _selectedSex;

  final Color primaryColor = const Color(0xFF4A90E2);

  // Replace with your Gmail credentials
  final String gmailUsername = 'ayaeubion@gmail.com';
  final String gmailAppPassword = 'nesq ezsj dqmn sunf';

  String _generateRandomMemberId() {
    final rand = Random.secure();
    final number = rand.nextInt(90000000) + 10000000;
    return 'MBR$number';
  }

  String _generateVerificationCode() {
    final rand = Random();
    return (100000 + rand.nextInt(900000)).toString();
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
      _generatedCode = _generateVerificationCode();
      final smtpServer = gmail(gmailUsername, gmailAppPassword);
      final message = Message()
        ..from = Address(gmailUsername, 'Zeus Fitness App')
        ..recipients.add(email)
        ..subject = 'Your Verification Code'
        ..text = 'Your verification code is: $_generatedCode';

      final sendReport = await send(message, smtpServer)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        throw TimeoutException(
            'Email sending timed out. Please check your internet connection.');
      });

      print('Message sent: $sendReport');
      setState(() {
        _isVerificationCodeSent = true;
        _isLoading = false;
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
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Account created successfully. Let's personalize your workout.",
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

  Future<void> _selectBirthday(BuildContext context) async {
    // FIX 1: Hide keyboard before opening date picker
    FocusScope.of(context).unfocus();

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4A90E2),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: screenHeight * 0.7,
                maxWidth: screenWidth * 0.9,
              ),
              child: child,
            ),
          ),
        );
      },
    );

    if (picked != null && picked != _selectedBirthday) {
      setState(() {
        _selectedBirthday = picked;
        _birthdayController.text =
            '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    final monthDifference = now.month - birthDate.month;
    if (monthDifference < 0 ||
        (monthDifference == 0 && now.day < birthDate.day)) {
      age--;
    }
    return age;
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
        _selectedBirthday == null ||
        _selectedSex == null) {
      _showMessage("All fields are required, including birthday and sex.");
      return;
    }

    final age = _calculateAge(_selectedBirthday!);
    if (age < 13 || age > 120) {
      _showMessage("You must be between 13 and 120 years old to sign up.");
      return;
    }

    if (password != confirmPassword) {
      _showMessage("Passwords do not match.");
      return;
    }

    setState(() => _isLoading = true);

    try {
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
          'birthday': _selectedBirthday != null
              ? Timestamp.fromDate(_selectedBirthday!)
              : null,
          'age': age,
          'sex': _selectedSex,
          'createdAt': FieldValue.serverTimestamp(),
          'qrCode': qrCodeValue,
        });

        _showWelcomeBanner();
        await Future.delayed(const Duration(milliseconds: 1000));

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
        _selectedBirthday != null &&
        _selectedSex != null &&
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
    _birthdayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    double responsiveButtonWidth() {
      if (screenWidth < 340) return 90;
      if (screenWidth < 380) return 100;
      if (screenWidth < 420) return 110;
      return 120;
    }

    double responsiveHorizontalPadding() {
      if (screenWidth < 340) return 20;
      if (screenWidth < 380) return 24;
      return 28;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: responsiveHorizontalPadding(),
              vertical: 20,
            ),
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
                          fontSize: isSmallScreen ? 20 : 22,
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
                        decoration:
                            _inputDecoration(Icons.person, "First Name"),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 10),
                    Expanded(
                      child: TextField(
                        controller: _lastNameController,
                        cursorColor: Colors.blue,
                        decoration: _inputDecoration(Icons.person, "Last Name"),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        cursorColor: Colors.blue,
                        decoration:
                            _inputDecoration(Icons.email_outlined, "Email"),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 10),
                    SizedBox(
                      width: responsiveButtonWidth(),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendVerificationCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 8 : 12,
                            vertical: 14,
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
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  "Send Code",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSmallScreen ? 11 : 12,
                                  ),
                                ),
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
                        flex: 2,
                        child: TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          cursorColor: Colors.blue,
                          decoration: _inputDecoration(
                              Icons.vpn_key, "Enter Verification Code"),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 8 : 10),
                      SizedBox(
                        width: responsiveButtonWidth(),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 8 : 12,
                              vertical: 14,
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Verify",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 11 : 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                    ),
                    child: Text(
                      _isCodeVerified
                          ? "Code verified successfully!"
                          : "Please enter the 6-digit code sent to your email.",
                      style: TextStyle(
                        color: _isCodeVerified
                            ? Colors.green
                            : Colors.grey.shade600,
                        fontSize: isSmallScreen ? 11 : 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectBirthday(context),
                        child: AbsorbPointer(
                          child: TextField(
                            readOnly: true,
                            controller: _birthdayController,
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                Icons.calendar_today,
                                color: _selectedBirthday != null
                                    ? primaryColor
                                    : Colors.grey.shade600,
                                size: 20,
                              ),
                              hintText: 'Birthday',
                              hintStyle: TextStyle(
                                fontSize: isSmallScreen ? 14 : 15,
                                color: Colors.grey.shade600,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: isSmallScreen ? 12 : 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: _selectedBirthday != null
                                    ? BorderSide(
                                        color: primaryColor.withOpacity(0.3),
                                        width: 1.5,
                                      )
                                    : BorderSide.none,
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: _selectedBirthday != null
                                    ? BorderSide(
                                        color: primaryColor.withOpacity(0.3),
                                        width: 1.5,
                                      )
                                    : BorderSide.none,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 15,
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedSex != null
                                ? primaryColor.withOpacity(0.3)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSex,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: _selectedSex != null
                                  ? primaryColor
                                  : Colors.grey.shade600,
                              size: 24,
                            ),
                            hint: Text(
                              'Sex',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: isSmallScreen ? 14 : 15,
                              ),
                            ),
                            items:
                                ['Male', 'Female', 'Other'].map((String sex) {
                              return DropdownMenuItem<String>(
                                value: sex,
                                child: Text(
                                  sex,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 15,
                                    color: Colors.black,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? value) {
                              setState(() {
                                _selectedSex = value;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_selectedBirthday != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                    ),
                    child: Text(
                      'Age: ${_calculateAge(_selectedBirthday!)} years old',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: isSmallScreen ? 12 : 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
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
                            : Text(
                                "Sign Up",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: isSmallScreen ? 15 : 16,
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
                      Text(
                        "Already have an account? ",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: isSmallScreen ? 13 : 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const MemberLoginPage()),
                          );
                        },
                        child: Text(
                          "Login",
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                            fontSize: isSmallScreen ? 13 : 14,
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
      ),
    );
  }

  InputDecoration _inputDecoration(IconData icon, String hint) {
    return InputDecoration(
      prefixIcon: Icon(icon),
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 1.5),
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
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 1.5),
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
