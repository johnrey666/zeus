import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchMembers();
    _searchController.addListener(_filterSearchResults);
  }

  Future<void> _fetchMembers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    final docs = snapshot.docs;
    setState(() {
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
          final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.toLowerCase();
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
    final styleName = GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                cursorColor: Colors.blue,
                decoration: InputDecoration(
                  hintText: "Search members...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
  onTap: () {
    // Navigation logic
  },
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD) ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.add, color: Colors.white),
        SizedBox(width: 6),
        Text(
          'Add Member',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  ),
),

              ),
              const SizedBox(height: 12),
              Expanded(
                child: _filteredMembers.isEmpty
                    ? const Center(child: Text("No members found"))
                    : ListView.builder(
                        itemCount: _paginatedMembers().length,
                        itemBuilder: (context, index) {
                          final doc = _paginatedMembers()[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final name = '${data['firstName']} ${data['lastName']}';

                          return Card(
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                dividerColor: Colors.transparent,
                                iconTheme: const IconThemeData(color: Colors.black),
                              ),
                              child: ExpansionTile(
                                leading: const Icon(Icons.person_outline, color: Colors.black),
                                title: Text(name, style: styleName),
                                backgroundColor: Colors.white,
                                collapsedBackgroundColor: Colors.white,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green[100],
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: const Text(
                                              'Active',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.green,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text("Name:", style: TextStyle(fontWeight: FontWeight.bold)),
                                                  Text(name),
                                                  const SizedBox(height: 10),
                                                  const Text("Date of Joining:", style: TextStyle(fontWeight: FontWeight.bold)),
                                                  Text(data['dateJoined'] ?? 'N/A'),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text("Plan Expiry:", style: TextStyle(fontWeight: FontWeight.bold)),
                                                  Text(data['planExpiry'] ?? 'N/A'),
                                                  const SizedBox(height: 10),
                                                  const Text("Amount:", style: TextStyle(fontWeight: FontWeight.bold)),
                                                  Text('Php ${data['amount'] ?? 'N/A'}'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              height: 36,
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  // Edit logic
                                                },
                                                icon: const Icon(Icons.edit, color: Colors.black, size: 18),
                                                label: const Text("Edit", style: TextStyle(color: Colors.black, fontSize: 13)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  elevation: 2,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            SizedBox(
                                              height: 36,
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  // QR code logic
                                                },
                                                icon: const Icon(Icons.qr_code, color: Colors.black, size: 18),
                                                label: const Text("QR Code", style: TextStyle(color: Colors.black, fontSize: 13)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  elevation: 2,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
                    Text("Page ${_currentPage + 1} of ${(_filteredMembers.length / _itemsPerPage).ceil()}"),
                    TextButton(
                      onPressed: (_currentPage + 1) * _itemsPerPage < _filteredMembers.length
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
