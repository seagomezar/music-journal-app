import 'dart:io';
import 'dart:ui' as ui;

import 'package:flute/models/exercise.dart';
import 'package:flute/models/piece.dart';
import 'package:flute/models/routine.dart';
import 'package:flute/models/score_view_preferences.dart';
import 'package:flute/models/session_record.dart';
import 'package:flute/models/user_profile.dart';
import 'package:flute/providers/auth_provider.dart';
import 'package:flute/providers/history_provider.dart';
import 'package:flute/providers/localization_provider.dart';
import 'package:flute/providers/practice_provider.dart';
import 'package:flute/providers/repertoire_provider.dart';
import 'package:flute/providers/routine_provider.dart';
import 'package:flute/screens/active_practice_view.dart';
import 'package:flute/screens/auth_screen.dart';
import 'package:flute/screens/calendar_history_view.dart';
import 'package:flute/screens/main_shell.dart';
import 'package:flute/screens/repertoire_view.dart';
import 'package:flute/screens/routine_config_view.dart';
import 'package:flute/screens/score_viewer_screen.dart';
import 'package:flute/screens/settings_screen.dart';
import 'package:flute/services/database_service.dart';
import 'package:flute/services/file_storage_service.dart';
import 'package:flute/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf_document/pdf_document.dart' as pdf;
import 'package:provider/provider.dart';

const _surfaceKey = ValueKey('ipad_evidence_surface');
const _outputDir = '/Users/sebas/.gemini/antigravity/brain/cfdf2788-bb3e-466b-8267-cccfc5748335';

Future<void> _capture(WidgetTester tester, String filename) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_surfaceKey),
    );
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outputDir/$filename.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
  });
}

