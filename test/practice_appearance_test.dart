import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flute/models/practice_appearance_preferences.dart';
import 'package:flute/providers/practice_provider.dart';
import 'package:flute/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('practice appearance defaults to a calm focused system-aware setup', () {
    final provider = PracticeProvider();
    addTearDown(provider.dispose);

    expect(provider.visualMode, PracticeVisualMode.focused);
    expect(provider.themeMode, ThemeMode.system);
    expect(provider.hapticsEnabled, isTrue);
    expect(provider.soundCuesEnabled, isTrue);
    expect(provider.reducedMotion, isFalse);
    expect(provider.showCelebrations, isTrue);
  });

  test(
    'appearance changes are persisted through the provider boundary',
    () async {
      PracticeVisualMode? savedMode;
      ThemeMode? savedTheme;
      bool? savedHaptics;
      bool? savedSoundCues;
      bool? savedReducedMotion;
      bool? savedCelebrations;
      final provider = PracticeProvider(
        persistVisualMode: (value) async => savedMode = value,
        persistThemeMode: (value) async => savedTheme = value,
        persistHaptics: (value) async => savedHaptics = value,
        persistSoundCues: (value) async => savedSoundCues = value,
        persistReducedMotion: (value) async => savedReducedMotion = value,
        persistShowCelebrations: (value) async => savedCelebrations = value,
      );
      addTearDown(provider.dispose);

      await provider.setVisualMode(PracticeVisualMode.full);
      await provider.setThemeMode(ThemeMode.dark);
      await provider.setHapticsEnabled(false);
      await provider.setSoundCuesEnabled(false);
      await provider.setReducedMotion(true);
      await provider.setShowCelebrations(false);

      expect(savedMode, PracticeVisualMode.full);
      expect(savedTheme, ThemeMode.dark);
      expect(savedHaptics, isFalse);
      expect(savedSoundCues, isFalse);
      expect(savedReducedMotion, isTrue);
      expect(savedCelebrations, isFalse);
      expect(provider.visualMode, PracticeVisualMode.full);
      expect(provider.themeMode, ThemeMode.dark);
    },
  );

  test('light and dark themes expose readable semantic surfaces', () {
    expect(AppTheme.lightTheme.brightness, Brightness.light);
    expect(AppTheme.darkTheme.brightness, Brightness.dark);
    expect(
      AppTheme.darkTheme.colorScheme.onSurface.computeLuminance(),
      greaterThan(AppTheme.darkTheme.colorScheme.surface.computeLuminance()),
    );
    expect(AppTheme.darkTheme.cardTheme.color, AppTheme.darkCardBg);
  });

  test('resetPreferences restores defaults after erasing local data', () async {
    final provider = PracticeProvider(
      keepScreenAwake: true,
      metronomeSoundEnabled: false,
      metronomeVolume: 0.2,
      tunerReferenceHz: 450,
      tunerToleranceCents: 20,
      visualMode: PracticeVisualMode.full,
      themeMode: ThemeMode.dark,
      hapticsEnabled: false,
      soundCuesEnabled: false,
      reducedMotion: true,
      showCelebrations: false,
    );
    addTearDown(provider.dispose);

    await provider.resetPreferences();

    expect(provider.keepScreenAwake, isFalse);
    expect(provider.metronomeSoundEnabled, isTrue);
    expect(provider.metronomeVolume, 0.7);
    expect(provider.tunerReferenceHz, 440);
    expect(provider.tunerToleranceCents, 10);
    expect(provider.visualMode, PracticeVisualMode.focused);
    expect(provider.themeMode, ThemeMode.system);
    expect(provider.hapticsEnabled, isTrue);
    expect(provider.soundCuesEnabled, isTrue);
    expect(provider.reducedMotion, isFalse);
    expect(provider.showCelebrations, isTrue);
  });
}
