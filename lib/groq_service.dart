import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _apiKey = 'YOUR_GROQ_API_KEY_HERE';
  static const String _model = 'llama-3.1-8b-instant';

  Future<String> getChatResponse(List<Map<String, String>> messages) async {
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
              'content': 'You are the SlimFitness Elite Guardian. You ONLY discuss: 1. Gym Workouts, 2. Nutrition/Diet, 3. Health/Recovery. If asked about ANYTHING else (politics, news, non-gym apps, general chat), you MUST politely refuse and say: "I am your dedicated Fitness Guardian. I only discuss topics that fuel your growth. Ask me about your workout or diet!" Be professional, motivating, and extremely strict about these topical boundaries.'
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
        return 'Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Request failed: $e';
    }
  }
}