Widget _wrapWithProviders({
  required Widget child,
  AuthProvider? authProv,
  PracticeProvider? practiceProv,
  RoutineProvider? routineProv,
  RepertoireProvider? repertoireProv,
  HistoryProvider? historyProv,
  LocalizationProvider? localizationProv,
  ThemeMode themeMode = ThemeMode.light,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(
        value: localizationProv ?? LocalizationProvider(initialLocale: 'es'),
      ),
      ChangeNotifierProvider.value(value: authProv ?? AuthProvider()),
      ChangeNotifierProvider.value(value: routineProv ?? RoutineProvider()),
      ChangeNotifierProvider.value(value: repertoireProv ?? RepertoireProvider()),
      ChangeNotifierProvider.value(value: historyProv ?? HistoryProvider()),
      ChangeNotifierProvider.value(value: practiceProv ?? PracticeProvider()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('es', ''),
      ],
      home: Scaffold(
        body: RepaintBoundary(
          key: _surfaceKey,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String samplePdfPath;

  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
    tempDir = await Directory.systemTemp.createTemp('flute_ipad_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tempDir.path,
        );

    final db = DatabaseService();
    await db.init();
    await db.clearAllUserData();

    await db.saveUserProfile(
      UserProfile(
        id: 'user_ipad',
        name: 'Sebastián',
        weeklyPracticeGoalMinutes: 180,
      ),
    );

    final sampleRoutines = [
      Routine(
        id: 'lunes',
        title: 'Lunes',
        description: 'Cromatismos de La (16T), escalas y vibrato.',
        exercises: [
          Exercise(id: 'l1', name: 'Cromatismos de La (bajando - 16T)', targetBpm: 60, articulation: 'Legato'),
          Exercise(id: 'l2', name: 'Cromatismos de La (subiendo - 16T)', targetBpm: 60, articulation: 'Legato'),
          Exercise(id: 'l3', name: 'Escalas: Articulación', targetBpm: 80, articulation: 'Staccato'),
          Exercise(id: 'l4', name: 'Vibrato', targetBpm: 60, articulation: 'Legato'),
        ],
      ),
      Routine(
        id: 'martes',
        title: 'Martes',
        description: 'Armónicos, escalas, ataque de aire, trinos y apoyaturas.',
        exercises: [
          Exercise(id: 'm1', name: 'Armónicos', targetBpm: 60, articulation: 'Legato'),
          Exercise(id: 'm2', name: 'Escalas', targetBpm: 80, articulation: 'Staccato'),
          Exercise(id: 'm3', name: 'Ataque de aire', targetBpm: 70, articulation: 'Staccato'),
          Exercise(id: 'm4', name: 'Trinos y apoyaturas', targetBpm: 80, articulation: 'Legato'),
        ],
      ),
    ];

    for (final r in sampleRoutines) {
      await db.saveRoutine(r);
    }

    final samplePieces = [
      Piece(
        id: 'piece_syrinx',
        title: 'Syrinx',
        composer: 'Claude Debussy',
        targetBpm: 50,
        measuresTotal: 35,
        measuresCompleted: 12,
        notes: 'Fluid transitions, resonant low register.',
      ),
      Piece(
        id: 'piece_chaminade',
        title: 'Concertino Op. 107',
        composer: 'Cécile Chaminade',
        targetBpm: 112,
        measuresTotal: 140,
        measuresCompleted: 45,
        notes: 'Expressive opening melody into brilliant allegro.',
      ),
    ];

    for (final p in samplePieces) {
      await db.savePiece(p);
    }

    final now = DateTime.now();
    final sampleSessions = [
      SessionRecord(
        id: 'sess_1',
        startTime: now.subtract(const Duration(days: 1, hours: 2)),
        endTime: now.subtract(const Duration(days: 1, hours: 1)),
        totalDurationInSeconds: 3600,
        completedExercises: sampleRoutines.first.exercises,
        rehearsedPieces: [
          SessionPieceRecord(
            pieceId: 'piece_syrinx',
            pieceTitle: 'Syrinx',
            durationInSeconds: 1200,
            measuresWorked: 8,
          ),
        ],
        notes: 'Great tone on the low C. Scales at 80 bpm felt clean.',
      ),
      SessionRecord(
        id: 'sess_2',
        startTime: now.subtract(const Duration(hours: 4)),
        endTime: now.subtract(const Duration(hours: 3)),
        totalDurationInSeconds: 3600,
        completedExercises: sampleRoutines.last.exercises,
        rehearsedPieces: [],
        notes: 'Harmonics drill 10 mins. Vibrato steady.',
      ),
    ];

    for (final s in sampleSessions) {
      await db.saveSession(s);
    }

    final sourceFile = File('${tempDir.path}/sample_score.pdf');
    await sourceFile.writeAsBytes(pdf.PdfBlankDocument.create(pageCount: 2));
    final storage = FileStorageService(rootOverride: tempDir);
    samplePdfPath = await storage.importPdf(sourceFile.path, originalName: 'Syrinx_Score.pdf');

    await db.saveScoreViewPreferences(
      ScoreViewPreferences(
        pieceId: 'piece_syrinx',
        sourcePath: samplePdfPath,
        layoutMode: ScoreLayoutMode.twoPage,
        fitMode: ScoreFitMode.fitWidth,
      ),
    );
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('iPad Fullscreen UI Suite', () {
    testWidgets('1a. Onboarding Portrait', (tester) async {
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_wrapWithProviders(child: const AuthScreen()));
      await _capture(tester, 'ipad_portrait_01_onboarding');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('1b. Onboarding Landscape', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_wrapWithProviders(child: const AuthScreen()));
      await _capture(tester, 'ipad_landscape_01_onboarding');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('2a. Dashboard Portrait', (tester) async {
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_wrapWithProviders(child: const MainShell()));
      expect(find.byType(NavigationRail), findsOneWidget);
      await _capture(tester, 'ipad_portrait_02_dashboard');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('2b. Dashboard Landscape', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_wrapWithProviders(child: const MainShell()));
      expect(find.byType(NavigationRail), findsOneWidget);
      await _capture(tester, 'ipad_landscape_02_dashboard');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('3a. Routines Portrait', (tester) async {
      final routineProv = RoutineProvider();
      await routineProv.loadRoutines();

      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        _wrapWithProviders(
          routineProv: routineProv,
          child: const RoutineConfigView(),
        ),
      );
      await _capture(tester, 'ipad_portrait_03_routines');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('3b. Routines Landscape', (tester) async {
      final routineProv = RoutineProvider();
      await routineProv.loadRoutines();

      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        _wrapWithProviders(
          routineProv: routineProv,
          child: const RoutineConfigView(),
        ),
      );
      await _capture(tester, 'ipad_landscape_03_routines');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('4a. Repertoire Portrait', (tester) async {
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_wrapWithProviders(child: const RepertoireView()));
      await _capture(tester, 'ipad_portrait_04_repertoire');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('4b. Repertoire Landscape', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_wrapWithProviders(child: const RepertoireView()));
      await _capture(tester, 'ipad_landscape_04_repertoire');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('5a. Score Viewer Portrait', (tester) async {
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        _wrapWithProviders(
          child: ScoreViewerScreen(
            pieceId: 'piece_syrinx',
            pdfPath: samplePdfPath,
            pieceTitle: 'Syrinx',
            pieceBpm: 50,
          ),
        ),
      );
      await _capture(tester, 'ipad_portrait_05_score_viewer');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('5b. Score Viewer Landscape', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        _wrapWithProviders(
          child: ScoreViewerScreen(
            pieceId: 'piece_syrinx',
            pdfPath: samplePdfPath,
            pieceTitle: 'Syrinx',
            pieceBpm: 50,
          ),
        ),
      );
      await _capture(tester, 'ipad_landscape_05_score_viewer');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('6a. Active Practice Portrait', (tester) async {
      final practice = PracticeProvider();
      final routine = DatabaseService().getRoutines().first;
      practice.startSession(routine);

      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        _wrapWithProviders(
          practiceProv: practice,
          child: const ActivePracticeView(),
        ),
      );
      await _capture(tester, 'ipad_portrait_06_active_practice');
      practice.cancelSession();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('6b. Active Practice Landscape', (tester) async {
      final practice = PracticeProvider();
      final routine = DatabaseService().getRoutines().first;
      practice.startSession(routine);

      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        _wrapWithProviders(
          practiceProv: practice,
          child: const ActivePracticeView(),
        ),
      );
      await _capture(tester, 'ipad_landscape_06_active_practice');
      practice.cancelSession();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('7a. Calendar / History Portrait', (tester) async {
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_wrapWithProviders(child: const CalendarHistoryView()));
      await _capture(tester, 'ipad_portrait_07_history');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('7b. Calendar / History Landscape', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_wrapWithProviders(child: const CalendarHistoryView()));
      await _capture(tester, 'ipad_landscape_07_history');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('8a. Settings Portrait', (tester) async {
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_wrapWithProviders(child: const SettingsScreen()));
      await _capture(tester, 'ipad_portrait_08_settings');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('8b. Settings Landscape', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_wrapWithProviders(child: const SettingsScreen()));
      await _capture(tester, 'ipad_landscape_08_settings');
      await tester.pumpWidget(const SizedBox());
    });
  });
}
