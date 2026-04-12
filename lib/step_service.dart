import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StepService {
  static final StepService _instance = StepService._internal();
  factory StepService() => _instance;
  StepService._internal();

  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;

  StreamSubscription<StepCount>? _stepCountStream;
  int _todaySteps = 0;
  int? _startingSteps;
  double _multiplier = 0.04; // Default elite average

  int get todaySteps => _todaySteps;
  double get burnedCalories => _todaySteps * _multiplier;

  Future<void> init() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final dateKey = "${now.year}-${now.month}-${now.day}";

    // 1. Fetch personalization multiplier and today's starting offset
    final userSnap = await _db.child('users/$uid/vitals/stepMultiplier').get();
    if (userSnap.exists) _multiplier = (userSnap.value as num).toDouble();

    final stepSnap = await _db.child('steps/$uid/$dateKey/startingSteps').get();
    if (stepSnap.exists) {
      _startingSteps = (stepSnap.value as num).toInt();
    }

    // 2. Request Permission
    final status = await Permission.activityRecognition.request();
    if (status.isGranted) {
      _startListening();
    }
  }

  void updateMultiplier(double newFactor) => _multiplier = newFactor;

  void _startListening() {
    _stepCountStream = Pedometer.stepCountStream.listen(_onStepCount, onError: _onStepCountError);
  }

  void _onStepCount(StepCount event) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final dateKey = "${now.year}-${now.month}-${now.day}";

    // Logic: Pedometer returns steps since boot.
    // If we don't have a starting point for today, set this first count as the base.
    if (_startingSteps == null || _startingSteps == 0) {
      _startingSteps = event.steps;
      await _db.child('steps/$uid/$dateKey/startingSteps').set(_startingSteps);
    }

    _todaySteps = event.steps - _startingSteps!;
    if (_todaySteps < 0) _todaySteps = 0; // Guard against reboot resets
    
    // Sync to Cloud
    await _db.child('steps/$uid/$dateKey').update({
      'count': _todaySteps,
      'caloriesBurned': burnedCalories,
      'lastUpdate': ServerValue.timestamp,
    });
  }

  void _onStepCountError(error) {
    print('Pedometer Error: $error');
  }

  void stop() {
    _stepCountStream?.cancel();
  }
}
