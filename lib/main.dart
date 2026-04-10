import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ai_coach_view.dart';
import 'splash_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        cardTheme: CardTheme(
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


class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center, size: 80, color: Color(0xFF39FF14)),
            const SizedBox(height: 24),
            Text(
              'SLIMFITNESS',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(letterSpacing: 2.0),
            ),
            const SizedBox(height: 8),
            const Text(
              'ELITE PERFORMANCE',
              style: TextStyle(color: Color(0xFF39FF14), letterSpacing: 4.0, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 48),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const DashboardView()),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF39FF14)),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              child: const Text('ENTER', style: TextStyle(color: Color(0xFF39FF14), fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Welcome, Member', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          // Premium Glass-like Card Placeholder
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                )
              ]
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today\'s Workout', style: TextStyle(color: Colors.white54)),
                SizedBox(height: 8),
                Text('Upper Body Strength', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiCoachView()),
              );
            },
            icon: const Icon(Icons.smart_toy, color: Colors.black),
            label: const Text('Ask AI Gym Coach', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}
