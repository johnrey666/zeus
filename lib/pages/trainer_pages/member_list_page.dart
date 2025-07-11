import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Member {
  final String name;
  final String mobile;
  final String weightHeight;
  final String id;
  final int age;

  Member({
    required this.name,
    required this.mobile,
    required this.weightHeight,
    required this.id,
    required this.age,
  });
}

class MemberListPage extends StatefulWidget {
  const MemberListPage({super.key});

  @override
  State<MemberListPage> createState() => _MemberListPageState();
}

class _MemberListPageState extends State<MemberListPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Member> _members = [];
  List<bool> _expandedList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final trainerId = currentUser.uid;

    try {
      // Get userIds who registered under this trainer
      final regSnapshot = await FirebaseFirestore.instance
          .collection('registrations')
          .where('trainerId', isEqualTo: trainerId)
          .where('status', isEqualTo: 'accepted') // optional filter
          .get();

      final userIds = regSnapshot.docs.map((doc) => doc['userId'] as String).toList();

      // Fetch user profiles
      final List<Member> loadedMembers = [];

      for (final userId in userIds) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          final member = Member(
            name: "${data['firstName']} ${data['lastName']}",
            mobile: data['phone'] ?? '',
            weightHeight: "${data['weight']}kg/${data['height']}cm",
            id: data['memberId'] ?? '',
            age: int.tryParse(data['age'] ?? '0') ?? 0,
          );
          loadedMembers.add(member);
        }
      }

      setState(() {
        _members = loadedMembers;
        _expandedList = List.generate(_members.length, (_) => false);
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading members: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _searchController,
                      cursorColor: Colors.blue,
                      decoration: const InputDecoration(
                        hintText: 'Search members',
                        border: InputBorder.none,
                        suffixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final isExpanded = _expandedList[index];

                        // Filter by search
                        final search = _searchController.text.toLowerCase();
                        if (search.isNotEmpty &&
                            !member.name.toLowerCase().contains(search)) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          children: [
                            Card(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 2,
                              child: ListTile(
                                title: Text(member.name),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _expandedList[index] =
                                              !_expandedList[index];
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded)
                              Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.white,
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Mobile No.',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                        Text(member.mobile),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'ID',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                        Text(member.id),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Weight/Height',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                        Text(member.weightHeight),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Age',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                        Text(member.age.toString()),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
