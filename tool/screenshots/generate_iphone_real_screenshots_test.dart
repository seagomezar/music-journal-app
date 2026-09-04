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
import 'package:flute/screens/main_shell.dart';
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

const _surfaceKey = ValueKey('iphone_surface');
final _targetDir = Directory('/Users/sebas/Desktop/AppStoreScreenshots/iphone');

Future<void> _capture(WidgetTester tester, String filename) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_surfaceKey),
    );
    final image = await boundary.toImage(pixelRatio: 3.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_targetDir.path}/$filename.png');
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
}) {
  final baseTheme = AppTheme.lightTheme;
  final themedWithFont = baseTheme.copyWith(
    textTheme: baseTheme.textTheme.apply(fontFamily: 'AppFont'),
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(
        value: localizationProv ?? LocalizationProvider(initialLocale: 'es'),
      ),
      ChangeNotifierProvider.value(value: authProv ?? AuthProvider()),
      ChangeNotifierProvider.value(value: routineProv ?? RoutineProvider()),
      ChangeNotifierProvider.value(
        value: repertoireProv ?? RepertoireProvider(),
      ),
      ChangeNotifierProvider.value(value: historyProv ?? HistoryProvider()),
      ChangeNotifierProvider.value(value: practiceProv ?? PracticeProvider()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themedWithFont,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      builder: (context, materialChild) {
        return RepaintBoundary(
          key: _surfaceKey,
          child: materialChild ?? const SizedBox(),
        );
      },
      home: child,
    ),
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es', null);

    // 1. Load Arial as AppFont
    final fontData = File(
      '/System/Library/Fonts/Supplemental/Arial.ttf',
    ).readAsBytesSync();
    final fontLoader = FontLoader('AppFont');
    fontLoader.addFont(Future.value(ByteData.view(fontData.buffer)));
    await fontLoader.load();

    // 2. Load MaterialIcons
    final iconData = File(
      '/Users/sebas/development/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    final iconLoader = FontLoader('MaterialIcons');
    iconLoader.addFont(Future.value(ByteData.view(iconData.buffer)));
    await iconLoader.load();

    // 3. Load serif font for piece titles
    final serifData = File(
      '/System/Library/Fonts/Supplemental/Times New Roman.ttf',
    ).readAsBytesSync();
    final serifLoader = FontLoader('serif');
    serifLoader.addFont(Future.value(ByteData.view(serifData.buffer)));
    await serifLoader.load();

    tempDir = await Directory.systemTemp.createTemp('flute_iphone_real_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            return tempDir.path;
          },
        );

    final db = DatabaseService();
    await db.init();

    await db.saveUserProfile(
      UserProfile(
        id: 'user_iphone',
        name: 'Sebastián',
        weeklyPracticeGoalMinutes: 180,
      ),
    );

    final sampleRoutines = [
      Routine(
        id: 'lunes',
        title: 'Lunes: Sonido y Armónicos',
        description: 'Cromatismos de La (16T), escalas y vibrato.',
        exercises: [
          Exercise(
            id: 'l1',
            name: 'Cromatismos de La (bajando - 16T)',
            targetBpm: 60,
            articulation: 'Legato',
          ),
          Exercise(
            id: 'l2',
            name: 'Cromatismos de La (subiendo - 16T)',
            targetBpm: 60,
            articulation: 'Legato',
          ),
          Exercise(
            id: 'l3',
            name: 'Escalas: Articulación',
            targetBpm: 80,
            articulation: 'Staccato',
          ),
          Exercise(
            id: 'l4',
            name: 'Vibrato controlado',
            targetBpm: 60,
            articulation: 'Legato',
          ),
        ],
      ),
      Routine(
        id: 'martes',
        title: 'Martes: Técnica y Agilidad',
        description: 'Armónicos, escalas, ataque de aire y trinos.',
        exercises: [
          Exercise(
            id: 'm1',
            name: 'Armónicos',
            targetBpm: 60,
            articulation: 'Legato',
          ),
          Exercise(
            id: 'm2',
            name: 'Escalas Mayores',
            targetBpm: 90,
            articulation: 'Staccato',
          ),
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
        measuresCompleted: 24,
        notes: 'Resonancia fluida en registro grave.',
      ),
      Piece(
        id: 'piece_chaminade',
        title: 'Concertino Op. 107',
        composer: 'Cécile Chaminade',
        targetBpm: 112,
        measuresTotal: 140,
        measuresCompleted: 85,
        notes: 'Apertura expresiva y allegro brillante.',
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
            measuresWorked: 12,
          ),
        ],
        notes: 'Excelente timbre en el Do grave. Escalas a 80 bpm limpias.',
      ),
      SessionRecord(
        id: 'sess_2',
        startTime: now.subtract(const Duration(hours: 4)),
        endTime: now.subtract(const Duration(hours: 3)),
        totalDurationInSeconds: 3600,
        completedExercises: sampleRoutines.last.exercises,
        rehearsedPieces: [],
        notes: 'Práctica de armónicos 15 mins. Vibrato estable.',
      ),
    ];

    for (final s in sampleSessions) {
      await db.saveSession(s);
    }

    final sourceFile = File('${tempDir.path}/sample_score.pdf');
    await sourceFile.writeAsBytes(pdf.PdfBlankDocument.create(pageCount: 2));
    final storage = FileStorageService(rootOverride: tempDir);
    final pdfPath = await storage.importPdf(
      sourceFile.path,
      originalName: 'Syrinx_Score.pdf',
    );

    await db.saveScoreViewPreferences(
      ScoreViewPreferences(pieceId: 'piece_syrinx', sourcePath: pdfPath),
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

  group('iPhone 6.5" Real Native Screenshots (1284x2778)', () {
    testWidgets('01 Dashboard', (tester) async {
      tester.view.physicalSize = const Size(1284, 2778);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithProviders(child: const MainShell(initialIndex: 0)),
      );
      await _capture(tester, '01_dashboard');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('02 Routines', (tester) async {
      final routineProv = RoutineProvider();
      await routineProv.loadRoutines();

      tester.view.physicalSize = const Size(1284, 2778);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithProviders(
          routineProv: routineProv,
          child: const MainShell(initialIndex: 1),
        ),
      );
      await _capture(tester, '02_rutinas');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('03 Repertoire', (tester) async {
      final repProv = RepertoireProvider();
      await repProv.loadPieces();

      tester.view.physicalSize = const Size(1284, 2778);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithProviders(
          repertoireProv: repProv,
          child: const MainShell(initialIndex: 2),
        ),
      );
      await _capture(tester, '03_repertorio');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('04 Active Practice', (tester) async {
      final practice = PracticeProvider();
      final routine = DatabaseService().getRoutines().first;
      practice.startSession(routine);

      tester.view.physicalSize = const Size(1284, 2778);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithProviders(
          practiceProv: practice,
          child: const ActivePracticeView(),
        ),
      );
      await _capture(tester, '04_practica_activa');
      practice.cancelSession();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('05 History', (tester) async {
      final histProv = HistoryProvider();
      await histProv.loadSessions();

      tester.view.physicalSize = const Size(1284, 2778);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithProviders(
          historyProv: histProv,
          child: const MainShell(initialIndex: 3),
        ),
      );
      await _capture(tester, '05_historial');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('06 Settings', (tester) async {
      tester.view.physicalSize = const Size(1284, 2778);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithProviders(child: const SettingsScreen()),
      );
      await _capture(tester, '06_configuracion');
      await tester.pumpWidget(const SizedBox());
    });
  });
}
