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

