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

  // Low-glare night palette. It keeps the same forest/sage/brass identity
  // while reducing luminance for evening practice.
  static const Color darkBackground = Color(0xFF101713);
  static const Color darkSurface = Color(0xFF141E18);
  static const Color darkCardBg = Color(0xFF1D2A22);
  static const Color darkBorder = Color(0xFF4D6253);
  static const Color darkTextPrimary = Color(0xFFF1F4EF);
  static const Color darkTextSecondary = Color(0xFFC1CEC2);
  static const Color darkPrimary = Color(0xFF9BC9A5);
  static const Color darkSecondary = Color(0xFFA7C9AE);
  static const Color darkAccent = Color(0xFFE1C56C);

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
    return _buildTheme(
      brightness: Brightness.light,
      backgroundColor: background,
      surfaceColor: surface,
      cardColor: cardBg,
      borderColor: border,
      foregroundColor: textPrimary,
      mutedColor: textSecondary,
      statusBarBrightness: Brightness.dark,
    );
  }

  static ThemeData get darkTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      backgroundColor: darkBackground,
      surfaceColor: darkSurface,
      cardColor: darkCardBg,
      borderColor: darkBorder,
      foregroundColor: darkTextPrimary,
      mutedColor: darkTextSecondary,
      statusBarBrightness: Brightness.light,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color backgroundColor,
    required Color surfaceColor,
    required Color cardColor,
    required Color borderColor,
    required Color foregroundColor,
    required Color mutedColor,
    required Brightness statusBarBrightness,
  }) {
    final isDark = brightness == Brightness.dark;
    final effectivePrimary = isDark ? darkPrimary : primary;
    final effectiveSecondary = isDark ? darkSecondary : secondary;
    final effectiveAccent = isDark ? darkAccent : primaryAccent;
    final effectiveOnPrimary = isDark ? darkBackground : Colors.white;
    final effectiveOnSecondary = isDark ? darkBackground : Colors.white;
    final effectiveOnAccent = isDark ? darkBackground : Colors.white;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: effectivePrimary,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: effectivePrimary,
        secondary: effectiveSecondary,
        tertiary: effectiveAccent,
        surface: surfaceColor,
        onSurface: foregroundColor,
        onPrimary: effectiveOnPrimary,
        onSecondary: effectiveOnSecondary,
        onTertiary: effectiveOnAccent,
        onError: Colors.white,
        error: Color(0xFFBA1A1A),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: foregroundColor,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: statusBarBrightness,
          systemNavigationBarColor: backgroundColor,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'serif',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: foregroundColor,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'serif',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: foregroundColor,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontFamily: 'serif',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: foregroundColor,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: foregroundColor,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: foregroundColor),
        bodyMedium: TextStyle(fontSize: 14, color: mutedColor),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: foregroundColor,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor.withValues(alpha: 0.5),
        labelStyle: TextStyle(color: mutedColor),
        hintStyle: TextStyle(color: mutedColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: effectivePrimary, width: 2),
        ),
      ),
      dividerColor: borderColor,
      iconTheme: IconThemeData(color: foregroundColor),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: backgroundColor,
        selectedItemColor: effectivePrimary,
        unselectedItemColor: mutedColor,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static Color backgroundColor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  static Color surfaceColor(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color cardColor(BuildContext context) => Theme.of(context).cardColor;

  static Color borderColor(BuildContext context) =>
      Theme.of(context).dividerColor;

  static Color primaryColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color accentColor(BuildContext context) =>
      Theme.of(context).colorScheme.tertiary;

  static Color secondaryColor(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;

  static Color textPrimaryColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color textSecondaryColor(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.color ??
      Theme.of(context).colorScheme.onSurface;

  // Helper Widget: Glassmorphic/Tonal Container Card
  static Widget glassCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double borderRadius = 16,
    Color? customColor,
  }) {
    return Builder(
      builder: (context) => Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: customColor ?? Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.18
                    : 0.04,
              ),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        // ListTile paints its ink/background on the nearest Material. Keep
        // that Material inside the decorated card so interactive tiles do not
        // trigger Flutter's invisible-ink assertion in debug/test builds.
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}
