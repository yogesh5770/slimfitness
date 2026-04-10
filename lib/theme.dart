import 'package:flutter/material.dart';

class SlimFitnessTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF080808),
      canvasColor: const Color(0xFF080808),
      cardColor: const Color(0xFF161B22),
      primaryColor: const Color(0xFF8B5CF6),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF8B5CF6),
        secondary: Color(0xFF7C3AED),
        surface: Color(0xFF080808),
        onSurface: Colors.white,
        background: Color(0xFF080808),
        onBackground: Colors.white,
        surfaceVariant: Color(0xFF141414),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
