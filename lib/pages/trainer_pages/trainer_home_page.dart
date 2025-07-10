import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Dummy pages (replace with actual implementations)
import 'dashboard_page.dart';
import 'member_list_page.dart';
import 'session_calendar_page.dart';
import 'trainer_workout_plan_page.dart';
import 'message_page.dart';

class TrainerHomePage extends StatefulWidget {
  const TrainerHomePage({super.key});

  @override
  State<TrainerHomePage> createState() => _TrainerHomePageState();
}

class _TrainerHomePageState extends State<TrainerHomePage>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isDarkMode = false;

  final List<String> _titles = [
    'Dashboard',
    'Member List',
    'Sessions',
    'Workout Plans',
    'Messages',
  ];

  final List<Widget> _pages = const [
    DashboardPage(),
    MemberListPage(),
    SessionCalendarPage(),
    TrainerWorkoutPlanPage(),
    TrainerMessagePage(),
  ];

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'profile':
        // TODO: Navigate to trainer profile page
        break;
      case 'toggle_theme':
        setState(() {
          _isDarkMode = !_isDarkMode;
        });
        break;
      case 'logout':
        _showLogoutDialog();
        break;
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pop(context); // Close dialog
    if (mounted) Navigator.pop(context); // Go back
  }

  void _showLogoutDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
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
                    child: const Text("Cancel"),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    child: const Text("Logout"),
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

  @override
  Widget build(BuildContext context) {
    final themeData = _isDarkMode ? ThemeData.dark() : ThemeData.light();

    return Theme(
      data: themeData.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(themeData.textTheme),
      ),
      child: Scaffold(
        extendBody: true,
        resizeToAvoidBottomInset: false,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _titles[_selectedIndex],
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_none_rounded),
                            onPressed: () {
                              // TODO: navigate to trainer notifications
                            },
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      PopupMenuButton<String>(
                        onSelected: _handleMenuSelection,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        icon: const CircleAvatar(
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'profile',
                            child: ListTile(
                              leading: Icon(Icons.person),
                              title: Text('Profile'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle_theme',
                            child: ListTile(
                              leading: Icon(_isDarkMode
                                  ? Icons.light_mode
                                  : Icons.dark_mode),
                              title: Text(
                                  _isDarkMode ? 'Light Mode' : 'Dark Mode'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'logout',
                            child: ListTile(
                              leading:
                                  Icon(Icons.logout, color: Colors.redAccent),
                              title: Text('Logout'),
                            ),
                          ),
                        ],
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
            color: themeData.cardColor,
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
              backgroundColor: themeData.cardColor,
              selectedItemColor: themeData.colorScheme.primary,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              showSelectedLabels: true,
              showUnselectedLabels: false,
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.group_outlined),
                  label: 'Members',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today_outlined),
                  label: 'Sessions',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.fitness_center),
                  label: 'Plans',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline),
                  label: 'Messages',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
