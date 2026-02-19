import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class BudgetLogic {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- 1. THE GLOBAL BOOKMARK (MONTH SYNC) ---
  // This variable controls the entire app's time machine.
  // When changed in Budget Setup, Dashboard and others follow.
  static DateTime selectedDate = DateTime.now();

  // --- 2. GLOBAL WARNING TOGGLE ---
  // Connects to the switch in Settings to stop notifications.
  static bool warningsEnabled = true;

  // --- 3. DYNAMIC MONTH KEY ---
  // Generates the folder name (e.g., "01-2026") based on the bookmark.
  static String get monthKey => DateFormat('MM-yyyy').format(selectedDate);

  // FEATURE #2 & #4: Smart Adaptation Logic
  // Now uses the SYNCED monthKey instead of the real-world date.
  static Stream<DocumentSnapshot> getBudgetStream() {
    String uid = _auth.currentUser?.uid ?? "";
    return _db.collection('users').doc(uid).collection('budgets').doc(monthKey).snapshots();
  }

  // Logic to calculate if a warning is needed
  // This now checks the 'warningsEnabled' toggle first.
  static String getBudgetWarning(double spent, double budget) {
    if (!warningsEnabled || budget == 0) return "";

    double percent = (spent / budget) * 100;
    if (percent >= 100) return "⚠️ Budget Exceeded!";
    if (percent >= 80) return "Warning: 80% of budget spent.";
    return "";
  }

  // Helper to quickly return to the current real-world month
  static void resetToCurrentMonth() {
    selectedDate = DateTime.now();
  }
}