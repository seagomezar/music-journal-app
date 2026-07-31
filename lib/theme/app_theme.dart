import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Stitch Brand Colors (Flute Practice Coach)
  static const Color background = Color(0xFFFAF9F7); // Warm paper background
  static const Color surface = Color(0xFFFAF9F7); // Warm paper surface
  static const Color cardBg = Color(0xFFEFEEEC); // Warm surface container
  static const Color border = Color(0xFFC3C8C1); // Outline border
  static const Color primary = Color(0xFF061B0E); // Forest green primary
  static const Color primaryAccent = Color(
    0xFF775A19,
  ); // Gold/Brass accent (secondary in Stitch)
  static const Color secondary = Color(
    0xFF819986,
  ); // Sage green secondary (for success states/badging)
  static const Color textPrimary = Color(0xFF1A1C1B); // Dark charcoal text
  static const Color textSecondary = Color(
    0xFF434843,
  ); // Medium gray-green text

  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, Color(0xFF1B3022)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [primaryAccent, Color(0xFFFED488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: Color(0xFFBA1A1A),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: background,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: const TextStyle(
          fontFamily: 'serif',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: const TextStyle(
          fontFamily: 'serif',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'serif',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: const TextStyle(fontSize: 16, color: textPrimary),
        bodyMedium: const TextStyle(fontSize: 14, color: textSecondary),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg.withValues(alpha: 0.5),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // Helper Widget: Glassmorphic/Tonal Container Card
  static Widget glassCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double borderRadius = 16,
    Color? customColor,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customColor ?? cardBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
