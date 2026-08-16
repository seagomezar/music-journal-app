import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/metronome_audio_service.dart';
import 'services/screen_awake_service.dart';
import 'services/analytics_service.dart';
import 'providers/auth_provider.dart';
import 'providers/routine_provider.dart';
import 'providers/repertoire_provider.dart';
import 'providers/history_provider.dart';
import 'providers/practice_provider.dart';
import 'providers/localization_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AnalyticsService.track('app_launch');

  // Initialize Local Offline Database
  final dbService = DatabaseService();
  await dbService.init();

  final metronomeAudioService = MetronomeAudioService();
  // Browsers block AudioContext creation until a user gesture. Keep the
  // journal UI bootable and let the first metronome tap initialize audio
  // lazily; native platforms can still warm the engine during startup.
  if (!kIsWeb) {
    try {
      await metronomeAudioService.initialize();
    } catch (error) {
      debugPrint('Background metronome initialization failed: $error');
    }
  }

  // Initialize Date Formatting for Calendar
  await initializeDateFormatting('es', null);
  await initializeDateFormatting('en', null);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocalizationProvider()),
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..checkAuthStatus(),
        ),
        ChangeNotifierProvider(create: (_) => RoutineProvider()),
        ChangeNotifierProvider(create: (_) => RepertoireProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(
          create: (_) => PracticeProvider(
            metronomeAudioController: metronomeAudioService,
            screenAwakeController: WakelockScreenAwakeController(),
            keepScreenAwake: dbService.getKeepScreenAwake(),
            metronomeSoundEnabled: dbService.getMetronomeSoundEnabled(),
            metronomeVolume: dbService.getMetronomeVolume(),
            tunerReferenceHz: dbService.getTunerReferenceHz(),
            tunerToleranceCents: dbService.getTunerToleranceCents(),
            visualMode: dbService.getPracticeVisualMode(),
            themeMode: dbService.getThemeMode(),
            hapticsEnabled: dbService.getHapticsEnabled(),
            soundCuesEnabled: dbService.getSoundCuesEnabled(),
            reducedMotion: dbService.getReducedMotion(),
            showCelebrations: dbService.getShowCelebrations(),
            persistKeepScreenAwake: dbService.setKeepScreenAwake,
            persistMetronomeSound: dbService.setMetronomeSoundEnabled,
            persistMetronomeVolume: dbService.setMetronomeVolume,
            persistTunerReference: dbService.setTunerReferenceHz,
            persistTunerTolerance: dbService.setTunerToleranceCents,
            persistVisualMode: dbService.setPracticeVisualMode,
            persistThemeMode: dbService.setThemeMode,
            persistHaptics: dbService.setHapticsEnabled,
            persistSoundCues: dbService.setSoundCuesEnabled,
            persistReducedMotion: dbService.setReducedMotion,
            persistShowCelebrations: dbService.setShowCelebrations,
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final practiceProvider = context.watch<PracticeProvider>();
    return MaterialApp(
      title: context.translate('app_title'),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: practiceProvider.themeMode,
      debugShowCheckedModeBanner: false,
      locale: Locale(context.watch<LocalizationProvider>().localeCode),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);

    // Redirect based on local authentication profile presence
    if (authProv.isAuthenticated) {
      return const MainShell();
    } else {
      return const AuthScreen();
    }
  }
}
