import 'package:firebase_database/firebase_database.dart';

/// Elite Service to maintain "Ground Truth" server time.
/// This prevents clock-cheating by syncing with the Firebase atomic clock.
class ServerTimeService {
  static final ServerTimeService _instance = ServerTimeService._internal();
  factory ServerTimeService() => _instance;
  ServerTimeService._internal();

  int _offset = 0;

  void init() {
    // Listen to Firebase's internal clock offset
    FirebaseDatabase.instance.ref('.info/serverTimeOffset').onValue.listen((event) {
      _offset = (event.snapshot.value as int? ?? 0);
    });
  }

  /// The raw difference between the local clock and the Firebase atomic clock
  int get offset => _offset;

  /// Returns the synchronized Server Time in milliseconds since epoch
  int get currentTimeMillis => DateTime.now().millisecondsSinceEpoch + _offset;

  /// Returns the synchronized Server Time as a DateTime object
  DateTime get now => DateTime.fromMillisecondsSinceEpoch(currentTimeMillis);

  /// Check if a given timestamp (in millis) belongs to "Today" based on Server Time
  bool isToday(int timestampMillis) {
    final serverNow = now;
    final targetDate = DateTime.fromMillisecondsSinceEpoch(timestampMillis);
    
    return serverNow.year == targetDate.year &&
           serverNow.month == targetDate.month &&
           serverNow.day == targetDate.day;
  }
}
