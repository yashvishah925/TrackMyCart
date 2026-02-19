import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'package:intl/intl.dart';
import 'budget_logic.dart'; // IMPORTED: The Global Brain

class BudgetSetupScreen extends StatefulWidget {
  const BudgetSetupScreen({super.key});

  @override
  State<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends State<BudgetSetupScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Uses the Global Brain's selectedDate for month syncing
  DateTime get _selectedDate => BudgetLogic.selectedDate;

  double _veggiesPercent = 30;
  double _dairyPercent = 20;
  double _meatPercent = 25;

  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isEditingNote = false;
  bool _isLoading = false;

  double _oldBudgetDisplay = 0.0;
  double _newBudgetDisplay = 0.0;

  final Color pastelGreen = const Color(0xFFB2F2BB);
  final Color deepPastelGreen = const Color(0xFF2B543A);
  final Color primaryGreen = const Color(0xFF22C55E);

  @override
  void initState() {
    super.initState();
    _loadMonthDataFromFirebase();
  }

  void _loadMonthDataFromFirebase() async {
    if (user == null) return;
    String monthKey = BudgetLogic.monthKey;

    var doc = await FirebaseFirestore.instance
        .collection('users').doc(user!.uid)
        .collection('budgets').doc(monthKey).get();

    if (mounted) {
      setState(() {
        if (doc.exists) {
          _oldBudgetDisplay = (doc.data()?['old_budget'] ?? 0.0).toDouble();
          _newBudgetDisplay = (doc.data()?['active_budget'] ?? 0.0).toDouble();
          _noteController.text = doc.data()?['note'] ?? "";
          _veggiesPercent = (doc.data()?['allocation_veggies'] ?? 30.0).toDouble();
          _dairyPercent = (doc.data()?['allocation_dairy'] ?? 20.0).toDouble();
          _meatPercent = (doc.data()?['allocation_meat'] ?? 25.0).toDouble();
        } else {
          _oldBudgetDisplay = 0.0;
          _newBudgetDisplay = 0.0;
          _noteController.text = "";
        }
        _budgetController.clear();
      });
    }
  }

  // FIXED LOGIC: Saves only the note to Firestore
  void _saveNoteToFirebase() async {
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('users').doc(user!.uid)
          .collection('budgets').doc(BudgetLogic.monthKey)
          .set({'note': _noteController.text.trim()}, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Note saved successfully!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving note: $e")));
    } finally {
      if (mounted) setState(() { _isLoading = false; _isEditingNote = false; });
    }
  }

