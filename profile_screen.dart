import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'welcome_screen.dart';
import 'budget_logic.dart'; // IMPORTED: The Global Brain

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // --- FIX #1: MONTH SYNC LOGIC ---
  // Now follows the global bookmark instead of hardcoded DateTime.now()
  String get currentMonthKey => BudgetLogic.monthKey;

  // FEATURE #1 & #5: Profile Editing with Firestore Sync
  void _editProfileModal(String currentName) {
    TextEditingController nameController = TextEditingController(text: currentName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.only(
          top: 20, left: 24, right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Edit Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Full Name",
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                    'name': nameController.text.trim(),
                  });
                  if (mounted) Navigator.pop(context);
                },
                child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
          builder: (context, userSnapshot) {
            return StreamBuilder<DocumentSnapshot>(
              // --- FIX #2: SYNCED BUDGET PROGRESS ---
              // Listening to the month folder chosen in Budget Setup
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .collection('budgets')
                  .doc(currentMonthKey)
                  .snapshots(),
              builder: (context, budgetSnapshot) {

                String name = userSnapshot.data?.get('name') ?? "User";
                String email = userSnapshot.data?.get('email') ?? "email@example.com";
                String initial = name.isNotEmpty ? name[0].toUpperCase() : "U";

                double spent = 0.0;
                double budget = 0.0;
                if (budgetSnapshot.hasData && budgetSnapshot.data!.exists) {
                  var data = budgetSnapshot.data!.data() as Map<String, dynamic>;
                  spent = (data['total_spent'] ?? 0.0).toDouble();
                  budget = (data['active_budget'] ?? 0.0).toDouble();
                }
                double ratio = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 110, height: 110,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE2FBE9)),
                              child: Center(
                                child: Text(initial, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF22C55E))),
                              ),
                            ),
                            Positioned(
                              bottom: 0, right: 0,
                              child: GestureDetector(
                                onTap: () => _editProfileModal(name),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                                  child: const Icon(Icons.edit, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text(email, style: const TextStyle(color: Colors.blueGrey, fontSize: 14)),
                      const SizedBox(height: 30),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // UPDATED: Now shows which month's progress you are viewing
                              Text("${DateFormat('MMMM yyyy').format(BudgetLogic.selectedDate).toUpperCase()} BUDGET PROGRESS",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey)),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("₹${spent.toStringAsFixed(1)}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                                  const SizedBox(width: 8),
                                  Text("of ₹${budget.toStringAsFixed(1)}", style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 10,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildActionTile(context, icon: Icons.settings_outlined, title: "App Settings", onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                      }),
                      const SizedBox(height: 12),
                      _buildActionTile(context, icon: Icons.logout_rounded, title: "Logout", iconColor: Colors.redAccent, onTap: () async {
                        await FirebaseAuth.instance.signOut();
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const WelcomeScreen()), (route) => false);
                        }
                      }),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: const Color(0xFF22C55E),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: (index) {
          if (index == 0) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap, Color iconColor = Colors.blueGrey}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}