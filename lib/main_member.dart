import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme.dart';
import 'splash_view.dart';
import 'server_time_service.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';
import 'step_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Will uncomment when google-services is linked
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  ServerTimeService().init();
  await StepService().init();
  runApp(const SlimFitnessMemberApp());
}

class SlimFitnessMemberApp extends StatelessWidget {
  const SlimFitnessMemberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SlimFitness Platform',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: SlimFitnessTheme.darkTheme,
      darkTheme: SlimFitnessTheme.darkTheme,
      home: const SplashView(isAdminEntryPoint: false),
    );
  }
}
