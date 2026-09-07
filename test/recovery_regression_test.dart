import 'dart:io';

import 'package:flute/models/routine.dart';
import 'package:flute/models/session_record.dart';
import 'package:flute/models/session_recording.dart';
import 'package:flute/providers/history_provider.dart';
import 'package:flute/services/database_service.dart';
import 'package:flute/services/file_storage_service.dart';
import 'package:flute/services/journal_backup_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('damaged preferences fall back without blocking the journal', () async {
    final directory = await Directory.systemTemp.createTemp(
      'flute_preferences_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
    final db = DatabaseService();
    await db.init();
    addTearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
    await Hive.box('flute_profile').put('preferred_locale', false);
    await Hive.box('flute_profile').put('keep_screen_awake', 'damaged');
    await Hive.box('flute_profile').put('metronome_volume', 'damaged');
    expect(db.getPreferredLocale(), 'en');
    expect(db.getKeepScreenAwake(), false);
    expect(db.getMetronomeVolume(), 0.7);
    expect(db.damagedRecords.value, contains('preferences'));
  });

  test('failed recording deletion preserves the playable take', () async {
    final directory = await Directory.systemTemp.createTemp('flute_recovery_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
    final db = DatabaseService();
    await db.init();
    final path = await FileStorageService().createRecordingPath();
    await File(path).writeAsBytes([1, 2, 3]);
    final now = DateTime.now();
    final take = SessionRecording(
      id: 'take',
      name: 'Keep this take',
      createdAt: now,
      storagePath: path,
    );
    final session = SessionRecord(
      id: 'session',
      startTime: now,
      endTime: now,
      totalDurationInSeconds: 60,
      completedExercises: [],
      rehearsedPieces: [],
      notes: '',
      recordings: [take],
    );
    await db.saveSession(session);
    final history = HistoryProvider();
    await history.loadSessions();
    await Hive.box('flute_sessions').close();
    await expectLater(
      history.deleteRecording(session.id, take),
      throwsA(anything),
    );
    expect(
      await File(path).exists(),
      isTrue,
      reason: 'A failed journal update must not destroy the recording.',
    );
    history.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('oversized journal cannot be reported as a successful backup', () {
    final service = JournalBackupService();
    final routines = List.generate(
      6000,
      (i) => Routine(
        id: 'routine-$i',
        title: 'Routine $i',
        description: 'a' * 4000,
        exercises: [],
      ),
    );
    expect(
      () => service.createBackup(
        routines: routines,
        sessions: [],
        appVersion: '1.0.0',
      ),
      throwsA(isA<JournalBackupException>()),
    );
  });
}
