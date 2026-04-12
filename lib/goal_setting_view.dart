import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:animate_do/animate_do.dart';
import 'vitals_service.dart';

class GoalSettingView extends StatefulWidget {
  const GoalSettingView({super.key});

  @override
  State<GoalSettingView> createState() => _GoalSettingViewState();
}

class _GoalSettingViewState extends State<GoalSettingView> {
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;

  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  final _idealWeightController = TextEditingController();
  String _selectedGoal = 'maintenance';
  String _selectedGender = 'male';
  String _selectedActivity = 'moderate';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentVitals();
  }

  void _loadCurrentVitals() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await _db.child('users/$uid/vitals').get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        _weightController.text = (data['weight'] ?? '').toString();
        _heightController.text = (data['height'] ?? '').toString();
        _ageController.text = (data['age'] ?? '').toString();
        _idealWeightController.text = (data['idealWeight'] ?? '').toString();
        _selectedGoal = data['goal'] ?? 'maintenance';
        _selectedGender = data['gender'] ?? 'male';
        _selectedActivity = data['activityLevel'] ?? 'moderate';
      });
    }
  }

  void _saveVitals() async {
    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);
    final age = int.tryParse(_ageController.text);
    final idealWeight = double.tryParse(_idealWeightController.text) ?? 0.0;

    if (weight == null || height == null || age == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid numbers')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uid = _auth.currentUser?.uid;
      
      // Calculate Targets
      final calories = VitalsService.calculateDailyCalories(
        weight: weight,
        heightCm: height,
        age: age,
        isMale: _selectedGender == 'male',
        goal: _selectedGoal,
        activityLevel: _selectedActivity,
      );

      final macros = VitalsService.calculateMacros(
        totalCalories: calories,
        weight: weight,
        goal: _selectedGoal,
      );

      await _db.child('users/$uid/vitals').set({
        'weight': weight,
        'height': height,
        'age': age,
        'gender': _selectedGender,
        'goal': _selectedGoal,
        'activityLevel': _selectedActivity,
        'idealWeight': idealWeight,
        'dailyCalorieTarget': calories,
        'proteinTarget': macros['protein'],
        'carbTarget': macros['carbs'],
        'fatTarget': macros['fats'],
        'lastUpdated': ServerValue.timestamp,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Elite Goals Setup Complete!')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(
        title: const Text('GOAL SETTING', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900, fontSize: 16)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInLeft(
              child: const Text(
                'DEFINE YOUR ELITE GOAL',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
            const SizedBox(height: 8),
            FadeInLeft(
              delay: const Duration(milliseconds: 200),
              child: const Text(
                'We will calculate your perfect Macro-split based on your vitals.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
            const SizedBox(height: 40),
            
            _buildInputLabel('CURRENT WEIGHT (KG)'),
            _buildTextField(_weightController, 'e.g. 85.5', Icons.monitor_weight_outlined),
            
            const SizedBox(height: 24),
            _buildInputLabel('HEIGHT (CM)'),
            _buildTextField(_heightController, 'e.g. 175', Icons.height_rounded),
            
            const SizedBox(height: 24),
            _buildInputLabel('AGE'),
            _buildTextField(_ageController, 'e.g. 25', Icons.cake_outlined),

            const SizedBox(height: 32),
            Row(
              children: [
                _buildChoiceChip('male', 'MALE', (v) => _selectedGender = v, _selectedGender),
                const SizedBox(width: 12),
                _buildChoiceChip('female', 'FEMALE', (v) => _selectedGender = v, _selectedGender),
              ],
            ),

            const SizedBox(height: 32),
            _buildInputLabel('MANUAL IDEAL WEIGHT (KG)'),
            _buildTextField(_idealWeightController, 'Optional target weight', Icons.star_border_rounded),

            const SizedBox(height: 32),
            _buildInputLabel('ACTIVITY LEVEL'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChoiceChip('sedentary', 'SEDENTARY', (v) => _selectedActivity = v, _selectedActivity),
                  const SizedBox(width: 12),
                  _buildChoiceChip('moderate', 'MODERATE', (v) => _selectedActivity = v, _selectedActivity),
                  const SizedBox(width: 12),
                  _buildChoiceChip('active', 'ACTIVE', (v) => _selectedActivity = v, _selectedActivity),
                  const SizedBox(width: 12),
                  _buildChoiceChip('athlete', 'ATHLETE', (v) => _selectedActivity = v, _selectedActivity),
                ],
              ),
            ),

            const SizedBox(height: 32),
            _buildInputLabel('PRIMARY GOAL'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildGoalChip('fat_loss', 'FAT LOSS', Icons.local_fire_department_rounded),
                _buildGoalChip('maintenance', 'MAINTAIN', Icons.balance_rounded),
                _buildGoalChip('muscle_gain', 'MUSCLE GAIN', Icons.fitness_center_rounded),
              ],
            ),

            const SizedBox(height: 60),
            FadeInUp(
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveVitals,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('CALCULATE ELITE PLAN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white12),
          prefixIcon: Icon(icon, color: Theme.of(context).primaryColor.withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String value, String label, Function(String) onSelect, String currentVal) {
    bool isSelected = currentVal == value;
    return GestureDetector(
      onTap: () => setState(() => onSelect(value)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? Theme.of(context).primaryColor : Colors.white10),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white38, fontWeight: FontWeight.bold, fontSize: 11)),
      ),
    );
  }

  Widget _buildGoalChip(String value, String label, IconData icon) {
    bool isSelected = _selectedGoal == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedGoal = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Theme.of(context).primaryColor : Colors.white10, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? Theme.of(context).primaryColor : Colors.white24),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white24, fontWeight: FontWeight.w900, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
