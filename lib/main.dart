// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: unused_import
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Add this import
import 'package:zeus/pages/admin_pages/attendance_page.dart';
import 'firebase_options.dart';
import 'package:zeus/pages/select_profile_page.dart';
import 'package:zeus/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // FCM init
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );
  print('User granted permission: ${settings.authorizationStatus}');

  String? token = await messaging.getToken();
  print('FCM Token: $token');

  // Initialize notification service
  try {
    await NotificationService().initialize();

    // Schedule daily reminders (non-blocking)
    Future.microtask(() async {
      try {
        await NotificationService().scheduleHydrationReminders();
        await NotificationService().scheduleStepsReminder();
        print('Daily reminders scheduled successfully');
      } catch (e) {
        print('Error scheduling daily reminders: $e');
      }
    });
  } catch (e) {
    print('Error initializing notifications: $e');
    // Continue app startup even if notifications fail
  }

  runApp(const ZeusLandingPage());
}

class ZeusLandingPage extends StatelessWidget {
  const ZeusLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const LandingScreen(),
      routes: {
        '/attendance_page': (context) => const AttendancePage(),
      },
    );
  }
}

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/zeus_logo.png',
                height: 250,
              ),
              const SizedBox(height: 60),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SelectProfilePage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: Color(0xFFE0E0E0),
                  elevation: 4,
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
