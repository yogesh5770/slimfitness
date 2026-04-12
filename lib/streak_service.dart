import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StreakService {
  final _db = FirebaseDatabase.instance.ref();

  /// Calculates and updates the user's meal logging streak.
  Future<int> updateAndGetStreak() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;

    final now = DateTime.now();
    final todayKey = "${now.year}-${now.month}-${now.day}";

    // Check if user logged any meal today
    final todaySnap = await _db.child('diet_logs/$uid/$todayKey').get();
    final hasLoggedToday = todaySnap.exists;

    // Get current streak data
    final streakSnap = await _db.child('streaks/$uid').get();
    int currentStreak = 0;
    String lastDate = '';

    if (streakSnap.exists) {
      final data = streakSnap.value as Map;
      currentStreak = (data['count'] as num?)?.toInt() ?? 0;
      lastDate = data['lastDate'] as String? ?? '';
    }

    if (!hasLoggedToday) return currentStreak;

    // Already counted today
    if (lastDate == todayKey) return currentStreak;

    // Check if yesterday was the last logged date (consecutive)
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayKey = "${yesterday.year}-${yesterday.month}-${yesterday.day}";

    if (lastDate == yesterdayKey) {
      currentStreak += 1;
    } else if (lastDate != todayKey) {
      currentStreak = 1; // Reset streak
    }

    await _db.child('streaks/$uid').set({
      'count': currentStreak,
      'lastDate': todayKey,
    });

    return currentStreak;
  }

  /// Gets streak for any user (used by Admin)
  Future<int> getStreakForUser(String uid) async {
    final snap = await _db.child('streaks/$uid').get();
    if (snap.exists) {
      return ((snap.value as Map)['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }
}
