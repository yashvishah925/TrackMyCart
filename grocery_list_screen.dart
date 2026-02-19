import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'budget_logic.dart';

class GroceryListScreen extends StatefulWidget {
  const GroceryListScreen({super.key});

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool isReviewMode = false;
  String selectedCategory = "All";
  String searchQuery = "";
  final FocusNode _searchFocus = FocusNode();

  final Color pastelGreen = const Color(0xFFDCFCE7);
  final Color deepPastelGreen = const Color(0xFF22C55E);
  final Color surfaceGrey = const Color(0xFFF8FAFC);

  final List<String> categories = ["All", "Vegetables", "Fruits", "Dairy", "Bakery", "Meat", "Snacks"];

  final List<Map<String, dynamic>> masterProducts = [
    {"name": "Spinach", "category": "Vegetables", "icon": Icons.eco, "color": Colors.green},
    {"name": "Tomato", "category": "Vegetables", "icon": Icons.fiber_manual_record, "color": Colors.red},
    {"name": "Carrot", "category": "Vegetables", "icon": Icons.eco, "color": Colors.orange},
    {"name": "Apples", "category": "Fruits", "icon": Icons.apple, "color": Colors.red},
    {"name": "Banana", "category": "Fruits", "icon": Icons.shopping_basket, "color": Colors.yellow},
    {"name": "Grapes", "category": "Fruits", "icon": Icons.blur_on, "color": Colors.purple},
    {"name": "Milk", "category": "Dairy", "icon": Icons.water_drop, "color": Colors.blue},
    {"name": "Eggs", "category": "Dairy", "icon": Icons.egg, "color": Colors.brown},
    {"name": "Cheese", "category": "Dairy", "icon": Icons.bakery_dining, "color": Colors.yellow},
    {"name": "Bread", "category": "Bakery", "icon": Icons.bakery_dining, "color": Colors.orange},
    {"name": "Cookie", "category": "Bakery", "icon": Icons.cookie, "color": Colors.brown},
    {"name": "Chicken", "category": "Meat", "icon": Icons.restaurant, "color": Colors.red},
    {"name": "Beef", "category": "Meat", "icon": Icons.kebab_dining, "color": Colors.redAccent},
    {"name": "Chips", "category": "Snacks", "icon": Icons.fastfood, "color": Colors.orange},
  ];

  List<Map<String, dynamic>> filteredResults = [];

  // --- SYNC TO FIREBASE ---
  Future<void> _syncToFirebase(String docId, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('users').doc(user!.uid)
        .collection('budgets').doc(BudgetLogic.monthKey)
        .collection('shopping_list').doc(docId).set(data, SetOptions(merge: true));
  }

  // --- HANDLE PURCHASE & CASCADE MATH ---
  void _handlePurchase(String docId, Map<String, dynamic> item, bool isChecking) async {
    final batch = FirebaseFirestore.instance.batch();
    final monthRef = FirebaseFirestore.instance
        .collection('users').doc(user!.uid)
        .collection('budgets').doc(BudgetLogic.monthKey);

    batch.update(monthRef.collection('shopping_list').doc(docId), {'isPurchased': isChecking});

    final expenseRef = monthRef.collection('expenses').doc(docId);

    if (isChecking) {
      batch.set(expenseRef, {...item, 'isPurchased': true, 'date': DateTime.now()});
      batch.update(monthRef, {'total_spent': FieldValue.increment((item['price'] ?? 0.0) * (item['qty'] ?? 1))});
    } else {
      batch.delete(expenseRef);
      batch.update(monthRef, {'total_spent': FieldValue.increment(-((item['price'] ?? 0.0) * (item['qty'] ?? 1)))});
    }
    await batch.commit();
  }

