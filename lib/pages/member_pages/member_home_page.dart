// ... other imports
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'training_page.dart';
import 'report_page.dart';
import 'qr_page.dart';
import 'message_page.dart';
import 'manage_profile_page.dart';
import 'member_notification_page.dart';

class MemberHomePage extends StatefulWidget {
  const MemberHomePage({super.key});

  @override
  State<MemberHomePage> createState() => _MemberHomePageState();
}

class _MemberHomePageState extends State<MemberHomePage>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isDarkMode = false;
  OverlayEntry? _notifOverlay;
  final GlobalKey _notifKey = GlobalKey();

  final List<String> _titles = ['Training', 'Reports', 'Scan QR', 'Messages'];
  final List<Widget> _pages = const [
    TrainingPage(),
    ReportPage(),
    QRPage(),
    MessagePage(),
  ];
  late final PageController _pageController;
  final user = FirebaseAuth.instance.currentUser;

  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeInOut));
  }

  void _onItemTapped(int i) {
    setState(() => _selectedIndex = i);
    _pageController.jumpToPage(i);
  }

  void _handleMenu(String v) {
    if (v == 'profile') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ManageProfilePage()));
    } else if (v == 'logout') {
      _showLogoutDialog();
    } else if (v == 'toggle_theme') {
      setState(() => _isDarkMode = !_isDarkMode);
    }
  }

  void _showLogoutDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => Wrap(children: [
        const SizedBox(height: 20),
        const Icon(Icons.logout, size: 40, color: Colors.redAccent),
        const SizedBox(height: 16),
        const Text('Confirm Logout',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        const Text("Are you sure you want to log out?"),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"))),
          const SizedBox(width: 10),
          Expanded(
              child: ElevatedButton(
                  onPressed: () {
                    FirebaseAuth.instance.signOut().then((_) {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    });
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                  child: const Text("Logout"))),
        ]),
        const SizedBox(height: 20),
      ]),
    );
  }

  void _toggleNotifications() {
    if (_notifOverlay != null) {
      _notifOverlay!.remove();
      _notifOverlay = null;
      return;
    }

    final renderBox =
        _notifKey.currentContext?.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = renderBox?.size ?? const Size(40, 40);
    _animController.forward(from: 0);

    _notifOverlay = OverlayEntry(builder: (_) {
      return Positioned(
        top: offset.dy + size.height + 8,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                width: 300,
                constraints: const BoxConstraints(maxHeight: 400),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                ),
                child: NotificationDropdown(userId: user?.uid ?? ""),
              ),
            ),
          ),
        ),
      );
    });

    Overlay.of(context).insert(_notifOverlay!);
  }

  @override
  void dispose() {
    _notifOverlay?.remove();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeData = _isDarkMode ? ThemeData.dark() : ThemeData.light();

    return Theme(
      data: themeData.copyWith(
          textTheme: GoogleFonts.poppinsTextTheme(themeData.textTheme)),
      child: Scaffold(
        extendBody: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: SafeArea(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_titles[_selectedIndex],
                      style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.white : Colors.black87)),
                  Row(children: [
                    Stack(children: [
                      IconButton(
                        key: _notifKey,
                        icon: const Icon(Icons.notifications_none_rounded),
                        onPressed: _toggleNotifications,
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('notifications')
                              .where('toUserId', isEqualTo: user?.uid)
                              .snapshots(),
                          builder: (__, snapshot) {
                            final count = snapshot.data?.docs.length ?? 0;
                            return count > 0
                                ? Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle))
                                : const SizedBox();
                          },
                        ),
                      ),
                    ]),
                    const SizedBox(width: 12),
                    PopupMenuButton<String>(
                      onSelected: _handleMenu,
                      icon: const CircleAvatar(
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.person, color: Colors.white)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'profile',
                          child: ListTile(
                              leading: Icon(Icons.person),
                              title: Text('Profile')),
                        ),
                        PopupMenuItem(
                          value: 'toggle_theme',
                          child: ListTile(
                              leading: Icon(_isDarkMode
                                  ? Icons.light_mode
                                  : Icons.dark_mode),
                              title: Text(
                                  _isDarkMode ? 'Light Mode' : 'Dark Mode')),
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
              children: _pages),
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
                    offset: const Offset(0, 4))
              ]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                type: BottomNavigationBarType.fixed,
                backgroundColor: themeData.cardColor,
                selectedItemColor: themeData.colorScheme.primary,
                unselectedItemColor: Colors.grey,
                showUnselectedLabels: false,
                showSelectedLabels: true,
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.fitness_center_outlined),
                      label: 'Train'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.bar_chart_outlined), label: 'Reports'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.qr_code_scanner), label: 'QR'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.message_outlined), label: 'Chat'),
                ]),
          ),
        ),
      ),
    );
  }
}

class NotificationDropdown extends StatelessWidget {
  final String userId;
  const NotificationDropdown({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: userId)
          .snapshots(), // <-- REMOVED .orderBy()
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 100, child: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error loading notifications: ${snapshot.error}'),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        print('Notification count: ${docs.length}');

        if (docs.isEmpty) {
          return const SizedBox(
              height: 60, child: Center(child: Text("No Notifications")));
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final text = data['text'] ?? '';
              final ts = data['timestamp'] as Timestamp?;
              final timeStr = ts != null
                  ? DateFormat('MMM d, h:mm a').format(ts.toDate())
                  : '';
              return ListTile(
                title: Text(text, style: GoogleFonts.poppins(fontSize: 14)),
                subtitle: Text(timeStr,
                    style:
                        GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                trailing: const Icon(Icons.notifications),
              );
            }),
            TextButton(
              onPressed: () {
                for (var doc in docs) {
                  FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(doc.id)
                      .delete();
                }
              },
              child: Text("Clear All", style: GoogleFonts.poppins()),
            )
          ],
        );
      },
    );
  }
}
