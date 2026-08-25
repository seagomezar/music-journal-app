import 'dart:io';

import 'package:flute/models/score_view_preferences.dart';
import 'package:flute/providers/localization_provider.dart';
import 'package:flute/providers/practice_provider.dart';
import 'package:flute/screens/score_viewer_screen.dart';
import 'package:flute/services/annotated_pdf_export_service.dart';
import 'package:flute/services/database_service.dart';
import 'package:flute/services/file_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../test/journal_backup_service_test.dart' as backup_tests;
import '../test/pdf_annotation_test.dart' as annotation_tests;
import '../test/practice_appearance_test.dart' as appearance_tests;
import '../test/repertoire_folder_test.dart' as folder_tests;
import '../test/routine_exercise_management_test.dart' as routine_tests;
import '../test/score_performance_test.dart' as score_tests;
import '../test/session_recording_test.dart' as recording_tests;

/// Runs the platform-sensitive feature regressions inside a real iOS runner.
///
/// These tests intentionally reuse the focused widget and service journeys so
/// taps, typing, drags, persistence, PDF processing, and recording state are
/// exercised with iOS framework/plugin initialization instead of only the host
/// test VM.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  routine_tests.main();
  folder_tests.main();
  score_tests.main();
  annotation_tests.main();
  recording_tests.main();
  backup_tests.main();
  appearance_tests.main();

  testWidgets(
    'imports and interacts with a real PDF score on the iOS renderer',
    (tester) async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'flute_ios_score_',
      );
      addTearDown(() async {
        if (await temporaryDirectory.exists()) {
          await temporaryDirectory.delete(recursive: true);
        }
      });

      final sourceDocument = sf.PdfDocument();
      for (var pageNumber = 1; pageNumber <= 2; pageNumber++) {
        final page = sourceDocument.pages.add();
        page.graphics.drawString(
          'iOS score page $pageNumber',
          sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 24),
        );
      }
      final sourceFile = File('${temporaryDirectory.path}/source score.pdf');
      await sourceFile.writeAsBytes(sourceDocument.saveSync(), flush: true);
      sourceDocument.dispose();

      final storage = FileStorageService(rootOverride: temporaryDirectory);
      final importedPath = await storage.importPdf(
        sourceFile.path,
        originalName: 'Imported iOS Score.pdf',
      );
      expect(await storage.isManagedPath(importedPath), isTrue);
      expect(await File(importedPath).exists(), isTrue);

      final practiceProvider = PracticeProvider();
      addTearDown(practiceProvider.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: practiceProvider),
            ChangeNotifierProvider(
              create: (_) => LocalizationProvider(initialLocale: 'en'),
            ),
          ],
          child: MaterialApp(
            home: ScoreViewerScreen(
              pieceId: 'ios_imported_score',
              pdfPath: importedPath,
              pieceTitle: 'Imported iOS Score',
              pieceBpm: 84,
            ),
          ),
        ),
      );

      await _pumpUntilEnabled(tester, find.byTooltip('Score display options'));
      expect(find.text('Imported iOS Score'), findsOneWidget);

      await tester.tap(find.byTooltip('Score display options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuous'));
      await tester.pumpAndSettle();
      await _scrollIntoView(tester, find.text('Sepia'));
      await tester.tap(find.text('Sepia'));
      await _scrollIntoView(tester, find.text('Duration'));
      await tester.tap(find.text('Duration'));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));

      final preferences = DatabaseService().getScoreViewPreferences(
        'ios_imported_score',
      );
      expect(preferences?.layoutMode, ScoreLayoutMode.continuous);
      expect(preferences?.colorMode, ScoreColorMode.sepia);
      expect(preferences?.autoScrollPaceMode, AutoScrollPaceMode.duration);

      await tester.tap(find.text('Annotate'));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(120, 300), const Offset(130, 70));
      await tester.pump(const Duration(seconds: 1));

      final annotations = DatabaseService().getPdfAnnotations(
        'ios_imported_score',
      );
      expect(annotations?.hasAnnotations, isTrue);
      final exportedBytes = await SyncfusionAnnotatedPdfExporter().build(
        sourcePath: importedPath,
        annotations: annotations!,
      );
      expect(String.fromCharCodes(exportedBytes.take(4)), '%PDF');
      final exportedDocument = sf.PdfDocument(inputBytes: exportedBytes);
      expect(exportedDocument.pages.count, 2);
      exportedDocument.dispose();

      await tester.tap(find.byTooltip('Performance mode'));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byType(Scaffold)));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Exit performance mode'), findsOneWidget);
      await tester.tap(find.byTooltip('Lock touch page turns'));
      await tester.tap(find.byTooltip('Automatic scrolling'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byTooltip('Automatic scrolling'));
      await tester.tap(find.byTooltip('Exit performance mode'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Performance mode'), findsOneWidget);
    },
  );
}

Future<void> _pumpUntilEnabled(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isEmpty) continue;
    final iconButton = find.ancestor(
      of: finder.first,
      matching: find.byType(IconButton),
    );
    if (iconButton.evaluate().isEmpty) continue;
    final button = tester.widget<IconButton>(iconButton.first);
    if (button.onPressed != null) return;
  }
  fail('Timed out waiting for the score-view action to become enabled.');
}

Future<void> _scrollIntoView(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}
