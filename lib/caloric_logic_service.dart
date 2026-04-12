import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CaloricLogicService {
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;

  Future<int> getYesterdayPenalty() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateKey = "${yesterday.year}-${yesterday.month}-${yesterday.day}";

    try {
      // 1. Get yesterday's consumption
      final logSnapshot = await _db.child('diet_logs/$uid/$dateKey').get();
      int consumed = 0;
      if (logSnapshot.exists) {
        final data = logSnapshot.value as Map<dynamic, dynamic>;
        for (var entry in data.values) {
          if (entry is Map) {
            if (entry.containsKey('calories')) {
              consumed += (entry['calories'] as num).toInt();
            } else {
              // Categorized structure
              for (var item in entry.values) {
                if (item is Map && item.containsKey('calories')) {
                  consumed += (item['calories'] as num).toInt();
                }
              }
            }
          }
        }
      }

      // 2. Get yesterday's target (or current target as fallback)
      final vitalsSnapshot = await _db.child('users/$uid/vitals/dailyCalorieTarget').get();
      final target = (vitalsSnapshot.value as num?)?.toInt() ?? 2000;

      // 3. Calculate Debt (Only if consumed > target)
      final overage = consumed - target;
      return overage > 0 ? overage : 0;
    } catch (e) {
      print("ERROR CALCULATING CALORIE DEBT: $e");
      return 0;
    }
  }
}