  // Individual save for Category Allocations
  void _saveCategoryPopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Update Allocations?"),
        content: const Text("Save these category percentages for the month?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
            onPressed: () {
              _performFirebaseSave(_newBudgetDisplay, false, onlyAllocations: true);
              Navigator.pop(context);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  void _confirmSave() {
    String input = _budgetController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a budget amount")));
      return;
    }
    double enteredValue = double.tryParse(input) ?? 0.0;
    bool isInitialSetup = _oldBudgetDisplay == 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isInitialSetup ? "Save Initial Budget?" : "Update to New Budget?"),
        content: Text("Set budget to ₹${enteredValue.toStringAsFixed(2)} for ${DateFormat('MMMM').format(_selectedDate)}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
            onPressed: () {
              _performFirebaseSave(enteredValue, isInitialSetup);
              Navigator.pop(context);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  void _performFirebaseSave(double amount, bool isInitial, {bool onlyAllocations = false}) async {
    if (user == null) return;
    setState(() => _isLoading = true);
    String monthKey = BudgetLogic.monthKey;

    try {
      DocumentReference budgetRef = FirebaseFirestore.instance
          .collection('users').doc(user!.uid)
          .collection('budgets').doc(monthKey);

      if (onlyAllocations) {
        await budgetRef.update({
          'allocation_veggies': _veggiesPercent,
          'allocation_dairy': _dairyPercent,
          'allocation_meat': _meatPercent,
        });
      } else {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentSnapshot snapshot = await transaction.get(budgetRef);
          if (!snapshot.exists) {
            transaction.set(budgetRef, {
              'old_budget': amount,
              'active_budget': amount,
              'note': _noteController.text,
              'allocation_veggies': _veggiesPercent,
              'allocation_dairy': _dairyPercent,
              'allocation_meat': _meatPercent,
              'total_spent': 0.0,
              'month_year': monthKey,
              'last_updated': DateTime.now(),
            });
          } else {
            double currentActive = (snapshot.data() as Map<String, dynamic>)['active_budget'] ?? 0.0;
            transaction.update(budgetRef, {
              'old_budget': currentActive,
              'active_budget': amount,
              'last_updated': DateTime.now(),
            });
          }
        });
      }

      if (mounted) {
        _loadMonthDataFromFirebase();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(onlyAllocations ? "Allocations Updated!" : "Budget Saved!")),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() { _isLoading = false; _isEditingNote = false; });
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        BudgetLogic.selectedDate = picked;
        _loadMonthDataFromFirebase();
        _isEditingNote = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            if (_isLoading) const LinearProgressIndicator(color: Colors.green),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new, size: 22)),
                        TextButton.icon(
                          onPressed: () => _selectMonth(context),
                          icon: const Icon(Icons.calendar_month, color: Color(0xFF2B543A)),
                          label: Text(DateFormat('MMMM yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2B543A))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text("Budget Setup", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Planning for ${DateFormat('MMMM yyyy').format(_selectedDate)}", style: const TextStyle(color: Colors.blueGrey, fontSize: 16)),
                    const SizedBox(height: 25),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF1F5F9))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniReport("Old Budget", "₹${_oldBudgetDisplay.toStringAsFixed(0)}"),
                          const SizedBox(height: 30, child: VerticalDivider(color: Colors.grey)),
                          _buildMiniReport("New Budget", "₹${_newBudgetDisplay.toStringAsFixed(0)}"),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),
                    const Text("Enter Budget", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),

                    TextField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.currency_rupee, color: Colors.blueGrey),
                        hintText: "Enter amount",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                    ),

                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Reason for Change", style: TextStyle(fontWeight: FontWeight.bold)),
                        // FIXED: Now triggers individual Note Save logic
                        IconButton(
                            icon: Icon(_isEditingNote ? Icons.check_circle : Icons.edit_note, color: primaryGreen),
                            onPressed: () {
                              if (_isEditingNote) {
                                _saveNoteToFirebase(); // SAVES note individually
                              } else {
                                setState(() => _isEditingNote = true);
                              }
                            }
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: _isEditingNote ? primaryGreen : const Color(0xFFF1F5F9))),
                      child: TextField(controller: _noteController, enabled: _isEditingNote, maxLines: 2, decoration: const InputDecoration(hintText: "Add a note...", border: InputBorder.none)),
                    ),

                    const SizedBox(height: 35),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Category Allocation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton(onPressed: _saveCategoryPopup, child: const Text("Save All", style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildAllocationCard("Veggies & Fruits", _veggiesPercent, Icons.eco, Colors.green, (val) => setState(() => _veggiesPercent = val)),
                    _buildAllocationCard("Dairy & Eggs", _dairyPercent, Icons.egg_alt, Colors.blue, (val) => setState(() => _dairyPercent = val)),
                    _buildAllocationCard("Meat & Seafood", _meatPercent, Icons.restaurant, Colors.red, (val) => setState(() => _meatPercent = val)),
                  ],
                ),
              ),
            ),
            _buildStickyFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniReport(String title, String value) {
    return Column(children: [Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black))]);
  }

  Widget _buildAllocationCard(String title, double value, IconData icon, Color color, Function(double) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)
                    ),
                    child: Icon(icon, color: color, size: 20)
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))
              ]),
              Text("${value.toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            ],
          ),
          Slider(value: value, min: 0, max: 100, activeColor: primaryGreen, inactiveColor: Colors.grey.shade100, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildStickyFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity, height: 60,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _confirmSave,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Confirm & Save", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen())), icon: const Icon(Icons.home_rounded, size: 28, color: Colors.blueGrey)),
              IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())), icon: const Icon(Icons.person_rounded, size: 28, color: Colors.blueGrey)),
            ],
          ),
        ],
      ),
    );
  }
}