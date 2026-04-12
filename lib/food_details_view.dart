import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:animate_do/animate_do.dart';

class FoodDetailsView extends StatefulWidget {
  final Map<String, dynamic> foodData;
  const FoodDetailsView({super.key, required this.foodData});

  @override
  State<FoodDetailsView> createState() => _FoodDetailsViewState();
}

class _FoodDetailsViewState extends State<FoodDetailsView> {
  double _amount = 100;
  String _selectedSlot = 'breakfast';
  final List<String> _slots = ['breakfast', 'lunch', 'snacks', 'dinner'];

  @override
  Widget build(BuildContext context) {
    final name = widget.foodData['name'] ?? 'Unknown';
    final image = widget.foodData['image'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(title: const Text('ADD TO DIET', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900, fontSize: 16))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            FadeInDown(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(30)),
                child: Column(
                  children: [
                    if (image != null)
                      ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(image, height: 120, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.fastfood_rounded, size: 50))),
                    const SizedBox(height: 20),
                    Text(name.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    const Text('PRECISE SPOONACULAR DATA', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 9)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            _buildMacroCard(),
            const SizedBox(height: 30),
            _buildSlotSelector(),
            const SizedBox(height: 30),
            _buildAmountSlider(),
            const SizedBox(height: 50),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroCard() {
    double factor = _amount / 100;
    final calories = (widget.foodData['calories'] as num) * factor;
    final protein = (widget.foodData['protein'] as num) * factor;
    final carbs = (widget.foodData['carbs'] as num) * factor;
    final fats = (widget.foodData['fats'] as num) * factor;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMacroItem('CALORIES', calories.toInt().toString(), 'kcal'),
          _buildMacroItem('PROTEIN', protein.toStringAsFixed(1), 'g'),
          _buildMacroItem('CARBS', carbs.toStringAsFixed(1), 'g'),
          _buildMacroItem('FATS', fats.toStringAsFixed(1), 'g'),
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        Text(unit, style: const TextStyle(color: Colors.white24, fontSize: 9)),
      ],
    );
  }

  Widget _buildSlotSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('LOG THIS MEAL AS:', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _slots.map((slot) {
            final isSelected = _selectedSlot == slot;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedSlot = slot),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).primaryColor : const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(slot.toUpperCase(), style: TextStyle(color: isSelected ? Colors.black : Colors.white30, fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAmountSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('TOTAL PORTION (GRAMS)', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            Text('${_amount.toInt()} g', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w900, fontSize: 20)),
          ],
        ),
        Slider(
          value: _amount,
          min: 10, max: 2000,
          divisions: 199,
          activeColor: Theme.of(context).primaryColor,
          inactiveColor: Colors.white10,
          onChanged: (val) => setState(() => _amount = val),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 65,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        onPressed: _saveToFirebase,
        child: const Text('CONFIRM ENTRY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 16)),
      ),
    );
  }

  void _saveToFirebase() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final dateKey = "${now.year}-${now.month}-${now.day}";
    double factor = _amount / 100;

    final logData = {
      'name': widget.foodData['name'] ?? 'Unknown',
      'amount': _amount.toInt(),
      'calories': ((widget.foodData['calories'] as num) * factor).toInt(),
      'protein': ((widget.foodData['protein'] as num) * factor).toStringAsFixed(1),
      'carbs': ((widget.foodData['carbs'] as num) * factor).toStringAsFixed(1),
      'fats': ((widget.foodData['fats'] as num) * factor).toStringAsFixed(1),
      'timestamp': ServerValue.timestamp,
    };

    await FirebaseDatabase.instance.ref()
        .child('diet_logs/$uid/$dateKey/$_selectedSlot')
        .push()
        .set(logData);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meal logged successfully!')));
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    }
  }
}
