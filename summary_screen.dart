import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  DateTime _viewingDate = DateTime.now(); // Month currently being viewed

  final Color pastelProgressGreen = const Color(0xFFA7F3D0);
  final Color deepGreen = const Color(0xFF059669);

  String get _monthKey => DateFormat('MM-yyyy').format(_viewingDate);

  void _resetToCurrentMonth() {
    setState(() => _viewingDate = DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    bool isLookingAtPastMonth = _monthKey != DateFormat('MM-yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen())),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Spending Summary', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
            Text(
              'Monthly Report • ${DateFormat('MMMM yyyy').format(_viewingDate)}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          if (isLookingAtPastMonth)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TextButton.icon(
                onPressed: _resetToCurrentMonth,
                icon: Icon(Icons.restore, size: 16, color: deepGreen),
                label: Text("Current", style: TextStyle(color: deepGreen, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // FEATURE #4: PULLS LIVE DATA FROM BACKEND
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('budgets').doc(_monthKey).snapshots(),
        builder: (context, budgetSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('budgets').doc(_monthKey).collection('expenses').snapshots(),
            builder: (context, expenseSnapshot) {

              double totalSpent = 0.0;
              double budgetLimit = 0.0;

              if (budgetSnapshot.hasData && budgetSnapshot.data!.exists) {
                var bData = budgetSnapshot.data!.data() as Map<String, dynamic>;
                budgetLimit = (bData['active_budget'] ?? 0.0).toDouble();
                totalSpent = (bData['total_spent'] ?? 0.0).toDouble();
              }

              double ratio = budgetLimit > 0 ? (totalSpent / budgetLimit).clamp(0.0, 1.1) : 0.0;

              // Categorization Logic
              double getCatAmount(String catName) {
                if (!expenseSnapshot.hasData) return 0.0;
                return expenseSnapshot.data!.docs.where((doc) => doc['category'] == catName).fold(0.0, (sum, doc) => sum + ((doc['price'] ?? 0.0) * (doc['qty'] ?? 0)));
              }

              final List<Map<String, dynamic>> categories = [
                {"name": "Veggies & Fruits", "amount": getCatAmount("Vegetables") + getCatAmount("Fruits"), "color": Colors.green, "icon": Icons.eco},
                {"name": "Dairy & Eggs", "amount": getCatAmount("Dairy"), "color": Colors.blue, "icon": Icons.water_drop},
                {"name": "Meat & Seafood", "amount": getCatAmount("Meat"), "color": Colors.red, "icon": Icons.set_meal},
                {"name": "Bakery", "amount": getCatAmount("Bakery"), "color": Colors.orange, "icon": Icons.bakery_dining},
              ];

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  children: [
                    // --- PROGRESS CIRCLE (YOUR UI) ---
                    _buildProgressCard(totalSpent, budgetLimit, ratio),

                    const SizedBox(height: 25),
                    const Text("Category Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    ...categories.map((cat) {
                      double catRatio = totalSpent > 0 ? (cat['amount'] / totalSpent) : 0.0;
                      return _buildCategoryItem(cat['name'], "₹${cat['amount'].toStringAsFixed(0)}", catRatio, cat['color'], cat['icon']);
                    }),

                    const SizedBox(height: 30),
                    const Text("Budget History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    _buildHistoryList(),

                    const SizedBox(height: 100),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildProgressCard(double spent, double limit, double ratio) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 180, width: 180,
                child: CircularProgressIndicator(
                  value: ratio > 1.0 ? 1.0 : ratio,
                  strokeWidth: 14,
                  backgroundColor: Colors.grey.shade100,
                  color: ratio >= 1.0 ? Colors.redAccent : deepGreen,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("SPENT", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                  Text("₹${spent.toStringAsFixed(0)}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  Text("of ₹${limit.toStringAsFixed(0)}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              )
            ],
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              _buildLegendItem("Spent", "${(ratio * 100).toInt()}%", deepGreen),
              Container(height: 35, width: 1, color: Colors.grey.shade200),
              _buildLegendItem("Left", "${(100 - (ratio * 100)).toInt().clamp(0, 100)}%", Colors.grey.shade300),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return StreamBuilder<QuerySnapshot>(
      // FEATURE #4: FETCHES PREVIOUS MONTHS FROM BACKEND
      stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('budgets').orderBy('month_year', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final key = doc.id;

            return GestureDetector(
              onTap: () => setState(() => _viewingDate = DateFormat('MM-yyyy').parse(key)),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: _monthKey == key ? pastelProgressGreen.withValues(alpha: 0.2) : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: _monthKey == key ? deepGreen : Colors.grey.shade100)
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("Limit: ₹${data['active_budget']}", style: const TextStyle(color: Colors.blueGrey, fontSize: 13)),
                    const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // --- UI HELPERS (EXACTLY AS REQUESTED) ---
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade100))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(icon: const Icon(Icons.home_rounded, color: Colors.blueGrey, size: 28), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()))),
          IconButton(icon: const Icon(Icons.person_rounded, color: Colors.blueGrey, size: 28), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()))),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String percent, Color color) {
    return Expanded(child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500))]), const SizedBox(height: 4), Text(percent, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]));
  }

  Widget _buildCategoryItem(String title, String amount, double progress, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        children: [
          Container(height: 45, width: 45, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]), const SizedBox(height: 10), ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, backgroundColor: Colors.grey.shade100, color: color, minHeight: 6))])),
        ],
      ),
    );
  }
}