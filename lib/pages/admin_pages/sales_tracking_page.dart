import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class SalesTrackingPage extends StatefulWidget {
  const SalesTrackingPage({super.key});

  @override
  State<SalesTrackingPage> createState() => _SalesTrackingPageState();
}

class _SalesTrackingPageState extends State<SalesTrackingPage> {
  double todaysRevenue = 0;
  int totalSales = 0;
  int memberSales = 0;
  double avgSalesValue = 0;
  List<Map<String, dynamic>> recentSales = [];

  final currencyFormatter = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

  @override
  void initState() {
    super.initState();
    _loadSalesData();
  }

  Future<String> _getUserName(String userId) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('registrations')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.data()['name'] ?? 'Unknown';
      }
    } catch (_) {}
    return 'Unknown';
  }

  void _loadSalesData() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snap = await FirebaseFirestore.instance.collection('sales').get();

    double todayRevenue = 0;
    int total = 0;
    int members = 0;
    double totalAmount = 0;
    List<Map<String, dynamic>> recent = [];

    for (var doc in snap.docs) {
      final data = doc.data();
      double amount = (data['amount'] ?? 0).toDouble();
      String date = data['date'] ?? '';
      String plan = data['plan'] ?? '';
      String userId = data['userId'] ?? '';
      String source = data['source'] ?? '';

      // Fetch name from registrations
      String name = await _getUserName(userId);

      total++;
      totalAmount += amount;

      if (source.toLowerCase() == 'registration') members++;
      if (date == today) todayRevenue += amount;

      recent.add({
        'name': name,
        'plan': plan,
        'amount': amount,
        'date': date,
      });
    }

    setState(() {
      todaysRevenue = todayRevenue;
      totalSales = total;
      memberSales = members;
      avgSalesValue = total > 0 ? totalAmount / total : 0;
      recentSales = recent.reversed.toList(); // newest first
    });
  }

  Widget _buildStatCard(String title, dynamic value, Icon icon) {
    return Container(
      width: (MediaQuery.of(context).size.width - 56) / 2,
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Stack(
        children: [
          Align(alignment: Alignment.centerRight, child: icon),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6D5F5F))),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title.toLowerCase().contains("revenue") || title.toLowerCase().contains("value")
                      ? currencyFormatter.format(value)
                      : value.toString(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6D5F5F)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          'Zeus Gym - Sales Tracking',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Monitor daily sales and revenue performance", style: textTheme.bodySmall),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildStatCard("Today's Revenue", todaysRevenue, const Icon(Icons.attach_money, color: Colors.black)),
                _buildStatCard("Total Sales", totalSales, const Icon(Icons.trending_up, color: Colors.black)),
                _buildStatCard("Member Sales", memberSales, const Icon(Icons.person, color: Colors.black)),
                _buildStatCard("Avg Sales Value", avgSalesValue, const Icon(Icons.bar_chart, color: Colors.black)),
              ],
            ),
            const SizedBox(height: 30),
            Text("Recent Sales", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text("Latest transactions and sales activity", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Column(
              children: recentSales.map((sale) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    sale['name'],
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF6EBFEA),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Membership',
                                    style: TextStyle(fontSize: 10, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(sale['plan'], style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currencyFormatter.format(sale['amount']),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            sale['date'],
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
