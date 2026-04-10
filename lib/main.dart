import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ai_coach_view.dart';
import 'splash_view.dart';
import 'server_time_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  ServerTimeService().init();
  runApp(const SlimFitnessApp());
}

class SlimFitnessApp extends StatelessWidget {
  const SlimFitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SlimFitness Elite',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0C10), // Matte Obsidian
        primaryColor: const Color(0xFF8B5CF6), // Premium Matte Purple (Amethyst)
        cardTheme: CardThemeData(
          color: const Color(0xFF161B22), // Surface Grey
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6),
          onPrimary: Colors.black,
          secondary: Color(0xFF7C3AED),
          surface: Color(0xFF161B22),
          onSurface: Colors.white,
          background: Color(0xFF0A0C10),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.dark().textTheme,
        ).copyWith(
          displayLarge: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
          titleLarge: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          bodyMedium: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      home: const SplashView(isAdminEntryPoint: false), // Default handled by splash logic
    );
  }
}
