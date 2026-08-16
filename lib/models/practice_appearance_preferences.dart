import 'package:flutter/material.dart';

/// Controls the amount of information visible while a musician is practising.
///
/// Focused mode keeps the current exercise and its timing controls in view;
/// full mode preserves the complete session workspace.
enum PracticeVisualMode { focused, full }

class PracticeAppearancePreferences {
  const PracticeAppearancePreferences({
    this.visualMode = PracticeVisualMode.focused,
    this.themeMode = ThemeMode.system,
    this.hapticsEnabled = true,
    this.soundCuesEnabled = true,
    this.reducedMotion = false,
    this.showCelebrations = true,
  });

  final PracticeVisualMode visualMode;
  final ThemeMode themeMode;
  final bool hapticsEnabled;
  final bool soundCuesEnabled;
  final bool reducedMotion;
  final bool showCelebrations;

  PracticeAppearancePreferences copyWith({
    PracticeVisualMode? visualMode,
    ThemeMode? themeMode,
    bool? hapticsEnabled,
    bool? soundCuesEnabled,
    bool? reducedMotion,
    bool? showCelebrations,
  }) {
    return PracticeAppearancePreferences(
      visualMode: visualMode ?? this.visualMode,
      themeMode: themeMode ?? this.themeMode,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      soundCuesEnabled: soundCuesEnabled ?? this.soundCuesEnabled,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      showCelebrations: showCelebrations ?? this.showCelebrations,
    );
  }
}
