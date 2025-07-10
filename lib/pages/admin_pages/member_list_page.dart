import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MemberListPage extends StatefulWidget {
  const MemberListPage({super.key});

  @override
  State<MemberListPage> createState() => _MemberListPageState();
}

class _MemberListPageState extends State<MemberListPage> {
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 0;
  final int _itemsPerPage = 10;
  List<QueryDocumentSnapshot> _allMembers = [];
  List<QueryDocumentSnapshot> _filteredMembers = [];
  List<QueryDocumentSnapshot> _trainers = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_filterSearchResults);
  }

  Future<void> _fetchUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();

    final docs = snapshot.docs;
    setState(() {
      _trainers = docs.where((d) => d['userType'] == 'Trainer').toList();
      _allMembers = docs.where((d) => d['userType'] == 'Member').toList();
      _filteredMembers = List.from(_allMembers);
    });
  }

  void _filterSearchResults() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = List.from(_allMembers);
      } else {
        _filteredMembers = _allMembers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
              .toLowerCase();
          return name.contains(query);
        }).toList();
      }
      _currentPage = 0;
    });
  }

  List<QueryDocumentSnapshot> _paginatedMembers() {
    final start = _currentPage * _itemsPerPage;
    final end = start + _itemsPerPage;
    return _filteredMembers.sublist(
      start,
      end > _filteredMembers.length ? _filteredMembers.length : end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final styleHeader =
        GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600);
    final styleName =
        GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500);
    final styleTime =
        GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search members...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Trainers', style: styleHeader),
              const SizedBox(height: 12),
              ..._trainers.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = '${data['firstName']} ${data['lastName']}';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.fitness_center),
                    title: Text(name, style: styleName),
                  ),
                );
              }),
              const SizedBox(height: 24),
              Text('Members', style: styleHeader),
              const SizedBox(height: 12),
              Expanded(
                child: _filteredMembers.isEmpty
                    ? const Center(child: Text("No members found"))
                    : ListView.builder(
                        itemCount: _paginatedMembers().length,
                        itemBuilder: (context, index) {
                          final doc = _paginatedMembers()[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final name =
                              '${data['firstName']} ${data['lastName']}';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ExpansionTile(
                              leading: const Icon(Icons.person_outline),
                              title: Text(name, style: styleName),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(doc.id)
                                        .collection('attendance')
                                        .orderBy('time', descending: true)
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                      if (!snapshot.hasData ||
                                          snapshot.data!.docs.isEmpty) {
                                        return const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Text('No attendance records'),
                                        );
                                      }

                                      final atDocs = snapshot.data!.docs;

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: atDocs.map((doc) {
                                          final at = doc.data()
                                              as Map<String, dynamic>;
                                          final ts = (at['time'] as Timestamp)
                                              .toDate();
                                          final formatted = DateFormat(
                                                  'MMM d, yyyy – hh:mm a')
                                              .format(ts);
                                          return ListTile(
                                            dense: true,
                                            leading: const Icon(
                                                Icons.check_circle_outline,
                                                size: 20),
                                            title: Text(formatted,
                                                style: styleTime),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (_filteredMembers.length > _itemsPerPage)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _currentPage > 0
                          ? () => setState(() => _currentPage--)
                          : null,
                      child: const Text("Previous"),
                    ),
                    Text(
                        "Page ${_currentPage + 1} of ${(_filteredMembers.length / _itemsPerPage).ceil()}"),
                    TextButton(
                      onPressed: (_currentPage + 1) * _itemsPerPage <
                              _filteredMembers.length
                          ? () => setState(() => _currentPage++)
                          : null,
                      child: const Text("Next"),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
