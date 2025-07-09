import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'member_signup_page.dart';
import 'package:zeus/pages/member_pages/member_home_page.dart';

class MemberLoginPage extends StatefulWidget {
  const MemberLoginPage({super.key});

  @override
  State<MemberLoginPage> createState() => _MemberLoginPageState();
}

class _MemberLoginPageState extends State<MemberLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;

  void _loginUser() async {
    setState(() => _isLoading = true);

    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final User? user = userCredential.user;

      if (user != null) {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        // ✅ Make sure the field name is userType (case-sensitive)
        final userType = userDoc.get('userType');

        if (userType == 'Member') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MemberHomePage()),
          );
        } else {
          await _auth.signOut();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Access denied. Not a Member account.')),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4A90E2);

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
                      child: const Icon(Icons.person_outline,
                          size: 70, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Member Login',
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
              const Text("Email",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                decoration:
                    _inputDecoration(Icons.email_outlined, "Enter your email"),
              ),
              const SizedBox(height: 20),
              const Text("Password",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration:
                    _inputDecoration(Icons.lock_outline, "Enter your password"),
              ),
              const SizedBox(height: 40),
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          )
                        : const Text("Login",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MemberSignUpPage()));
                  },
                  child: const Text('Sign Up'),
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
}
