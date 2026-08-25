import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_document/pdf_document.dart' as pdf;

import 'package:flute/models/pdf_annotation.dart';
import 'package:flute/models/exercise.dart';
import 'package:flute/models/piece.dart';
import 'package:flute/models/routine.dart';
import 'package:flute/models/score_view_preferences.dart';
import 'package:flute/services/annotated_pdf_export_service.dart';
import 'package:flute/services/database_service.dart';
import 'package:flute/services/pdf_annotation_service.dart';
import 'package:flute/services/score_view_preferences_service.dart';

PdfAnnotationDocument _annotations({String sourcePath = '/scores/etude.pdf'}) {
  return PdfAnnotationDocument(
    pieceId: 'piece_1',
    sourcePath: sourcePath,
    pages: const {
      1: [
        PdfInkStroke(
          colorArgb: 0xff336699,
          widthInPdfPoints: 4,
          points: [
            PdfAnnotationPoint(x: 0.1, y: 0.2),
            PdfAnnotationPoint(x: 0.75, y: 0.8),
          ],
        ),
      ],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory databaseDirectory;

  setUpAll(() async {
    databaseDirectory = await Directory.systemTemp.createTemp(
      'flute_pdf_annotations_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => databaseDirectory.path,
        );
    await DatabaseService().init();
  });

  setUp(() async {
    await DatabaseService().clearAllUserData();
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (await databaseDirectory.exists()) {
      await databaseDirectory.delete(recursive: true);
    }
  });

  test('annotation documents preserve page-relative ink data', () {
    final restored = PdfAnnotationDocument.fromJson(_annotations().toJson());

    expect(restored.pieceId, 'piece_1');
    expect(restored.sourcePath, '/scores/etude.pdf');
    expect(restored.hasAnnotations, isTrue);
    expect(restored.pages[1]!.single.colorArgb, 0xff336699);
    expect(restored.pages[1]!.single.widthInPdfPoints, 4);
    expect(restored.pages[1]!.single.points.last.x, 0.75);
    expect(restored.pages[1]!.single.points.last.y, 0.8);
  });

  test('saved annotations are scoped to the current source PDF', () async {
    final service = PdfAnnotationService();
    await service.save(_annotations());

    final restored = await service.load(
      pieceId: 'piece_1',
      sourcePath: '/scores/etude.pdf',
    );
    expect(restored.hasAnnotations, isTrue);

    final replacement = await service.load(
      pieceId: 'piece_1',
      sourcePath: '/scores/replacement.pdf',
    );
    expect(replacement.hasAnnotations, isFalse);
    expect(replacement.sourcePath, '/scores/replacement.pdf');
    expect(DatabaseService().getPdfAnnotations('piece_1'), isNull);
  });

  test('deleting a repertoire piece also deletes its annotations', () async {
    await DatabaseService().savePiece(
      Piece(
        id: 'piece_1',
        title: 'Etude',
        composer: 'Composer',
        targetBpm: 80,
        pdfPath: '/scores/etude.pdf',
      ),
    );
    await DatabaseService().saveRoutine(
      Routine(
        id: 'routine_1',
        title: 'Routine',
        description: '',
        exercises: [
          Exercise(
            id: 'exercise_1',
            name: 'Etude drill',
            targetBpm: 80,
            articulation: 'Legato',
            musicSheetPieceId: 'piece_1',
          ),
        ],
      ),
    );
    await DatabaseService().savePdfAnnotations(_annotations());
    await DatabaseService().saveScoreViewPreferences(
      const ScoreViewPreferences(
        pieceId: 'piece_1',
        sourcePath: '/scores/etude.pdf',
        lastPage: 4,
      ),
    );
    expect(DatabaseService().getPdfAnnotations('piece_1'), isNotNull);
    expect(DatabaseService().getScoreViewPreferences('piece_1'), isNotNull);

    await DatabaseService().deletePiece('piece_1');

    expect(DatabaseService().getPdfAnnotations('piece_1'), isNull);
    expect(DatabaseService().getScoreViewPreferences('piece_1'), isNull);
    expect(
      DatabaseService().getRoutines().single.exercises.single.musicSheetPieceId,
      isNull,
    );
  });

  test('score view preferences reset when the PDF is replaced', () async {
    final service = ScoreViewPreferencesService();
    await service.save(
      const ScoreViewPreferences(
        pieceId: 'piece_1',
        sourcePath: '/scores/etude.pdf',
        layoutMode: ScoreLayoutMode.twoPage,
        lastPage: 6,
      ),
    );

    final replacement = await service.load(
      pieceId: 'piece_1',
      sourcePath: '/scores/replacement.pdf',
    );

    expect(replacement.layoutMode, ScoreLayoutMode.singlePage);
    expect(replacement.lastPage, 1);
    expect(replacement.sourcePath, '/scores/replacement.pdf');
  });

  test('export creates a readable PDF with flattened ink', () {
    final sourceBytes = pdf.PdfBlankDocument.create();

    final exportedBytes = buildAnnotatedPdfBytes({
      'sourceBytes': sourceBytes,
      'annotations': _annotations().toJson(),
    });

    expect(exportedBytes, isNot(equals(sourceBytes)));
    expect(String.fromCharCodes(exportedBytes.take(4)), '%PDF');
    final exported = pdf.PdfDocument.open(exportedBytes);
    expect(exported.pageCount, 1);
    expect(exported.page(0).annotations, isEmpty);
  });
}
