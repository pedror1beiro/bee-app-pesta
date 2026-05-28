import 'package:flutter/material.dart';

class AppTheme {
  static const bark    = Color(0xFF1C110A);
  static const bark60  = Color(0xFF5C3A1E);
  static const bark30  = Color(0xFFA07850);
  static const honey   = Color(0xFFE8922A);
  static const honeyLt = Color(0xFFF5B95D);
  static const wax     = Color(0xFFFFF8EC);
  static const leaf    = Color(0xFF3D6B45);
  static const leafLt  = Color(0xFF6FAA79);
  static const sky     = Color(0xFF4A90B8);
  static const danger  = Color(0xFFD94F4F);
  static const surface = Color(0xFF2A1A0C);
  static const card    = Color(0xFF362213);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: bark,
    colorScheme: const ColorScheme.dark(
      primary: honey,
      secondary: leafLt,
      surface: surface,
      onSurface: wax,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bark,
      foregroundColor: wax,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: wax,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: honey.withValues(alpha: 0.2),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: honey);
        }
        return const IconThemeData(color: bark30);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.selected) ? honey : bark30;
        return TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600);
      }),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: honey,
        foregroundColor: bark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: bark60),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: bark60),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: honey, width: 2),
      ),
      labelStyle: const TextStyle(color: bark30),
      hintStyle: const TextStyle(color: bark30),
    ),
    cardTheme: CardThemeData(
      color: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
  );
}
