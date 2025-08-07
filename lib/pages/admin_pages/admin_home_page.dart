import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dashboard_page.dart';
import 'member_list_page.dart';
import 'pending_registrations_page.dart';
import 'notifications_page.dart';
import 'attendance_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;

  final List<String> _titles = [
    'Admin Dashboard',
    'Members Update',
    'Pending Registrations',
    'Announcements',
    'Attendance',
  ];

  late List<Widget> _pages;

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _pages = [
      DashboardPage(
        onNavigateToAttendance: () {
          _onItemTapped(4);
        },
      ),
      const MemberListPage(),
      const PendingRegistrationsPage(),
      const NotificationsPage(),
      const AttendancePage(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _handleMenuSelection(String value) {
    if (value == 'logout') _showLogoutDialog();
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            children: [
              const Center(
                child: Icon(Icons.logout, size: 40, color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Confirm Logout',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 10),
              const Center(child: Text("Are you sure you want to log out?")),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      child: const Text("Cancel", style: TextStyle(color: Colors.black)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      child: const Text("Logout", style: TextStyle(color: Colors.white)),
                      onPressed: _logout,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeData = ThemeData.light();

    return Theme(
      data: themeData.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(themeData.textTheme),
      ),
      child: Scaffold(
        extendBody: true,
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: SafeArea(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _titles[_selectedIndex],
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: _handleMenuSelection,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: Colors.white,
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'logout',
                        child: ListTile(
                          leading: Icon(Icons.logout, color: Colors.redAccent),
                          title: Text('Logout'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pages.length,
            itemBuilder: (_, index) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _pages[index],
            ),
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
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              backgroundColor: Colors.white,
              selectedItemColor: Colors.black,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              showSelectedLabels: true,
              showUnselectedLabels: false,
              elevation: 0,
              selectedLabelStyle: const TextStyle(fontSize: 10),
              unselectedLabelStyle: const TextStyle(fontSize: 10),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_customize_outlined),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.group_outlined),
                  label: 'Members',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.pending_actions_outlined),
                  label: 'Pending',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications_outlined),
                  label: 'Notify',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.qr_code_scanner),
                  label: 'Attendance',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
