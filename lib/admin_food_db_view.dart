import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:animate_do/animate_do.dart';

class AdminFoodDbView extends StatefulWidget {
  const AdminFoodDbView({super.key});

  @override
  State<AdminFoodDbView> createState() => _AdminFoodDbViewState();
}

class _AdminFoodDbViewState extends State<AdminFoodDbView> {
  final _db = FirebaseDatabase.instance.ref();

  void _addFood() {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final proteinCtrl = TextEditingController();
    final carbsCtrl = TextEditingController();
    final fatsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('ADD TAMIL FOOD', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Per 100g serving', style: TextStyle(color: Colors.white24, fontSize: 10)),
              const SizedBox(height: 16),
              _field(nameCtrl, 'Food Name (e.g. Idli)', Icons.restaurant),
              const SizedBox(height: 12),
              _field(calCtrl, 'Calories (kcal)', Icons.local_fire_department, isNum: true),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(proteinCtrl, 'Protein (g)', Icons.fitness_center, isNum: true)),
                const SizedBox(width: 8),
                Expanded(child: _field(carbsCtrl, 'Carbs (g)', Icons.grain, isNum: true)),
              ]),
              const SizedBox(height: 12),
              _field(fatsCtrl, 'Fats (g)', Icons.opacity, isNum: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await _db.child('custom_foods').push().set({
                'name': nameCtrl.text.trim().toLowerCase(),
                'displayName': nameCtrl.text.trim(),
                'calories': double.tryParse(calCtrl.text) ?? 0,
                'protein': double.tryParse(proteinCtrl.text) ?? 0,
                'carbs': double.tryParse(carbsCtrl.text) ?? 0,
                'fats': double.tryParse(fatsCtrl.text) ?? 0,
                'timestamp': ServerValue.timestamp,
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('ADD', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon, {bool isNum = false}) {
    return TextField(
      controller: c,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
        prefixIcon: Icon(icon, color: Colors.white24, size: 18),
        filled: true, fillColor: Colors.black26,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFood,
        backgroundColor: Theme.of(context).primaryColor,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('ADD FOOD', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                const Text('CUSTOM FOOD DATABASE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
                const Spacer(),
                StreamBuilder<DatabaseEvent>(
                  stream: _db.child('custom_foods').onValue,
                  builder: (ctx, snap) {
                    int count = 0;
                    if (snap.hasData && snap.data?.snapshot.value != null) {
                      count = (snap.data!.snapshot.value as Map).length;
                    }
                    return Text('$count ITEMS', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 10, fontWeight: FontWeight.bold));
                  },
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Members will see these foods FIRST when searching', style: TextStyle(color: Colors.white24, fontSize: 10)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _db.child('custom_foods').onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                  return const Center(child: Text('No custom foods added yet.', style: TextStyle(color: Colors.white24)));
                }
                final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
                final items = data.entries.toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final key = items[index].key;
                    final food = Map<String, dynamic>.from(items[index].value as Map);
                    return FadeInUp(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text((food['displayName'] ?? '').toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  Text('P: ${food['protein']}g · C: ${food['carbs']}g · F: ${food['fats']}g', style: const TextStyle(color: Colors.white24, fontSize: 10)),
                                ],
                              ),
                            ),
                            Text('${(food['calories'] as num).toInt()}', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w900, fontSize: 18)),
                            const SizedBox(width: 4),
                            const Text('kcal', style: TextStyle(color: Colors.white24, fontSize: 9)),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => _db.child('custom_foods/$key').remove(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
