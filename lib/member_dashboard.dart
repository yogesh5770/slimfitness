import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'ai_coach_view.dart';
import 'category_list_view.dart';
import 'exercise_video_view.dart';
import 'profile_view.dart';
import 'notification_service.dart';
import 'server_time_service.dart';
import 'vitals_service.dart';
import 'goal_setting_view.dart';
import 'caloric_logic_service.dart';
import 'streak_service.dart';
import 'weight_chart_view.dart';
import 'step_service.dart';
import 'groq_service.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class MemberDashboard extends StatefulWidget {
  const MemberDashboard({super.key});

  @override
  State<MemberDashboard> createState() => _MemberDashboardState();
}

class _MemberDashboardState extends State<MemberDashboard> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    EliteHubView(),
    FoodLoggerView(),
    MemberChatView(),
    ProfileView(),
  ];

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  void _initNotifications() async {
    final notificationService = NotificationService();
    await notificationService.init();

    final database = FirebaseDatabase.instance.ref();
    database.child('group_chat').limitToLast(1).onChildAdded.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final isAdmin = data['isAdmin'] == true;
        final senderId = data['senderId'] as String?;
        final currentUid = FirebaseAuth.instance.currentUser?.uid;

        if (isAdmin && senderId != currentUid && _currentIndex != 2) {
          notificationService.showNotification(
            title: 'COUNCIL ANNOUNCEMENT',
            body: data['text'] ?? 'New message from owner',
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(
        centerTitle: true,
        title: const Text('SLIM FITNESS', style: TextStyle(letterSpacing: 6, fontWeight: FontWeight.w900, fontSize: 18)),
        actions: [
          FadeInDown(
            child: IconButton(
              icon: const Icon(Icons.smart_toy_rounded),
              color: Theme.of(context).primaryColor,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiCoachView())),
            ),
          )
        ],
      ),
      body: SafeArea(
        top: true,
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF0A0C10),
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.white24,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
        unselectedLabelStyle: const TextStyle(fontSize: 10, letterSpacing: 1),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bolt_rounded), label: 'HUB'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu_rounded), label: 'DIET'),
          BottomNavigationBarItem(icon: Icon(Icons.forum_rounded), label: 'CHAT'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'PROFILE'),
        ],
      ),
    );
  }
}

class EliteHubView extends StatefulWidget {
  const EliteHubView({super.key});

  @override
  State<EliteHubView> createState() => _EliteHubViewState();
}

