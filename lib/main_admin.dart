import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:slim_fitness_flutter/splash_view.dart';
import 'package:slim_fitness_flutter/theme.dart';
import 'package:slim_fitness_flutter/server_time_service.dart';
import 'package:slim_fitness_flutter/notification_service.dart';
import 'firebase_options_manual.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ELITE BOOT LOGIC: Run App immediately to show 'Loading' state while Firebase initializes
  runApp(const SlimFitnessAdminApp());

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.getOptions('admin'),
    ).timeout(const Duration(seconds: 5));

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await ServerTimeService().init().timeout(const Duration(seconds: 5));
    
    print("ELITE: Admin System Initialization Successful.");
  } catch (e) {
    print("ELITE ERROR: Safe Boot triggered for Admin. Initialization failed: $e");
  }
}

class SlimFitnessAdminApp extends StatelessWidget {
  const SlimFitnessAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SlimFitness Admin',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: SlimFitnessTheme.darkTheme,
      darkTheme: SlimFitnessTheme.darkTheme,
      home: const SplashView(isAdminEntryPoint: true),
    );
  }
}

