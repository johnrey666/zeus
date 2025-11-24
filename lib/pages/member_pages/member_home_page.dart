import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_page.dart';
import 'training_page.dart';
import 'report_page.dart';
import 'qr_page.dart';
import 'manage_profile_page.dart';
import 'member_notification_page.dart';

class MemberHomePage extends StatefulWidget {
  const MemberHomePage({super.key, required int initialTabIndex});

  @override
  State<MemberHomePage> createState() => _MemberHomePageState();
}

class _MemberHomePageState extends State<MemberHomePage>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isDarkMode = false;

  final user = FirebaseAuth.instance.currentUser;

  final List<String> _titles = ['Home', 'Training', 'Reports', 'Scanner'];
  final List<Widget> _pages = [
    HomePage(), // 🏠 New Home page
    TrainingPage(), // 🏋️ Placeholder
    ReportPage(), // 📊 Reports
    QRPage(), // 📷 QR
  ];

  late final PageController _pageController;
  late GlobalKey<HomePageState> _homeKey;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _homeKey = GlobalKey<HomePageState>();
    // Rebuild _pages with key
    _pages[0] = HomePage(key: _homeKey);
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.jumpToPage(index);
  }

  void _handleMenu(String v) async {
    if (v == 'profile') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManageProfilePage()),
      );

      if (result != null && result['reloadSuggestions'] == true) {
        // Use a small delay to ensure Firestore has updated
        await Future.delayed(const Duration(milliseconds: 1000));

        // Force reload AI suggestions in the current HomePage
        if (_homeKey.currentState != null && mounted) {
          await _homeKey.currentState!.reloadAISuggestions();
        }
      }
    } else if (v == 'logout') {
      _showLogoutDialog();
    } else if (v == 'toggle_theme') {
      setState(() => _isDarkMode = !_isDarkMode);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pop(context);
    if (mounted) Navigator.pop(context);
  }

  void _showLogoutDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: Wrap(
          children: [
            const Center(
              child: Icon(Icons.logout, size: 40, color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text('Confirm Logout',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 10),
            const Center(child: Text("Are you sure you want to log out?")),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    child: const Text("Cancel",
                        style: TextStyle(color: Colors.black)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent),
                    child: const Text("Logout",
                        style: TextStyle(color: Colors.white)),
                    onPressed: _logout,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // Handle back button press
  Future<bool> _onWillPop() async {
    // Prevent back navigation if user is logged in
    return user != null ? false : true;
  }

  @override
  Widget build(BuildContext context) {
    final themeData = _isDarkMode ? ThemeData.dark() : ThemeData.light();

    return Theme(
      data: themeData.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(themeData.textTheme),
      ),
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          extendBody: true,
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.white,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: SafeArea(
              child: Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_titles[_selectedIndex],
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    Row(children: [
                      Stack(children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none_rounded,
                              color: Colors.black87),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MemberNotificationPage(
                                    userId: user?.uid ?? ""),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('announcements')
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || user == null) {
                                return const SizedBox();
                              }

                              final newNotifications =
                                  snapshot.data!.docs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final seenBy = Map<String, dynamic>.from(
                                    data['seenBy'] ?? {});
                                final seenCount = seenBy[user!.uid] ?? 0;
                                return seenCount < 2;
                              });

                              return newNotifications.isNotEmpty
                                  ? Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  : const SizedBox();
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(width: 12),
                      PopupMenuButton<String>(
                        onSelected: _handleMenu,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        color: Colors.white,
                        icon: StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user?.uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData ||
                                snapshot.hasError ||
                                user == null) {
                              return const Icon(Icons.person,
                                  color: Colors.black, size: 24);
                            }

                            final userData =
                                snapshot.data!.data() as Map<String, dynamic>?;
                            final profileImagePath =
                                userData?['profileImagePath'] as String?;

                            return profileImagePath != null &&
                                    profileImagePath.isNotEmpty
                                ? CircleAvatar(
                                    radius: 14,
                                    backgroundImage:
                                        FileImage(File(profileImagePath)),
                                  )
                                : const Icon(Icons.person,
                                    color: Colors.black, size: 24);
                          },
                        ),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'profile',
                            child: ListTile(
                                leading: Icon(Icons.person),
                                title: Text('Profile')),
                          ),
                          const PopupMenuItem(
                            value: 'logout',
                            child: ListTile(
                                leading:
                                    Icon(Icons.logout, color: Colors.redAccent),
                                title: Text('Logout')),
                          ),
                        ],
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: _pages,
            ),
          ),
          bottomNavigationBar: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                selectedItemColor: Colors.black,
                unselectedItemColor: Colors.grey,
                showUnselectedLabels: false,
                showSelectedLabels: true,
                selectedLabelStyle: const TextStyle(fontSize: 10),
                unselectedLabelStyle: const TextStyle(fontSize: 10),
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.home_outlined), label: 'Home'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.fitness_center_outlined),
                      label: 'Train'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.bar_chart_outlined), label: 'Reports'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.qr_code_scanner), label: 'QR'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