class _EliteHubViewState extends State<EliteHubView> {
  final _database = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  final _timeService = ServerTimeService();
  final _caloricLogic = CaloricLogicService();
  final _streakService = StreakService();
  int _penalty = 0;
  int _streak = 0;
  int _waterCount = 0;
  final _stepService = StepService();
  final _groq = GroqService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final penalty = await _caloricLogic.getYesterdayPenalty();
    final streak = await _streakService.updateAndGetStreak();
    await _loadWater();
    _checkStepCalibration();
    if (mounted) setState(() { _penalty = penalty; _streak = streak; });
  }

  Future<void> _checkStepCalibration() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final vitalsSnap = await _database.child('users/$uid/vitals').get();
    if (!vitalsSnap.exists) return;

    final vitals = Map<String, dynamic>.from(vitalsSnap.value as Map);
    if (vitals.containsKey('stepMultiplier')) return;

    // Trigger AI Calibration for the first time or if missing
    final weight = (vitals['weight'] as num?)?.toDouble() ?? 70.0;
    final height = (vitals['height'] as num?)?.toDouble() ?? 170.0;
    final age = (vitals['age'] as num?)?.toInt() ?? 25;

    final factor = await _groq.getStepCalibrationFactor(
      weightKg: weight,
      heightCm: height,
      age: age,
    );

    // Save to Cloud & Local Service
    await _database.child('users/$uid/vitals/stepMultiplier').set(factor);
    _stepService.updateMultiplier(factor);
    
    debugPrint("ELITE AI: Step Calibration Factor Set to $factor");
  }

  Future<void> _loadWater() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final now = DateTime.now();
    final key = "${now.year}-${now.month}-${now.day}";
    final snap = await _database.child('water_logs/$uid/$key').get();
    if (snap.exists && mounted) setState(() => _waterCount = (snap.value as num).toInt());
  }

  void _addWater() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final now = DateTime.now();
    final key = "${now.year}-${now.month}-${now.day}";
    final newCount = _waterCount + 1;
    await _database.child('water_logs/$uid/$key').set(newCount);
    if (mounted) setState(() => _waterCount = newCount);
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Session expired.'));

    return StreamBuilder<DatabaseEvent>(
      stream: _database.child('users/$uid').onValue,
      builder: (context, userSnapshot) {
        return StreamBuilder<DatabaseEvent>(
          stream: _database.child('diet_logs/$uid/${_getDateKey()}').onValue,
          builder: (context, dietSnapshot) {
            return StreamBuilder<DatabaseEvent>(
              stream: _database.child('steps/$uid/${_getDateKey()}').onValue,
              builder: (context, stepSnapshot) {
                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHealthSummary(userSnapshot, dietSnapshot, stepSnapshot),
                            const SizedBox(height: 32),
                            _buildSectionTitle("TODAY'S WORKOUT"),
                          ],
                        ),
                      ),
                    ),
                    _buildWorkoutList(uid, (userSnapshot.data?.snapshot.value as Map?)?['vitals'] ?? {}),
                  ],
                );
              }
            );
          },
        );
      },
    );
  }

  String _getDateKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month}-${now.day}";
  }

  Widget _buildSectionTitle(String title) {
    return FadeInLeft(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
          Container(height: 2, width: 40, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(10))),
        ],
      ),
    );
  }

  Widget _buildHealthSummary(AsyncSnapshot<DatabaseEvent> userSnap, AsyncSnapshot<DatabaseEvent> dietSnap, AsyncSnapshot<DatabaseEvent> stepSnap) {
    if (!userSnap.hasData || userSnap.data?.snapshot.value == null) return const SizedBox();
    
    final userData = Map<String, dynamic>.from(userSnap.data!.snapshot.value as Map);
    final vitals = userData['vitals'] != null ? Map<String, dynamic>.from(userData['vitals'] as Map) : null;

    if (vitals == null) return _buildEmptyVitalsCard();

    int consumed = 0;
    if (dietSnap.hasData && dietSnap.data?.snapshot.value != null) {
      final rawData = dietSnap.data!.snapshot.value;
      if (rawData is Map) {
        for (var entry in rawData.values) {
          if (entry is Map) {
            if (entry.containsKey('calories')) {
              consumed += (entry['calories'] as num).toInt();
            } else {
              for (var mealItem in entry.values) {
                if (mealItem is Map && mealItem.containsKey('calories')) {
                  consumed += (mealItem['calories'] as num).toInt();
                }
              }
            }
          }
        }
      }
    }

    // Step Burn Adjustment
    int stepCount = 0;
    double stepBurn = 0;
    if (stepSnap.hasData && stepSnap.data?.snapshot.value != null) {
      final data = stepSnap.data!.snapshot.value as Map;
      stepCount = (data['count'] ?? 0) as int;
      stepBurn = (data['caloriesBurned'] ?? 0.0).toDouble();
      consumed -= stepBurn.toInt(); 
    }

    final baseTarget = (vitals['dailyCalorieTarget'] as num?)?.toInt() ?? 2000;
    final effectiveTarget = baseTarget - _penalty;
    final weight = (vitals['weight'] as num?)?.toDouble() ?? 0.0;
    final height = (vitals['height'] as num?)?.toDouble() ?? 0.0;
    final bmi = VitalsService.calculateBMI(weight, height);
    final bmiStatus = VitalsService.getBMIStatus(bmi);

    final progress = (consumed / effectiveTarget).clamp(0.0, 1.0);

    return Column(
      children: [
        FadeInDown(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(30)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('NET CALORIE BALANCE', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      const SizedBox(height: 4),
                      if (_penalty > 0)
                        Text('YESTERDAY OVERAGE: -$_penalty', style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('${consumed < 0 ? 0 : consumed} / $effectiveTarget', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('AVAILABLE: ${effectiveTarget - consumed} kcal', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('🦶 $stepCount STEPS | -${stepBurn.toStringAsFixed(1)} KCAL REDUCED', style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 80, height: 80,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(consumed > effectiveTarget ? Colors.redAccent : Theme.of(context).primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildMiniMetric('BMI', bmi.toStringAsFixed(1), bmiStatus)),
            const SizedBox(width: 16),
            Expanded(child: _buildMiniMetric('GOAL', vitals['goal'].toString().toUpperCase(), 'ACTIVE')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMiniMetric(
                'FAT %',
                '${VitalsService.calculateBodyFat(bmi, (vitals['age'] as num?)?.toInt() ?? 25, vitals['gender'] == 'male').toStringAsFixed(1)}%',
                'ESTIMATED',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMiniMetric(
                'IDEAL WT',
                '${VitalsService.calculateIdealWeight((vitals['height'] as num?)?.toDouble() ?? 170.0, vitals['gender'] == 'male').toStringAsFixed(1)} kg',
                'TARGET',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Water + Streak + Weight Row
        Row(
          children: [
            // Water Tracker
            Expanded(
              child: GestureDetector(
                onTap: _showWaterDialog,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      Icon(Icons.water_drop, color: Colors.cyanAccent.withOpacity(0.7), size: 28),
                      const SizedBox(height: 8),
                      Text('$_waterCount / 8', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const Text('GLASSES', style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Streak
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    Text(_streak > 0 ? '🔥' : '❄️', style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 8),
                    Text('$_streak', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const Text('DAY STREAK', style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Weight Chart
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeightChartView())),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      Icon(Icons.show_chart, color: Theme.of(context).primaryColor, size: 28),
                      const SizedBox(height: 8),
                      const Text('WEIGHT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      const Text('CHART', style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyVitalsCard() {
    return FadeInDown(
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.analytics_outlined, size: 40, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('SET YOUR ELITE GOALS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 8),
            const Text('Unlock BMI, Macros, and Calorie tracking.', style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalSettingView())),
              child: const Text('SETUP NOW'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, String status) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(status, style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showWaterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('HYDRATION TRACKER', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Log internal hydration to maintain metabolic efficiency.', style: TextStyle(color: Colors.white38, fontSize: 10)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), onPressed: () {
                  if (_waterCount > 0) { _updateWater(_waterCount - 1); Navigator.pop(context); }
                }),
                Text('$_waterCount', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent), onPressed: () {
                  _updateWater(_waterCount + 1); Navigator.pop(context);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateWater(int val) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final key = _getDateKey();
    await _database.child('water_logs/$uid/$key').set(val);
    if (mounted) setState(() => _waterCount = val);
  }

  void _finishWorkout(String uid, String key, Map item, Map vitals) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final weight = (vitals['weight'] as num?)?.toDouble() ?? 70.0;
    final height = (vitals['height'] as num?)?.toDouble() ?? 170.0;
    final age = (vitals['age'] as num?)?.toInt() ?? 25;

    final burn = await _groq.calculateWorkoutBurn(
      workoutName: item['name'],
      durationOrSets: item['isTimed'] ? "${item['minutes']} mins" : "${item['sets']}x${item['reps']}",
      weightKg: weight,
      heightCm: height,
      age: age,
    );

    await _database.child('assigned_workouts/$uid/$key').update({'status': 'done', 'burn': burn});
    
    // Inject into history as Negative Calories
    await _database.child('diet_logs/$uid/${_getDateKey()}/workouts/$key').set({
      'name': 'ACTIVITY: ${item['name']}',
      'calories': -burn,
      'timestamp': ServerValue.timestamp,
    });

    if (mounted) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('ELITE: WORKOUT FINISHED (+ BUILT IN BURN: -$burn kcal)'),
        backgroundColor: Theme.of(context).primaryColor,
      ));
    }
  }

  Widget _buildWorkoutList(String uid, Map vitals) {
    return StreamBuilder<DatabaseEvent>(
      stream: _database.child('assigned_workouts/$uid').onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
        List<MapEntry<dynamic, dynamic>> todayItems = [];
        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          final Map<dynamic, dynamic> data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          todayItems = data.entries.where((entry) => _timeService.isToday(entry.value['timestamp'] ?? 0)).toList();
        }
        if (todayItems.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Opacity(
                opacity: 0.1,
                child: Column(
                  children: [
                    const Icon(Icons.timer_outlined, size: 48),
                    const SizedBox(height: 16),
                    const Text('AWAITING WORKOUT ASSIGNMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ],
                ),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = todayItems[index].value as Map;
                final key = todayItems[index].key;
                final isDone = item['status'] == 'done';
                return FadeInUp(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: isDone ? Colors.white.withOpacity(0.01) : const Color(0xFF161B22), borderRadius: BorderRadius.circular(20)),
                    child: ListTile(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseVideoView(exerciseName: item['name']!, videoUrl: item['link']!))),
                      title: Text(item['name'] ?? '', style: TextStyle(color: isDone ? Colors.white24 : Colors.white, fontWeight: FontWeight.bold)),
                      trailing: isDone 
                        ? Text('-${item['burn']} kcal', style: const TextStyle(color: Colors.white24, fontWeight: FontWeight.bold))
                        : TextButton(
                            onPressed: () => _finishWorkout(uid, key, item, vitals),
                            child: const Text('FINISH', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                      leading: Icon(isDone ? Icons.check_circle : Icons.circle_outlined, color: isDone ? Theme.of(context).primaryColor : Colors.white24),
                    ),
                  ),
                );
              },
              childCount: todayItems.length,
            ),
          ),
        );
      },
    );
  }
}

class FoodLoggerView extends StatefulWidget {
  const FoodLoggerView({super.key});

  @override
  State<FoodLoggerView> createState() => _FoodLoggerViewState();
}

class _FoodLoggerViewState extends State<FoodLoggerView> {
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  final _groq = GroqService();

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    await _speech.initialize();
  }

  void _startListening() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      setState(() => _isListening = true);
      await _speech.listen(onResult: (val) {
        if (val.finalResult) {
          setState(() => _isListening = false);
          _processVoiceLog(val.recognizedWords);
        }
      });
    }
  }

  void _processVoiceLog(String text) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final logData = await _groq.parseFoodLog(text);
    if (logData != null && logData['isLog'] == true) {
      final nutrition = await _groq.getNutritionEstimate(logData['food']);
      final uid = _auth.currentUser?.uid;
      final dateKey = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
      
      await _db.child('diet_logs/$uid/$dateKey/${logData['category']}').push().set({
        'name': logData['food'],
        'calories': nutrition['calories'],
        'protein': nutrition['protein'],
        'carbs': nutrition['carbs'],
        'fats': nutrition['fats'],
        'serving': nutrition['serving'],
        'timestamp': ServerValue.timestamp,
      });

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ELITE VOICE: LOGGED ${logData['food']} (+${nutrition['calories']} kcal)'),
          backgroundColor: Colors.greenAccent,
        ));
      }
    } else {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('COULD NOT PARSE LOG. TRY: "Add 2 eggs to breakfast"')));
      }
    }
  }

  Widget _buildAdminDietSection(String uid) {
    return StreamBuilder<DatabaseEvent>(
      stream: _db.child('users/$uid/assigned_diet').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) return const SizedBox();
        final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final plan = data['plan'] as String? ?? '';
        if (plan.isEmpty) return const SizedBox();

        return FadeInDown(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.greenAccent.withOpacity(0.1), Colors.black26]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.2))
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.restaurant_menu, color: Colors.greenAccent, size: 16),
                    const SizedBox(width: 8),
                    const Text('ADMIN DIET PLAN', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(plan, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    final dateKey = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";

    return Column(
      children: [
        _buildAdminDietSection(uid ?? ''),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('DIET CENTER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
              IconButton(
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.redAccent : null),
                onPressed: _isListening ? () => _speech.stop() : _startListening,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: _db.child('diet_logs/$uid/$dateKey').onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              
              Map<String, List<Map>> categorized = {
                'breakfast': [],
                'lunch': [],
                'snacks': [],
                'dinner': [],
              };

              if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                final logs = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
                for (var key in logs.keys) {
                  final val = logs[key];
                  if (val is Map) {
                    if (categorized.containsKey(key)) {
                      val.forEach((itemKey, itemVal) {
                        categorized[key]!.add(Map<String, dynamic>.from(itemVal as Map));
                      });
                    } else if (key == 'workouts') {
                      // Workouts category in history
                      if (!categorized.containsKey('workouts')) categorized['workouts'] = [];
                      val.forEach((wkId, wkVal) {
                        categorized['workouts']!.add(Map<String, dynamic>.from(wkVal as Map));
                      });
                    } else if (val.containsKey('calories')) {
                      categorized['snacks']!.add(Map<String, dynamic>.from(val));
                    }
                  }
                }
              }

              return StreamBuilder<DatabaseEvent>(
                stream: _db.child('steps/$uid/$dateKey').onValue,
                builder: (context, stepSnap) {
                  if (stepSnap.hasData && stepSnap.data?.snapshot.value != null) {
                    final stepData = stepSnap.data!.snapshot.value as Map;
                    final stepBurn = (stepData['caloriesBurned'] ?? 0.0) as double;
                    if (stepBurn > 0) {
                      if (!categorized.containsKey('activity')) categorized['activity'] = [];
                      categorized['activity']!.add({'name': 'NATIVE HARDWARE WALKING', 'calories': -stepBurn, 'amount': '${stepData['count']} steps'});
                    }
                  }

                  bool isEmpty = crystallizedEmpty(categorized);
                  if (isEmpty) return _buildEmptyState();

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      ...categorized.entries.map((entry) {
                        if (entry.value.isEmpty) return const SizedBox();
                        return _buildMealSection(entry.key, entry.value);
                      }).toList(),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  bool crystallizedEmpty(Map<String, List<Map>> data) {
    for (var list in data.values) {
      if (list.isNotEmpty) return false;
    }
    return true;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_food_outlined, size: 64, color: Colors.white10),
          const SizedBox(height: 16),
          const Text('NO MEALS LOGGED TODAY', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildMealSection(String title, List<Map> items) {
    int sectionTotal = items.fold(0, (sum, item) => sum + (item['calories'] as num).toInt());
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(title.toUpperCase(), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 11)),
              const SizedBox(width: 8),
              Text('$sectionTotal kcal', style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              const Expanded(child: Divider(color: Colors.white10)),
            ],
          ),
        ),
        ...items.map((item) => _buildFoodCard(item)).toList(),
      ],
    );
  }

  Widget _buildFoodCard(Map item) {
    final isNegative = (item['calories'] as num) < 0;
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isNegative ? Colors.blueAccent.withOpacity(0.05) : const Color(0xFF161B22), 
          borderRadius: BorderRadius.circular(20),
          border: isNegative ? Border.all(color: Colors.blueAccent.withOpacity(0.2)) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'].toString().toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1, color: isNegative ? Colors.blueAccent : Colors.white)),
                  const SizedBox(height: 4),
                  Text(item['amount'] != null ? '${item['amount']}' : '', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${isNegative ? "" : "+"}${item['calories']} KCAL', style: TextStyle(color: isNegative ? Colors.blueAccent : Theme.of(context).primaryColor, fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 4),
                Text('P: ${item['protein']}g | C: ${item['carbs']}g | F: ${item['fats']}g', style: const TextStyle(color: Colors.white24, fontSize: 9)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MemberChatView extends StatefulWidget {
  const MemberChatView({super.key});

  @override
  State<MemberChatView> createState() => _MemberChatViewState();
}

class _MemberChatViewState extends State<MemberChatView> {
  final _database = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  final _timeService = ServerTimeService();
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _handleDailyPurge();
  }

  void _handleDailyPurge() async {
    final serverNow = _timeService.now;
    final dateKey = "${serverNow.year}-${serverNow.month}-${serverNow.day}";
    final lastPurgeSnapshot = await _database.child('metadata/last_purge').get();
    final lastPurgeDate = lastPurgeSnapshot.value as String?;

    if (lastPurgeDate != dateKey) {
      await _database.child('group_chat').remove();
      await _database.child('metadata/last_purge').set(dateKey);
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final profileSnapshot = await _database.child('users/${user.uid}/name').get();
      String senderName = profileSnapshot.value as String? ?? user.email?.split('@')[0] ?? 'Member';
      if (user.email == 'slimfitness@gmail.com') senderName = 'YOGESH (OWNER)';

      await _database.child('group_chat').push().set({
        'senderId': user.uid,
        'senderName': senderName,
        'text': text,
        'isAdmin': user.email == 'slimfitness@gmail.com',
        'timestamp': ServerValue.timestamp,
      });
      _messageController.clear();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserUid = _auth.currentUser?.uid;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: _database.child('group_chat').onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data?.snapshot.value == null) return const Center(child: Text('No messages yet.', style: TextStyle(color: Colors.white24)));

              final Map<dynamic, dynamic> chatMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
              final messages = chatMap.values.map((v) => Map<String, dynamic>.from(v as Map)).toList();
              messages.sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0));

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg['senderId'] == currentUserUid;
                  final isAdmin = msg['isAdmin'] == true;
                  final date = DateTime.fromMillisecondsSinceEpoch(msg['timestamp'] as int? ?? 0);
                  final timeStr = DateFormat('hh:mm a').format(date);

                  return FadeInUp(
                    duration: const Duration(milliseconds: 300),
                    child: Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? Theme.of(context).primaryColor : (isAdmin ? const Color(0xFF1E293B) : const Color(0xFF161B22)),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isMe ? 20 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isAdmin) const Text('OWNER', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1))
                            else if (!isMe) Text(msg['senderName'] ?? '', style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text(msg['text'] ?? '', style: TextStyle(color: isMe ? Colors.black : Colors.white, fontSize: 15)),
                            const SizedBox(height: 4),
                            Align(alignment: Alignment.centerRight, child: Text(timeStr, style: TextStyle(color: isMe ? Colors.black54 : Colors.white24, fontSize: 9))),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: const Color(0xFF161B22),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                  ),
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
    );
  }
}
