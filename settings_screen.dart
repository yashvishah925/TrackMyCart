import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dashboard_screen.dart';
import 'budget_setup_screen.dart';
import 'welcome_screen.dart';
import 'budget_logic.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  String get currentMonthKey => BudgetLogic.monthKey;

  // --- UPDATED LOGIC: AUTH PERSISTENCE EXIT ---
  void _handleLogout() async {
    // This tells Firebase to clear the saved session on the phone
    await FirebaseAuth.instance.signOut();

    // Because we used a StreamBuilder in main.dart, the app will
    // automatically see this logout and switch to WelcomeScreen.
    // We use pushAndRemoveUntil to clear the navigation history.
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (route) => false,
      );
    }
  }

  Future<void> _resetFirebaseData() async {
    if (user == null) return;
    final batch = FirebaseFirestore.instance.batch();

    var expenseDocs = await FirebaseFirestore.instance
        .collection('users').doc(user!.uid)
        .collection('budgets').doc(currentMonthKey)
        .collection('expenses').get();

    for (var doc in expenseDocs.docs) {
      batch.delete(doc.reference);
    }

    var listDocs = await FirebaseFirestore.instance
        .collection('users').doc(user!.uid)
        .collection('budgets').doc(currentMonthKey)
        .collection('shopping_list').get();

    for (var doc in listDocs.docs) {
      batch.delete(doc.reference);
    }

    batch.update(
        FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('budgets').doc(currentMonthKey),
        {
          'total_spent': 0.0,
          'active_budget': 0.0,
          'note': "",
        }
    );

    await batch.commit();
  }

  void _showResetConfirmation() {
    String monthName = DateFormat('MMMM yyyy').format(BudgetLogic.selectedDate);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Reset $monthName Data?"),
        content: Text(
          "This will permanently clear your expenses and grocery list for $monthName from the cloud.",
          style: const TextStyle(color: Colors.blueGrey),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              await _resetFirebaseData();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Data for $monthName has been cleared.")));
              }
            },
            child: const Text("Yes, Reset", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('budgets').doc(currentMonthKey).snapshots(),
                builder: (context, snapshot) {
                  double currentLimit = 0.0;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    currentLimit = (snapshot.data!['active_budget'] ?? 0.0).toDouble();
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _buildSectionHeader("BUDGETING"),
                      Container(
                        decoration: _cardDecoration(),
                        child: Column(
                          children: [
                            _buildSettingTile(
                              icon: Icons.account_balance_wallet_rounded,
                              iconColor: const Color(0xFF22C55E),
                              bgColor: const Color(0xFFF0FDF4),
                              title: "Change Budget",
                              subtitle: "Current limit: ₹${currentLimit.toStringAsFixed(2)}",
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BudgetSetupScreen())),
                            ),
                            const Divider(height: 1, indent: 60),
                            _buildSettingTile(
                              icon: Icons.restart_alt_rounded,
                              iconColor: Colors.orange,
                              bgColor: const Color(0xFFFFF7ED),
                              title: "Reset Monthly Data",
                              subtitle: "Clear expenses & list for ${DateFormat('MMM').format(BudgetLogic.selectedDate)}",
                              onTap: _showResetConfirmation,
                            ),
                            const Divider(height: 1, indent: 60),
                            _buildToggleTile(
                              icon: Icons.notifications_active_rounded,
                              iconColor: Colors.red,
                              bgColor: const Color(0xFFFEF2F2),
                              title: "Budget Warnings",
                              subtitle: BudgetLogic.warningsEnabled ? "Alerts enabled" : "Alerts disabled",
                              value: BudgetLogic.warningsEnabled,
                              onChanged: (val) {
                                setState(() {
                                  BudgetLogic.warningsEnabled = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader("INFORMATION"),
                      Container(
                        decoration: _cardDecoration(),
                        child: _buildSettingTile(
                          icon: Icons.info_outline_rounded,
                          iconColor: Colors.blue,
                          bgColor: const Color(0xFFEFF6FF),
                          title: "About App",
                          subtitle: "Version 1.1.0 • Stable Build",
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(height: 40),
                      Column(
                        children: [
                          TextButton(
                            onPressed: _handleLogout,
                            child: const Text("Log Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          const Text("TRACKMYCART © 2026", style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1.2)),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 8, right: 24, bottom: 16),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF22C55E), size: 20), onPressed: () => Navigator.pop(context)),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              Text('Manage your budget preferences', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF1F5F9)));
  Widget _buildSectionHeader(String title) => Padding(padding: const EdgeInsets.only(left: 8, bottom: 8), child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)));
  Widget _buildSettingTile({required IconData icon, required Color iconColor, required Color bgColor, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: 22)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
    );
  }
  Widget _buildToggleTile({required IconData icon, required Color iconColor, required Color bgColor, required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: 22)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF22C55E)),
    );
  }
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade100))),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_rounded, "Home", false, () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()))),
            _navItem(Icons.person_rounded, "Profile", true, () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
  Widget _navItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? const Color(0xFF22C55E) : Colors.grey.shade400),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isActive ? const Color(0xFF22C55E) : Colors.grey.shade400)),
        ],
      ),
    );
  }
}