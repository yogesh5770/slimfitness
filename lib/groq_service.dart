import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static final String _apiKey = utf8.decode(base64.decode('WjNOclgxRXpYelphV2xOamVqQjNkbklKYTB0MmVEUk9WWRrZVdJekZsWjVaRmxzTlZkak4xVmpUemR0WW1OWmJWSWpNRU9HUnpOTVdsZGNqUT0='));
  static const String _model = 'llama-3.1-8b-instant';

  Future<String> getChatResponse(List<Map<String, String>> messages, {String userContext = ""}) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are the SlimFitness AI Coach — a friendly, knowledgeable fitness and nutrition expert. $userContext\n\nYou happily answer ALL questions about:\n- Calories, macros, nutrition info for any food (Indian, Tamil Nadu, global)\n- Gym workouts, exercises, muscle groups\n- Diet plans, meal suggestions, weight loss/gain tips\n- Health, recovery, supplements\n\nWhen someone asks about a food (like "2 poori calories"), give them the calorie and macro breakdown clearly.\n\nOnly refuse topics completely unrelated to health/fitness (like politics, movies, etc). Be motivating and supportive, never overly strict.'
            },
            ...messages
          ],
          'temperature': 0.7,
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ?? 'No response received.';
      } else {
        print("GROQ API ERROR: ${response.statusCode} - ${response.body}");
        return 'I am having trouble connecting to the Elite Network (Error ${response.statusCode}).';
      }
    } catch (e) {
      print("GROQ REQUEST FAILED: $e");
      return 'Request failed. Check your internet or API key.';
    }
  }

  Future<Map<String, double>> getNutritionEstimate(String foodName) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a professional nutritionist. Provide the estimated TOTAL calories, protein, carbs, and fats for the SPECIFIC amount of food the user requests (e.g., if they ask for "1 plate chicken rice", give stats for the whole plate). Also estimate the total weight in grams. Return ONLY a JSON object in this format: {"calories": 0.0, "protein": 0.0, "carbs": 0.0, "fats": 0.0, "serving_size_grams": 0}. No text. Output valid JSON only.'
            },
            {'role': 'user', 'content': foodName}
          ],
          'temperature': 0.1,
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'].toString().trim();
        // Extract JSON if AI adds extra text
        final jsonStart = content.indexOf('{');
        final jsonEnd = content.lastIndexOf('}') + 1;
        final jsonStr = content.substring(jsonStart, jsonEnd);
        final nutrition = jsonDecode(jsonStr);
        return {
          'calories': (nutrition['calories'] as num).toDouble(),
          'protein': (nutrition['protein'] as num).toDouble(),
          'carbs': (nutrition['carbs'] as num).toDouble(),
          'fats': (nutrition['fats'] as num).toDouble(),
          'serving': (nutrition['serving_size_grams'] as num?)?.toDouble() ?? 100.0,
        };
      }
    } catch (e) {
      print("AI ESTIMATION ERROR: $e");
    }
    return {};
  }

  /// Parses natural language like "I ate 2 bananas add in snacks"
  /// Returns structured data: {food, quantity, category, isLog}
  Future<Map<String, dynamic>?> parseFoodLog(String userMessage) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': '''You are a food log detector. Your ONLY job is to decide if the user wants to LOG/SAVE food to their diet tracker.

Return {"isLog": true} ONLY when the user EXPLICITLY says to ADD or LOG food using words like:
- "add in breakfast/lunch/snacks/dinner"
- "log this in breakfast"
- "save to lunch"
- "add to dinner"
- "I ate X add in Y" (where Y is a meal category)

Return {"isLog": false} for EVERYTHING else, including:
- "2 poori calories" → NOT a log, just asking info
- "how many calories in dosa" → NOT a log
- "I ate 2 bananas" (no meal category mentioned) → NOT a log
- Any fitness/gym questions → NOT a log

Only return {"isLog": true} when you see BOTH a food AND an explicit meal category (breakfast/lunch/snacks/dinner).

If isLog is true, return:
{"isLog": true, "food": "ONLY the exact food name", "quantity": "ONLY the measurement/amount (e.g. '1 bowl', '2', '200g'). If none mentioned, return '1 serving'", "category": "breakfast|lunch|snacks|dinner"}

Return ONLY JSON, no explanation.'''
            },
            {'role': 'user', 'content': userMessage}
          ],
          'temperature': 0.1,
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'].toString().trim();
        final jsonStart = content.indexOf('{');
        final jsonEnd = content.lastIndexOf('}') + 1;
        if (jsonStart >= 0 && jsonEnd > jsonStart) {
          final parsed = jsonDecode(content.substring(jsonStart, jsonEnd));
          return Map<String, dynamic>.from(parsed);
        }
      }
    } catch (e) {
      print("FOOD LOG PARSE ERROR: $e");
    }
    return null;
  }

  /// Scientific AI Calibration for Steps
  Future<double> getStepCalibrationFactor({
    required double weightKg,
    required double heightCm,
    required int age,
  }) async {
    final prompt = """
    As an elite fitness scientist, calculate the scientific "Calories Per Step" multiplier for this individual.
    Biometrics: Weight: ${weightKg}kg, Height: ${heightCm}cm, Age: $age.
    
    Standard walk (3 mph) MET is 3.5. 
    Use the formula: (MET * 3.5 * weight) / 200 = Kcal/min.
    Assuming 100 steps per minute, calculate Kcal Per Step.
    
    Return ONLY a JSON object: {"factor": decimal}
    """;

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': [
            {'role': 'system', 'content': 'You are a calorie calculation engine. Return JSON only.'},
            {'role': 'user', 'content': prompt},
          ],
          'response_format': {'type': 'json_object'},
        }),
      );

      final decoded = jsonDecode(response.body);
      final content = jsonDecode(decoded['choices'][0]['message']['content']);
      return (content['factor'] as num).toDouble();
    } catch (e) {
      print("ERROR IN STEP CALIBRATION: $e");
      return 0.04; // Fallback to safe average
    }
  }

  /// Scientific Biometric Burn Estimation
  Future<int> calculateWorkoutBurn({
    required String workoutName,
    required String durationOrSets,
    required double weightKg,
    required double heightCm,
    required int age,
  }) async {
    final prompt = """
    As an elite fitness scientist, estimate the calories burned for this activity.
    Activity: $workoutName
    Intensity/Duration: $durationOrSets
    User Biometrics: Weight: ${weightKg}kg, Height: ${heightCm}cm, Age: $age.
    
    Calculate based on MET values. Return ONLY a JSON object: {"calories": integer}
    """;

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': [
            {'role': 'system', 'content': 'You are a calorie calculation engine. Return JSON only.'},
            {'role': 'user', 'content': prompt},
          ],
          'response_format': {'type': 'json_object'},
        }),
      );

      final decoded = jsonDecode(response.body);
      final contentContent = decoded['choices'][0]['message']['content'].toString().trim();
      final content = jsonDecode(contentContent);
      return (content['calories'] as num).toInt();
    } catch (e) {
      print("ERROR IN AI BURN CALCULATION: $e");
      return 0;
    }
  }
}
