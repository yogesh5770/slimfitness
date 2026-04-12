import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'groq_service.dart';

class NutritionService {
  static const String _apiKey = 'Cw3B3g9Gzp1hhbX/gWLfHQ==lWI7yFhiEs3oq1jW';
  static const String _baseUrl = 'https://api.calorieninjas.com/v1/nutrition';
  final GroqService _groqService = GroqService();
  final _db = FirebaseDatabase.instance.ref();

  /// Triple search: Custom DB → CalorieNinjas → AI Fallback
  Future<List<Map<String, dynamic>>> searchFood(String query) async {
    if (query.length < 2) return [];

    // 1. Check custom food database FIRST (Tamil Nadu foods)
    final customResults = await _searchCustomDb(query);
    if (customResults.isNotEmpty) return customResults;

    // 2. Pure AI Elite Estimation
    // Bypass CalorieNinjas entirely due to western-centric inaccuracy on local cuisines.
    final aiResult = await aiEstimate(query);
    if (aiResult.isNotEmpty) return [aiResult];

    return [];
  }

  /// Searches the admin-curated custom food database
  Future<List<Map<String, dynamic>>> _searchCustomDb(String query) async {
    try {
      final snap = await _db.child('custom_foods').get();
      if (!snap.exists) return [];

      final data = Map<String, dynamic>.from(snap.value as Map);
      final lowerQuery = query.toLowerCase();

      return data.values
          .where((item) => (item['name'] as String).contains(lowerQuery))
          .map((item) => {
            'name': item['displayName'] ?? item['name'],
            'calories': (item['calories'] as num).toDouble(),
            'protein': (item['protein'] as num).toDouble(),
            'carbs': (item['carbs'] as num).toDouble(),
            'fats': (item['fats'] as num).toDouble(),
            'fiber': 0.0,
            'sugar': 0.0,
            'sodium': 0.0,
            'serving': 100.0,
            'source': 'custom_db',
          })
          .toList();
    } catch (e) {
      print("CUSTOM DB SEARCH ERROR: $e");
    }
    return [];
  }

  /// CalorieNinjas NLP search
  Future<List<Map<String, dynamic>>> _searchCalorieNinjas(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?query=${Uri.encodeComponent(query)}'),
        headers: {'X-Api-Key': _apiKey},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        return items.map((item) => {
          'name': item['name'] ?? 'Unknown',
          'calories': (item['calories'] as num?)?.toDouble() ?? 0.0,
          'protein': (item['protein_g'] as num?)?.toDouble() ?? 0.0,
          'carbs': (item['carbohydrates_total_g'] as num?)?.toDouble() ?? 0.0,
          'fats': (item['fat_total_g'] as num?)?.toDouble() ?? 0.0,
          'fiber': (item['fiber_g'] as num?)?.toDouble() ?? 0.0,
          'sugar': (item['sugar_g'] as num?)?.toDouble() ?? 0.0,
          'sodium': (item['sodium_mg'] as num?)?.toDouble() ?? 0.0,
          'serving': (item['serving_size_g'] as num?)?.toDouble() ?? 100.0,
          'source': 'calorieninjas',
        }).toList();
      }
    } catch (e) {
      print("CALORIENINJAS SEARCH ERROR: $e");
    }
    return [];
  }

  /// AI fallback for foods not in any database
  Future<Map<String, dynamic>> aiEstimate(String foodName) async {
    try {
      final result = await _groqService.getNutritionEstimate(foodName);
      if (result.isNotEmpty) {
        return {
          'name': foodName,
          'calories': result['calories'] ?? 0.0,
          'protein': result['protein'] ?? 0.0,
          'carbs': result['carbs'] ?? 0.0,
          'fats': result['fats'] ?? 0.0,
          'fiber': 0.0, 'sugar': 0.0, 'sodium': 0.0,
          'serving': result['serving'] ?? 100.0,
          'source': 'ai_estimate',
        };
      }
    } catch (e) {
      print("AI ESTIMATE FALLBACK ERROR: $e");
    }
    return {};
  }
}