  // --- FIX: PENCIL ICON (PRICE EDIT) WITH CASCADE UPDATE ---
  void _openPriceModal(Map<String, dynamic> product, {String? docId, double? oldPrice, int? oldQty}) {
    TextEditingController priceController = TextEditingController(text: oldPrice?.toString() ?? "");
    int quantity = oldQty ?? 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          padding: EdgeInsets.only(top: 20, left: 24, right: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(docId != null ? "Edit ${product['name']}" : "Add ${product['name']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(hintText: "Enter price (₹)", filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Quantity", style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(onPressed: () => setModalState(() => quantity > 1 ? quantity-- : null), icon: const Icon(Icons.remove_circle_outline)),
                      Text("$quantity", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => setModalState(() => quantity++), icon: const Icon(Icons.add_circle_outline, color: Colors.green)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: pastelGreen, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    double finalPrice = double.tryParse(priceController.text) ?? 0.0;
                    String id = docId ?? product['name'];

                    // 1. Update Shopping List
                    Map<String, dynamic> updatedData = {
                      'name': product['name'],
                      'category': product['category'],
                      'price': finalPrice,
                      'qty': quantity,
                      'isPurchased': product['isPurchased'] ?? false,
                      'isFav': product['isFav'] ?? false,
                      'icon_code': product['icon_code'] ?? product['icon'].codePoint,
                      'color_value': product['color_value'] ?? product['color'].value,
                      'addedAt': DateTime.now(),
                    };
                    await _syncToFirebase(id, updatedData);

                    // 2. CASCADE UPDATE: If already purchased, update the Expense and Total Spent
                    if (product['isPurchased'] == true) {
                      final monthRef = FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('budgets').doc(BudgetLogic.monthKey);

                      // Calculate the difference in price to update the total_spent correctly
                      double oldTotal = (oldPrice ?? 0.0) * (oldQty ?? 1);
                      double newTotal = finalPrice * quantity;
                      double difference = newTotal - oldTotal;

                      await monthRef.collection('expenses').doc(id).update({
                        'price': finalPrice,
                        'qty': quantity,
                      });

                      await monthRef.update({'total_spent': FieldValue.increment(difference)});
                    }

                    setState(() { searchQuery = ""; filteredResults = []; });
                    Navigator.pop(context);
                  },
                  child: Text(docId != null ? "Save Changes" : "Confirm", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceGrey,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (!isReviewMode) _buildCategoryFilter(),
            Expanded(
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (searchQuery.isEmpty && !isReviewMode) _buildFavSuggestions(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        child: Text(isReviewMode ? "Items to Buy" : "My Shopping List", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(child: _buildMainList()),
                    ],
                  ),
                  if (filteredResults.isNotEmpty && !isReviewMode) _buildSearchResults(),
                ],
              ),
            ),
            _buildStickyBottomBar(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildMainList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(user?.uid)
          .collection('budgets').doc(BudgetLogic.monthKey)
          .collection('shopping_list').orderBy('addedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        if (isReviewMode) docs = docs.where((d) => (d.data() as Map<String, dynamic>)['isPurchased'] == false).toList();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final item = doc.data() as Map<String, dynamic>;
            bool purchased = item['isPurchased'] ?? false;
            bool isFav = item['isFav'] ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: purchased ? Colors.grey.shade100 : Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Row(
                children: [
                  Icon(IconData(item['icon_code'], fontFamily: 'MaterialIcons'), color: purchased ? Colors.grey : (isFav ? Colors.red : Color(item['color_value'])), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: purchased ? Colors.grey : Colors.black, decoration: purchased ? TextDecoration.lineThrough : null)),
                        Text("₹${item['price']} • Qty: ${item['qty']}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => _openPriceModal(item, docId: doc.id, oldPrice: (item['price'] as num).toDouble(), oldQty: item['qty']), icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey, size: 18)),
                  if (!isReviewMode) ...[
                    IconButton(onPressed: () => FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('budgets').doc(BudgetLogic.monthKey).collection('shopping_list').doc(doc.id).update({'isFav': !isFav}), icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: Colors.red, size: 20)),
                    Checkbox(value: purchased, activeColor: deepPastelGreen, onChanged: (val) => _handlePurchase(doc.id, item, val!)),
                  ]
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(onPressed: () => isReviewMode ? setState(() => isReviewMode = false) : Navigator.pop(context), icon: Icon(isReviewMode ? Icons.close : Icons.arrow_back_ios_new, size: 20)),
          Text(isReviewMode ? "Review List" : "Grocery List", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          if (!isReviewMode) ...[
            const SizedBox(height: 15),
            TextField(onChanged: _searchItems, decoration: InputDecoration(hintText: "Search...", prefixIcon: const Icon(Icons.search, size: 20), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
          ]
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(height: 35, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 24), itemCount: categories.length, itemBuilder: (context, index) {
      bool isSelected = selectedCategory == categories[index];
      return GestureDetector(onTap: () => setState(() { selectedCategory = categories[index]; _searchItems(searchQuery); }), child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 15), decoration: BoxDecoration(color: isSelected ? deepPastelGreen : Colors.white, borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Text(categories[index], style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 12, fontWeight: FontWeight.bold))));
    }));
  }

  Widget _buildFavSuggestions() => const SizedBox.shrink();

  void _searchItems(String query) {
    setState(() {
      searchQuery = query;
      filteredResults = query.isEmpty ? [] : masterProducts.where((item) => item['name'].toLowerCase().contains(query.toLowerCase()) && (selectedCategory == "All" || item['category'] == selectedCategory)).toList();
    });
  }

  Widget _buildSearchResults() {
    return Positioned(top: 0, left: 24, right: 24, child: Material(elevation: 8, borderRadius: BorderRadius.circular(15), child: Container(constraints: const BoxConstraints(maxHeight: 250), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: ListView.builder(shrinkWrap: true, itemCount: filteredResults.length, itemBuilder: (context, index) {
      final item = filteredResults[index];
      return ListTile(leading: Icon(item['icon'], color: item['color'], size: 20), title: Text(item['name']), onTap: () => _openPriceModal(item));
    }))));
  }

  Widget _buildStickyBottomBar() {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(user?.uid)
            .collection('budgets').doc(BudgetLogic.monthKey)
            .collection('shopping_list').snapshots(),
        builder: (context, snapshot) {
          double total = 0;
          if (snapshot.hasData) for (var d in snapshot.data!.docs) if (!(d['isPurchased'] ?? false)) total += ((d['price'] ?? 0) * (d['qty'] ?? 1));
          return Padding(padding: const EdgeInsets.only(bottom: 10, left: 20, right: 20), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(25)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [const Text("ESTIMATED TOTAL", style: TextStyle(color: Colors.white54, fontSize: 9)), Text("₹${total.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: pastelGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => setState(() => isReviewMode = !isReviewMode), child: Text(isReviewMode ? "Add Items" : "Review List", style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)))
          ])));
        }
    );
  }

  Widget _buildBottomNav() {
    return Container(height: 60, color: Colors.white, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      IconButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen())), icon: const Icon(Icons.home_rounded, color: Colors.blueGrey, size: 26)),
      IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())), icon: const Icon(Icons.person_rounded, color: Colors.blueGrey, size: 26)),
    ]));
  }
}