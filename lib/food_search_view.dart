import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'nutrition_service.dart';
import 'food_details_view.dart';

class FoodSearchView extends StatefulWidget {
  const FoodSearchView({super.key});

  @override
  State<FoodSearchView> createState() => _FoodSearchViewState();
}

class _FoodSearchViewState extends State<FoodSearchView> {
  final NutritionService _nutritionService = NutritionService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _usedAiFallback = false;
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().length > 1) {
        _performSearch(query.trim());
      } else {
        setState(() { _results = []; _usedAiFallback = false; });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() { _isLoading = true; _usedAiFallback = false; });
    try {
      var results = await _nutritionService.searchFood(query);

      // AI Fallback: If CalorieNinjas returns nothing, use AI
      if (results.isEmpty) {
        final aiResult = await _nutritionService.aiEstimate(query);
        if (aiResult.isNotEmpty) {
          results = [aiResult];
          _usedAiFallback = true;
        }
      }

      if (mounted) {
        setState(() { _results = results; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(
        title: const Text('SEARCH FOOD', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900, fontSize: 16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Type food name (e.g. Dosa, Idli)...',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
                filled: true,
                fillColor: const Color(0xFF161B22),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                suffixIcon: _isLoading
                    ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : null,
              ),
            ),
          ),
          if (_usedAiFallback)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 14),
                    SizedBox(width: 8),
                    Text('AI ESTIMATED — not found in database', style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _results.isEmpty && !_isLoading
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _results.length,
                    itemBuilder: (context, index) => _buildResultCard(_results[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_outlined, size: 64, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          const Text('RESULTS APPEAR AS YOU TYPE', style: TextStyle(color: Colors.white12, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? 'Unknown';
    final cal = (item['calories'] as num).toInt();
    final isAi = item['source'] == 'ai_estimate';

    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(20)),
        child: ListTile(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FoodDetailsView(foodData: item))),
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: isAi ? Colors.blueAccent.withOpacity(0.15) : Theme.of(context).primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isAi ? Icons.auto_awesome : Icons.restaurant_rounded,
              color: isAi ? Colors.blueAccent : Theme.of(context).primaryColor,
              size: 22,
            ),
          ),
          title: Text(name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'P: ${(item['protein'] as num).toStringAsFixed(1)}g · C: ${(item['carbs'] as num).toStringAsFixed(1)}g · F: ${(item['fats'] as num).toStringAsFixed(1)}g',
              style: const TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$cal', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w900, fontSize: 18)),
              const Text('kcal', style: TextStyle(color: Colors.white24, fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }
}
