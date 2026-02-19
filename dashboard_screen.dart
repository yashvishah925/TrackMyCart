import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'budget_setup_screen.dart';
import 'grocery_list_screen.dart';
import 'expense_tracker_screen.dart';
import 'summary_screen.dart';
import 'profile_screen.dart';
import 'budget_logic.dart'; // IMPORTED: The Global Brain

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // --- FIX #1: MONTH SYNC LOGIC ---
  // Now follows the global bookmark instead of hardcoded date
  String get currentMonthKey => BudgetLogic.monthKey;

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF22C55E);
    const Color pastelGreen = Color(0xFFB2F2BB);
    const Color deepPastelGreen = Color(0xFF2B543A);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
          builder: (context, userSnapshot) {
            return StreamBuilder<DocumentSnapshot>(
              // Listening to the SYNCED month key
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .collection('budgets')
                  .doc(currentMonthKey)
                  .snapshots(),
              builder: (context, budgetSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                String name = "User";
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  var data = userSnapshot.data!.data() as Map<String, dynamic>;
                  name = data['name'] ?? "User";
                }

                double budget = 0.0;
                double spent = 0.0;
                if (budgetSnapshot.hasData && budgetSnapshot.data!.exists) {
                  var bData = budgetSnapshot.data!.data() as Map<String, dynamic>;
                  budget = (bData['active_budget'] ?? 0.0).toDouble();
                  spent = (bData['total_spent'] ?? 0.0).toDouble();
                }
                double remaining = budget - spent;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Welcome back,", style: TextStyle(color: Colors.grey, fontSize: 14)),
                              Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                            child: CircleAvatar(
                              radius: 25,
                              backgroundColor: pastelGreen,
                              child: const Icon(Icons.person, color: deepPastelGreen),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      _buildBanner(primaryGreen),
                      const SizedBox(height: 30),
                      const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        children: [
                          _actionCard(context, "Budget Setup", "₹${remaining.toStringAsFixed(0)} left", Icons.wallet, Colors.green, const BudgetSetupScreen()),
                          _actionCard(context, "Grocery List", "Manage items", Icons.list, Colors.blue, const GroceryListScreen()),
                          _actionCard(context, "Expenses", "Daily stats", Icons.trending_up, Colors.orange, const ExpenseTrackerScreen()),
                          _actionCard(context, "Summary", "Report ready", Icons.bar_chart, Colors.purple, const SummaryScreen()),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // --- FIX #2: TODAY'S SPENDING LOGIC ---
                      // This filters your monthly list to show only today's purchases
                      const Text("Today's Spending", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      _buildTodaySpendingList(currentMonthKey),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // --- LIVE FILTERING FOR TODAY'S SPENDING ---
  Widget _buildTodaySpendingList(String key) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(user?.uid)
          .collection('budgets').doc(key)
          .collection('expenses')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No purchases made today.", style: TextStyle(color: Colors.grey)));
        }

        DateTime now = DateTime.now();
        var todayDocs = snapshot.data!.docs.where((doc) {
          DateTime date = (doc['date'] as Timestamp).toDate();
          return date.day == now.day && date.month == now.month && date.year == now.year;
        }).toList();

        if (todayDocs.isEmpty) {
          return const Center(child: Text("No purchases made today.", style: TextStyle(color: Colors.grey)));
        }

        return Column(
          children: todayDocs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return _spendingTile(
                data['name'] ?? "Item",
                "Today, ${DateFormat('jm').format((data['date'] as Timestamp).toDate())}",
                "₹${((data['price'] ?? 0) * (data['qty'] ?? 1)).toStringAsFixed(2)}"
            );
          }).toList(),
        );
      },
    );
  }

  // UI Helper for the spending tiles
  Widget _spendingTile(String title, String time, String amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        ],
      ),
    );
  }

  Widget _buildBanner(Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(25)),
      child: Row(
        children: [
          const Expanded(
            child: Text("Smart Grocery Shopping Assistant",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF065F46))),
          ),
          Icon(Icons.shopping_cart, size: 40, color: color.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _actionCard(BuildContext context, String title, String sub, IconData icon, Color color, Widget screen) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => screen)),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}