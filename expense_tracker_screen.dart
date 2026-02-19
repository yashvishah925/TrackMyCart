import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dashboard_screen.dart';
import 'grocery_list_screen.dart';
import 'profile_screen.dart';
import 'budget_logic.dart'; // IMPORTED: The Global Brain

class ExpenseTrackerScreen extends StatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final Color pastelGreen = const Color(0xFFDCFCE7);
  final Color accentGreen = const Color(0xFF22C55E);

  // --- FIX #1: MONTH SYNC LOGIC ---
  // Now follows the global bookmark instead of hardcoded DateTime.now()
  String get currentMonthKey => BudgetLogic.monthKey;
  DateTime get currentSelectedDate => BudgetLogic.selectedDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          // SYNCED: Fetching budget for the specific month selected
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('budgets').doc(currentMonthKey).snapshots(),
          builder: (context, budgetSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              // SYNCED: Fetching expenses for the specific month selected
              stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('budgets').doc(currentMonthKey).collection('expenses').orderBy('date', descending: true).snapshots(),
              builder: (context, expenseSnapshot) {

                double activeBudget = 0.0;
                double totalSpent = 0.0;

                if (budgetSnapshot.hasData && budgetSnapshot.data!.exists) {
                  var data = budgetSnapshot.data!.data() as Map<String, dynamic>;
                  activeBudget = (data['active_budget'] ?? 0.0).toDouble();
                  totalSpent = (data['total_spent'] ?? 0.0).toDouble();
                }

                double remaining = activeBudget - totalSpent;

                // --- FIX #2: WARNING TOGGLE SYNC ---
                // Now uses the logic function that respects the Settings toggle
                String warning = BudgetLogic.getBudgetWarning(totalSpent, activeBudget);

                List<QueryDocumentSnapshot> expenses = expenseSnapshot.data?.docs ?? [];

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                            ),
                            const SizedBox(height: 10),
                            const Text("Expense Tracker", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                            // UPDATED: Now displays the name of the selected month
                            Text("Purchases for ${DateFormat('MMMM yyyy').format(currentSelectedDate)}", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                          ],
                        ),
                      ),

                      if (warning.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: warning.contains("⚠️") ? Colors.red.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: warning.contains("⚠️") ? Colors.red.shade200 : Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(warning.contains("⚠️") ? Icons.report_problem : Icons.info_outline, color: warning.contains("⚠️") ? Colors.red : Colors.orange, size: 20),
                                const SizedBox(width: 10),
                                Expanded(child: Text(warning, style: TextStyle(color: warning.contains("⚠️") ? Colors.red.shade900 : Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 12))),
                              ],
                            ),
                          ),
                        ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: pastelGreen, borderRadius: BorderRadius.circular(30)),
                          child: Column(
                            children: [
                              Text("TOTAL SPENT SO FAR", style: TextStyle(color: accentGreen.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                              const SizedBox(height: 8),
                              Text("₹${totalSpent.toStringAsFixed(2)}", style: TextStyle(color: accentGreen, fontSize: 36, fontWeight: FontWeight.bold)),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 16.0), child: Divider(color: accentGreen.withValues(alpha: 0.1))),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildStatItem("Budget", "₹${activeBudget.toStringAsFixed(0)}"),
                                  _buildStatItem("Remaining", "₹${remaining.toStringAsFixed(0)}"),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 32, 24, 16),
                        child: Text("Recently Purchased", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),

                      if (expenses.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text("No items purchased this month.", style: TextStyle(color: Colors.grey))))
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            children: expenses.map((doc) {
                              final item = doc.data() as Map<String, dynamic>;
                              return _buildExpenseItem(
                                  IconData(item['icon_code'] ?? 57905, fontFamily: 'MaterialIcons'),
                                  item['name'] ?? "Unknown",
                                  "${item['category']} • ${item['qty']} Qty",
                                  ((item['price'] ?? 0) * (item['qty'] ?? 1)).toStringAsFixed(2)
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade100))),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavButton(context, Icons.home_rounded, "Home", false, () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()))),
              _buildNavButton(context, Icons.person_rounded, "Profile", false, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()))),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPERS REMAIN UNCHANGED ---
  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: accentGreen.withValues(alpha: 0.6), fontSize: 12)),
        Text(value, style: TextStyle(color: accentGreen, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildExpenseItem(IconData icon, String title, String subtitle, String price) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: pastelGreen, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: accentGreen, size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12))])),
          Text("₹$price", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildNavButton(BuildContext context, IconData icon, String label, bool isActive, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: isActive ? accentGreen : Colors.grey.shade400), Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isActive ? accentGreen : Colors.grey.shade400))]));
  }
}