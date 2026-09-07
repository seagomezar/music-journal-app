import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:flute/models/exercise.dart';
import 'package:flute/models/routine.dart';
import 'package:flute/models/piece.dart';
import 'package:flute/models/pdf_annotation.dart';
import 'package:flute/models/score_view_preferences.dart';
import 'package:flute/models/session_record.dart';
import 'package:flute/models/session_recording.dart';
import 'package:flute/models/user_profile.dart';
import 'package:flute/services/database_service.dart';
import 'package:flute/services/full_backup_service.dart';
import 'package:flute/services/file_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final db = DatabaseService();
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flute_backup_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
    await db.init();
    await db.clearAllUserData();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'full restore retains media, score ink, links, profile and preferences',
    () async {
      final storage = FileStorageService();
      final source = File('${directory.path}/score.pdf');
      await source.writeAsBytes(utf8.encode('%PDF-1.4 sample'));
      final pdf = await storage.importPdf(source.path);
      final audio = await storage.createRecordingPath();
      await File(audio).writeAsBytes([4, 5, 6]);
      final exercise = Exercise(
        id: 'exercise',
        name: 'Etude',
        targetBpm: 252,
        articulation: 'Legato',
        musicSheetPieceId: 'piece',
      );
      await db.saveUserProfile(
        UserProfile(
          id: 'local_profile',
          name: 'Flutist',
          weeklyPracticeGoalMinutes: 180,
        ),
      );
      await db.setPreferredLocale('es');
      await db.setMetronomeVolume(0.2);
      await db.saveRoutine(
        Routine(
          id: 'routine',
          title: 'Warmup',
          description: '',
          exercises: [exercise],
        ),
      );
      await db.savePiece(
        Piece(
          id: 'piece',
          title: 'Etude',
          composer: '',
          targetBpm: 30,
          pdfPath: pdf,
        ),
      );
      await db.savePdfAnnotations(
        PdfAnnotationDocument(
          pieceId: 'piece',
          sourcePath: pdf,
          pages: {
            1: [
              const PdfInkStroke(
                points: [PdfAnnotationPoint(x: 0.1, y: 0.2)],
                colorArgb: 0xff000000,
                widthInPdfPoints: 2,
              ),
            ],
          },
        ),
      );
      await db.saveScoreViewPreferences(
        ScoreViewPreferences(pieceId: 'piece', sourcePath: pdf, lastPage: 3),
      );
      final now = DateTime.now();
      await db.saveSession(
        SessionRecord(
          id: 'session',
          startTime: now,
          endTime: now,
          totalDurationInSeconds: 120,
          completedExercises: [exercise],
          rehearsedPieces: [],
          notes: 'Keep this',
          recordings: [
            SessionRecording(
              id: 'take',
              name: 'My take',
              createdAt: now,
              storagePath: audio,
            ),
          ],
        ),
      );
      final service = FullBackupService();
      final bytes = await service.create(db);
      final backup = service.parse(bytes);
      expect(jsonEncode(backup.records), isNot(contains(directory.path)));
      expect(backup.media.length, 2);
      await db.clearAllUserData();
      await db.writeSessionDraft({'sessionId': 'old-unfinished-session'});
      await service.restore(db, backup);
      expect(db.readSessionDraft(), isNull);
      expect(db.getUserProfile()!.name, 'Flutist');
      expect(db.getPreferredLocale(), 'es');
      expect(db.getMetronomeVolume(), 0.2);
      expect(
        db.getRoutines().single.exercises.single.musicSheetPieceId,
        'piece',
      );
      final restoredPiece = db.getPieces().single;
      expect(
        await File(restoredPiece.pdfPath!).readAsString(),
        '%PDF-1.4 sample',
      );
      expect(db.getPdfAnnotations('piece')!.sourcePath, restoredPiece.pdfPath);
      expect(db.getPdfAnnotations('piece')!.hasAnnotations, true);
      expect(
        db.getScoreViewPreferences('piece')!.sourcePath,
        restoredPiece.pdfPath,
      );
      expect(db.getScoreViewPreferences('piece')!.lastPage, 3);
      expect(
        await File(
          db.getSessions().single.recordings.single.storagePath,
        ).readAsBytes(),
        [4, 5, 6],
      );
    },
  );

  test('rejects traversal entries without touching the journal', () {
    final zip = Archive()..add(ArchiveFile('../escape', 1, [1]));
    expect(
      () => FullBackupService().parse(
        Uint8List.fromList(ZipEncoder().encode(zip)),
      ),
      throwsFormatException,
    );
  });

  test('startup restore keeps originals until explicit data erasure', () async {
    await db.saveUserProfile(
      UserProfile(
        id: 'original',
        name: 'Keep original',
        weeklyPracticeGoalMinutes: 120,
      ),
    );
    final service = FullBackupService();
    final backup = service.parse(await service.create(db));
    db.needsRecovery.value = true;
    await db.initializeRecoveryDatabase();
    expect(
      db.needsRecovery.value,
      true,
      reason: 'The recovery UI must stay mounted until restore finishes.',
    );
    await service.restore(db, backup);
    await db.activateRecoveryDatabase();
    expect(db.getUserProfile()!.name, 'Keep original');
    expect(Hive.box('flute_profile').get('active_user'), isNotNull);
    final bootstrap = Hive.box('flute_bootstrap');
    expect(bootstrap.get('generation'), startsWith('_recovered_'));
    await db.clearAllUserData();
    expect(await Hive.boxExists('flute_profile'), false);
    expect(db.getUserProfile(), isNull);
    db.needsRecovery.value = false;
  });

  test(
    'portable references rebase after an application directory move',
    () async {
      final oldRoot = Directory('${directory.path}/old-container');
      final newRoot = Directory('${directory.path}/new-container');
      final oldStorage = FileStorageService(rootOverride: oldRoot);
      final newStorage = FileStorageService(rootOverride: newRoot);
      await oldStorage.initialize();
      await newStorage.initialize();
      final oldPath = await oldStorage.createRecordingPath();
      final identifier = oldStorage.portablePath(oldPath);
      await newStorage.writeMedia(identifier, Uint8List.fromList([1, 2, 3]));
      expect(newStorage.resolveStoredPath(oldPath), startsWith(newRoot.path));
      expect(await newStorage.readMedia(oldPath), [1, 2, 3]);
    },
  );

  test(
    'restore repairs a corrupted existing content-addressed attachment',
    () async {
      final storage = FileStorageService();
      final pdf = File('${directory.path}/source.pdf');
      await pdf.writeAsBytes([1, 2, 3]);
      final managed = await storage.importPdf(pdf.path);
      await db.savePiece(
        Piece(
          id: 'repair',
          title: 'Score',
          composer: '',
          targetBpm: 80,
          pdfPath: managed,
        ),
      );
      final service = FullBackupService();
      final backup = service.parse(await service.create(db));
      final identifier = backup.media.keys.single;
      await storage.writeMedia(identifier, Uint8List.fromList([9, 9]));
      await service.restore(db, backup);
      expect(await storage.readMedia(identifier), [1, 2, 3]);
    },
  );

  test('rejects corrupted media before changing saved records', () async {
    final storage = FileStorageService();
    final pdf = File('${directory.path}/source.pdf');
    await pdf.writeAsBytes([1, 2, 3]);
    final managed = await storage.importPdf(pdf.path);
    await db.savePiece(
      Piece(
        id: 'integrity',
        title: 'Score',
        composer: '',
        targetBpm: 80,
        pdfPath: managed,
      ),
    );
    final service = FullBackupService();
    final archive = ZipDecoder().decodeBytes(await service.create(db));
    final altered = Archive();
    for (final file in archive) {
      altered.add(
        file.name.startsWith('media/')
            ? ArchiveFile(file.name, 3, [9, 9, 9])
            : file,
      );
    }
    expect(
      () => service.parse(Uint8List.fromList(ZipEncoder().encode(altered))),
      throwsFormatException,
    );
    expect(db.getPieces().single.title, 'Score');
  });

  test('a missing attachment prevents an incomplete backup download', () async {
    await db.savePiece(
      Piece(
        id: 'missing',
        title: 'Score',
        composer: '',
        targetBpm: 80,
        pdfPath: '${directory.path}/missing.pdf',
      ),
    );
    await expectLater(
      FullBackupService().create(db),
      throwsA(isA<FileSystemException>()),
    );
  });
}
