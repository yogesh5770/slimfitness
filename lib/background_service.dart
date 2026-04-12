import 'dart:io';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', // id
    'Elite Background Sync', // title
    description: 'This channel is used for important background notifications.', // description
    importance: Importance.low, // importance must be at low or higher level
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  if (Platform.isIOS || Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        ios: DarwinInitializationSettings(),
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      ),
    );
  }

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'SlimFitness Sync',
      initialNotificationContent: 'Elite sync is active',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  DartPluginRegistrant.ensureInitialized();

  // Initialize Firebase in the background isolate
  await Firebase.initializeApp();

  // Initialize standard local notifications
  final notificationService = NotificationService();
  await notificationService.init();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  final database = FirebaseDatabase.instance.ref();
  final auth = FirebaseAuth.instance;

  // Listen to the group chat
  database.child('group_chat').limitToLast(1).onChildAdded.listen((event) async {
    if (event.snapshot.exists) {
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final isAdmin = data['isAdmin'] == true;
      final senderId = data['senderId'] as String?;
      
      // Wait for Auth context (can be null in background if session expired)
      final currentUser = auth.currentUser;
      
      // Only push a notification if the sender is NOT the current logged-in user
      if (currentUser != null && senderId != currentUser.uid) {
        String titleText = isAdmin ? 'COUNCIL ANNOUNCEMENT' : (data['senderName'] ?? 'Member');
        
        // Show notification instantly
        await notificationService.showNotification(
          title: titleText,
          body: data['text'] ?? 'New message received',
        );
      }
    }
  });

  print('BACKGROUND ISOLATE: Listening securely to Firebase Chat Socket...');
}
