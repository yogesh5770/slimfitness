import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'groq_service.dart';
import 'nutrition_service.dart';

class AiCoachView extends StatefulWidget {
  const AiCoachView({super.key});

  @override
  State<AiCoachView> createState() => _AiCoachViewState();
}

class _AiCoachViewState extends State<AiCoachView> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  final GroqService _groqService = GroqService();
  final NutritionService _nutritionService = NutritionService();
  String _userContext = "";

  @override
  void initState() {
    super.initState();
    _loadUserContext();
  }

  void _loadUserContext() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseDatabase.instance.ref().child('users/$uid/vitals').get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      _userContext = "User Info: ${data['gender']}, ${data['weight']}kg, ${data['height']}cm, goal: ${data['goal']}. ";
    }

    // Load chat history from DB
    final chatSnap = await FirebaseDatabase.instance.ref().child('ai_chat/$uid').orderByChild('timestamp').get();
    
    if (chatSnap.exists) {
      final data = Map<String, dynamic>.from(chatSnap.value as Map);
      final sortedEntries = data.entries.toList()..sort((a, b) => (a.value['timestamp'] as num).compareTo(b.value['timestamp'] as num));
      
      final history = sortedEntries.map((e) => {
        'role': e.value['role'].toString(),
        'content': e.value['content'].toString(),
      }).toList();

      setState(() {
        _messages.addAll(history);
      });
    } else {
      // Default welcome message if no history
      final welcomeMsg = '💪 Hello! I am your SlimFitness AI Coach.\n\n🍽️ **Quick Log**: Just tell me what you ate!\nExample: "I ate 2 bananas before gym add in snacks"\n\nI\'ll automatically log it to your Diet Center with full macro tracking!';
      setState(() {
        _messages.add({'role': 'assistant', 'content': welcomeMsg});
      });
      _saveMessageToDb('assistant', welcomeMsg);
    }
  }

  void _saveMessageToDb(String role, String content) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseDatabase.instance.ref().child('ai_chat/$uid').push().set({
      'role': role,
      'content': content,
      'timestamp': ServerValue.timestamp,
    });
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _saveMessageToDb('user', text);
    _controller.clear();

    try {
      // Step 1: Check if the user wants to log food
      final parsed = await _groqService.parseFoodLog(text);

      if (parsed != null && parsed['isLog'] == true) {
        // User wants to log food!
        await _handleFoodLog(parsed);
      } else {
        // Normal chat - fitness advice
        final response = await _groqService.getChatResponse(_messages, userContext: _userContext);
        if (mounted) {
          setState(() {
            _isLoading = false;
            _messages.add({'role': 'assistant', 'content': response});
          });
          _saveMessageToDb('assistant', response);
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = 'Connection issue. Please try again.';
        setState(() {
          _isLoading = false;
          _messages.add({'role': 'assistant', 'content': errorMsg});
        });
        _saveMessageToDb('assistant', errorMsg);
      }
    }
  }

  Future<void> _handleFoodLog(Map<String, dynamic> parsed) async {
    final food = parsed['food'] as String? ?? '';
    final rawQuantity = parsed['quantity'] as String? ?? '1 serving';
    final quantity = "$rawQuantity $food".trim();
    final category = parsed['category'] as String? ?? 'snacks';

    // Show "looking up..." message
    if (mounted) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': '🔍 Looking up "$quantity"...'});
      });
    }

    // Step 2: Get nutrition from CalorieNinjas
    var results = await _nutritionService.searchFood(quantity);
    Map<String, dynamic>? nutritionData;

    if (results.isNotEmpty) {
      // Sum up all items if multiple (e.g., "2 bananas" returns one entry with doubled values)
      double totalCal = 0, totalP = 0, totalC = 0, totalF = 0;
      String name = food;
      for (var item in results) {
        totalCal += (item['calories'] as num).toDouble();
        totalP += (item['protein'] as num).toDouble();
        totalC += (item['carbs'] as num).toDouble();
        totalF += (item['fats'] as num).toDouble();
        name = item['name'] as String;
      }
      nutritionData = {
        'name': name,
        'calories': totalCal,
        'protein': totalP,
        'carbs': totalC,
        'fats': totalF,
        'serving': (results.first['serving'] as num?)?.toDouble() ?? 100.0,
      };
    } else {
      // AI fallback
      final aiResult = await _nutritionService.aiEstimate(quantity);
      if (aiResult.isNotEmpty) {
        nutritionData = aiResult;
      }
    }

    if (nutritionData == null || (nutritionData['calories'] as num) <= 0) {
      if (mounted) {
        final errorMsg = '❌ Could not find nutrition for "$food". Try being more specific (e.g., "1 cup cooked rice").';
        setState(() {
          _isLoading = false;
          _messages.removeWhere((msg) => msg['content'] == '🔍 Looking up "$quantity"...');
          _messages.add({'role': 'assistant', 'content': errorMsg});
        });
        _saveMessageToDb('assistant', errorMsg);
      }
      return;
    }

    // Step 3: Save to Firebase
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final dateKey = "${now.year}-${now.month}-${now.day}";
    final cal = (nutritionData['calories'] as num).toInt();
    final protein = (nutritionData['protein'] as num).toStringAsFixed(1);
    final carbs = (nutritionData['carbs'] as num).toStringAsFixed(1);
    final fats = (nutritionData['fats'] as num).toStringAsFixed(1);
    final serving = (nutritionData['serving'] as num?)?.toInt() ?? 100;

    await FirebaseDatabase.instance.ref()
        .child('diet_logs/$uid/$dateKey/$category')
        .push()
        .set({
      'name': quantity,
      'amount': serving,
      'calories': cal,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
      'timestamp': ServerValue.timestamp,
    });

    // Step 4: Confirm to user
    if (mounted) {
      final successMsg = '✅ **Logged to ${category.toUpperCase()}!**\n\n'
              '🍽️ $quantity\n'
              '🔥 $cal kcal\n'
              '💪 P: ${protein}g · C: ${carbs}g · F: ${fats}g\n\n'
              'Check your Diet Center to see it! Keep fueling your gains! 💪';
      setState(() {
        _isLoading = false;
        _messages.removeWhere((msg) => msg['content'] == '🔍 Looking up "$quantity"...');
        _messages.add({'role': 'assistant', 'content': successMsg});
      });
      _saveMessageToDb('assistant', successMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(
        title: const Text('AI GYM COACH', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900, fontSize: 16)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final reversedIndex = _messages.length - 1 - index;
                final msg = _messages[reversedIndex];
                final isUser = msg['role'] == 'user';

                return FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(18),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                      decoration: BoxDecoration(
                        color: isUser ? Theme.of(context).primaryColor : const Color(0xFF161B22),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(25),
                          topRight: const Radius.circular(25),
                          bottomLeft: Radius.circular(isUser ? 25 : 0),
                          bottomRight: Radius.circular(isUser ? 0 : 25),
                        ),
                      ),
                      child: Text(
                        msg['content'] ?? '',
                        style: TextStyle(color: isUser ? Colors.black : Colors.white, fontSize: 15, fontWeight: isUser ? FontWeight.bold : FontWeight.normal),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  const Text('COACH IS THINKING...', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Log food or ask about fitness...',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF161B22),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  radius: 26,
                  child: IconButton(icon: const Icon(Icons.send_rounded, color: Colors.black), onPressed: _sendMessage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
