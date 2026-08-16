import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:flute/models/user_profile.dart';
import 'package:flute/models/exercise.dart';
import 'package:flute/models/routine.dart';
import 'package:flute/providers/auth_provider.dart';
import 'package:flute/providers/history_provider.dart';
import 'package:flute/providers/localization_provider.dart';
import 'package:flute/providers/practice_provider.dart';
import 'package:flute/providers/repertoire_provider.dart';
import 'package:flute/providers/routine_provider.dart';
import 'package:flute/screens/main_shell.dart';
import 'package:flute/services/database_service.dart';
import 'package:flute/theme/app_theme.dart';

/// Loads the real Roboto + Material Icons fonts (bundled with the Flutter SDK)
/// so the widget lays out with production text metrics instead of the wide
/// placeholder test glyphs, which would otherwise force spurious overflows.
/// Resolved via FLUTTER_ROOT so it works on any machine, including CI.
Future<void> _loadRealFonts() async {
  if (kIsWeb) return;
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final fontDir = '$root/bin/cache/artifacts/material_fonts';

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      final f = File('$fontDir/$file');
      if (!f.existsSync()) return;
      loader.addFont(f.readAsBytes().then((b) => b.buffer.asByteData()));
    }
    await loader.load();
  }

  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

class FakeAuthProvider extends AuthProvider {
  @override
  UserProfile? get user => UserProfile(
    id: 'u1',
    name: 'Alex Flutist',
    email: 'alex@flute.com',
    weeklyPracticeGoalMinutes: 120,
  );
}

class FakeHistoryProvider extends HistoryProvider {
  @override
  Future<void> loadSessions() async {}
  @override
  int get thisWeekMinutesPracticed => 85;
  @override
  int get currentStreak => 4;
  @override
  int get totalSessionsCount => 27;
  @override
  int get totalExercisesCompleted => 63;
  @override
  int get totalMinutesPracticed => 940;
}

class FakeRoutineProvider extends RoutineProvider {
  @override
  bool get isLoading => false;
  @override
  Future<void> loadRoutines() async {}
  @override
  List<Routine> get routines => [
    Routine(
      id: 'r1',
      title: 'Daily Warmup',
      description: 'Long tones and scales',
      exercises: [
        Exercise(
          id: 'e1',
          name: 'Long Tones',
          targetBpm: 60,
          articulation: 'Legato',
        ),
        Exercise(
          id: 'e2',
          name: 'Chromatic Scale',
          targetBpm: 80,
          articulation: 'Legato',
        ),
      ],
    ),
  ];
}

Widget _wrapShell(LocalizationProvider loc, {ThemeData? theme}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => FakeAuthProvider()),
      ChangeNotifierProvider<HistoryProvider>(
        create: (_) => FakeHistoryProvider(),
      ),
      ChangeNotifierProvider<RoutineProvider>(
        create: (_) => FakeRoutineProvider(),
      ),
      ChangeNotifierProvider<RepertoireProvider>(
        create: (_) => RepertoireProvider(),
      ),
      ChangeNotifierProvider<PracticeProvider>(
        create: (_) => PracticeProvider(),
      ),
      ChangeNotifierProvider<LocalizationProvider>.value(value: loc),
    ],
    child: MaterialApp(
      theme: theme ?? ThemeData.light(),
      home: const MainShell(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadRealFonts();
    await initializeDateFormatting('en', null);
    await initializeDateFormatting('es', null);

    // Route path_provider (used by Hive.initFlutter) at a real temp dir so the
    // DatabaseService singleton persists locale changes for real.
    if (!kIsWeb) {
      final dir = await Directory.systemTemp.createTemp('flute_hive_dash_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => dir.path,
          );
    }
    await DatabaseService().init();
    await DatabaseService().setPreferredLocale('en');
  });

  testWidgets(
    'switching language rebuilds bottom nav and dashboard instantly and persists',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final loc = LocalizationProvider(initialLocale: 'en');
      await tester.pumpWidget(_wrapShell(loc));
      await tester.pumpAndSettle();

      // English bottom-nav labels + dashboard chrome are present.
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Routines'), findsWidgets);
      expect(find.text('Repertoire'), findsWidgets);
      expect(find.text('History'), findsWidgets);
      expect(find.text('Welcome back,'), findsOneWidget);
      expect(find.text('Current Streak'), findsOneWidget);

      // Tap the in-dashboard language toggle. No navigation happens; the fix
      // makes MainShell + DashboardView watch the provider so they rebuild.
      await tester.tap(find.byTooltip('Español'));
      await tester.pumpAndSettle();

      // Bottom nav + dashboard now show Spanish immediately.
      expect(find.text('Dashboard'), findsNothing);
      expect(find.text('Inicio'), findsWidgets); // dashboard_nav -> Inicio
      expect(find.text('Rutinas'), findsWidgets);
      expect(find.text('Historial'), findsWidgets);
      expect(find.text('Bienvenido de nuevo,'), findsOneWidget);
      expect(find.text('Racha Actual'), findsOneWidget);

      // Locale change was persisted through the real DatabaseService.
      expect(DatabaseService().getPreferredLocale(), 'es');
      expect(loc.isSpanish, isTrue);
    },
    skip: kIsWeb,
  );

  testWidgets('dashboard renders in the browser test runner', (tester) async {
    final loc = LocalizationProvider(initialLocale: 'en');
    await tester.pumpWidget(_wrapShell(loc));
    await tester.pump();
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Welcome back,'), findsOneWidget);
  }, skip: !kIsWeb);

  testWidgets('dark dashboard keeps statistics readable', (tester) async {
    final loc = LocalizationProvider(initialLocale: 'en');
    await tester.pumpWidget(_wrapShell(loc, theme: AppTheme.darkTheme));
    await tester.pumpAndSettle();

    final streak = tester.widget<Text>(find.text('4 Days'));
    expect(streak.style?.color, AppTheme.darkTextPrimary);
    expect(
      tester.widget<Text>(find.text('Current Streak')).style?.color,
      AppTheme.darkTextSecondary,
    );
  });
}
