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
import 'package:pdf_document/pdf_document.dart' as pdf;
import 'package:provider/provider.dart';

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

      final sourceFile = File('${temporaryDirectory.path}/source score.pdf');
      await sourceFile.writeAsBytes(
        pdf.PdfBlankDocument.create(pageCount: 2),
        flush: true,
      );

      final storage = FileStorageService(rootOverride: temporaryDirectory);
      final importedPath = await storage.importPdf(
        sourceFile.path,
        originalName: 'Imported iOS Score.pdf',
      );
      expect(await storage.isManagedPath(importedPath), isTrue);
      expect(await File(importedPath).exists(), isTrue);

      await DatabaseService().saveScoreViewPreferences(
        ScoreViewPreferences(
          pieceId: 'ios_imported_score',
          sourcePath: importedPath,
          layoutMode: ScoreLayoutMode.twoPage,
          fitMode: ScoreFitMode.fitWidth,
        ),
      );

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      final portraitPage = find.byKey(const ValueKey('score_page_overlay_1'));
      await _pumpUntilFound(tester, portraitPage);
      var pageRect = tester.getRect(portraitPage);
      var viewerTop = tester.getBottomLeft(find.byType(AppBar)).dy;
      var viewerBottom = tester.getTopLeft(find.byType(BottomNavigationBar)).dy;
      expect(pageRect.left, greaterThanOrEqualTo(0));
      expect(pageRect.right, lessThanOrEqualTo(390));
      expect(pageRect.top, greaterThanOrEqualTo(viewerTop));
      expect(pageRect.bottom, lessThanOrEqualTo(viewerBottom));

      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.text('1–2/2'), findsWidgets);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      await _pumpUntilFound(tester, portraitPage);
      pageRect = tester.getRect(portraitPage);
      viewerTop = tester.getBottomLeft(find.byType(AppBar)).dy;
      viewerBottom = tester.getTopLeft(find.byType(BottomNavigationBar)).dy;
      expect(pageRect.right, lessThanOrEqualTo(390));
      expect(pageRect.top, greaterThanOrEqualTo(viewerTop));
      expect(pageRect.bottom, lessThanOrEqualTo(viewerBottom));
      expect(tester.takeException(), isNull);

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
      final exportedBytes = await OpenSourceAnnotatedPdfExporter().build(
        sourcePath: importedPath,
        annotations: annotations!,
      );
      expect(String.fromCharCodes(exportedBytes.take(4)), '%PDF');
      final exportedDocument = pdf.PdfDocument.open(exportedBytes);
      expect(exportedDocument.pageCount, 2);

      await tester.tap(find.byTooltip('Performance mode'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('performance_controls_toggle')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('performance_controls')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('toggle_touch_lock')));
      await tester.tap(find.byKey(const ValueKey('toggle_auto_scroll')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('toggle_auto_scroll')));
      await tester.tap(find.byKey(const ValueKey('exit_performance_mode')));
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

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for the expected widget.');
}

Future<void> _scrollIntoView(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}
