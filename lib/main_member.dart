import 'firebase_options_manual.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ELITE BOOT LOGIC: Run App immediately to show 'Loading' state while Firebase initializes
  runApp(const SlimFitnessMemberApp());

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.getOptions('member'),
    ).timeout(const Duration(seconds: 5));

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await ServerTimeService().init().timeout(const Duration(seconds: 5));
    await StepService().init().timeout(const Duration(seconds: 5));
    
    print("ELITE: Member System Initialization Successful.");
  } catch (e) {
    print("ELITE ERROR: Safe Boot triggered for Member. Initialization failed: $e");
  }
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
