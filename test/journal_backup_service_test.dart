import 'dart:convert';
import 'dart:typed_data';

import 'package:flute/models/exercise.dart';
import 'package:flute/models/routine.dart';
import 'package:flute/models/session_record.dart';
import 'package:flute/models/session_recording.dart';
import 'package:flute/models/pitch_tracking.dart';
import 'package:flute/services/journal_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = JournalBackupService();
  final exercise = Exercise(
    id: 'exercise-1',
    name: 'Long tones',
    targetBpm: 60,
    articulation: 'Legato',
  );
  final routine = Routine(
    id: 'routine-1',
    title: 'Warmup',
    description: 'Daily fundamentals',
    exercises: [exercise],
  );
  final session = SessionRecord(
    id: 'session-1',
    startTime: DateTime.utc(2026, 7, 20, 15),
    endTime: DateTime.utc(2026, 7, 20, 15, 30),
    startUtcOffsetMinutes: -300,
    endUtcOffsetMinutes: -300,
    totalDurationInSeconds: 1800,
    completedExercises: [exercise],
    exerciseResults: [
      SessionExerciseRecord(
        exercise: exercise,
        durationInSeconds: 300,
        practicedBpm: 66,
        pitchSummary: const ExercisePitchSummary(
          inTuneMilliseconds: 240000,
          analyzedMilliseconds: 270000,
          trackingMilliseconds: 300000,
          referenceHz: 440,
          toleranceCents: 10,
        ),
      ),
    ],
    rehearsedPieces: [
      SessionPieceRecord(
        pieceId: 'piece-1',
        pieceTitle: 'Syrinx',
        durationInSeconds: 600,
        measuresWorked: 4,
      ),
    ],
    notes: 'Worked slowly.',
    audioFilePath: '/private/device/recording.m4a',
  );

  test('round trips routines and sessions without media paths', () {
    final source = service.createBackup(
      routines: [routine],
      sessions: [session],
      appVersion: '1.0.0',
      exportedAt: DateTime.utc(2026, 7, 24, 12),
    );

    expect(source, isNot(contains('audioFilePath')));
    expect(source, isNot(contains('/private/device')));
    expect(source, isNot(contains('pdfPath')));

    final decoded = service.parseBytes(Uint8List.fromList(utf8.encode(source)));
    expect(decoded.routines.single.title, 'Warmup');
    expect(decoded.sessions.single.notes, 'Worked slowly.');
    expect(decoded.sessions.single.audioFilePath, isNull);
    expect(decoded.sessions.single.startUtcOffsetMinutes, -300);
    expect(decoded.sessions.single.localStartTime.hour, 10);
    expect(
      decoded.sessions.single.exerciseResults.single.durationInSeconds,
      300,
    );
    expect(decoded.sessions.single.exerciseResults.single.practicedBpm, 66);
    expect(
      decoded
          .sessions
          .single
          .exerciseResults
          .single
          .pitchSummary!
          .onPitchPercentage,
      closeTo(88.89, 0.01),
    );
  });

  test('excludes all recording metadata from journal backups', () {
    final withRecordings = session.copyWith(
      recordings: [
        SessionRecording(
          id: 'recording-1',
          name: 'Final take',
          createdAt: DateTime.utc(2026, 7, 20, 15, 1),
          storagePath: '/private/device/final.m4a',
        ),
      ],
    );

    final source = service.createBackup(
      routines: const [],
      sessions: [withRecordings],
      appVersion: '1.0.0',
    );

    expect(source, isNot(contains('recording-1')));
    expect(source, isNot(contains('Final take')));
    expect(source, isNot(contains('/private/device/final.m4a')));
    final decoded = service.parseBytes(Uint8List.fromList(utf8.encode(source)));
    expect(decoded.sessions.single.recordings, isEmpty);
  });

  test('imports version 2 exercise results without pitch summaries', () {
    final document =
        jsonDecode(
              service.createBackup(
                routines: [routine],
                sessions: [session],
                appVersion: '1.0.0',
              ),
            )
            as Map<String, dynamic>;
    document['schemaVersion'] = 2;
    final sessions = document['sessions'] as List<dynamic>;
    final results =
        (sessions.single as Map<String, dynamic>)['exerciseResults']
            as List<dynamic>;
    (results.single as Map<String, dynamic>).remove('pitchSummary');

    final decoded = service.parseBytes(
      Uint8List.fromList(utf8.encode(jsonEncode(document))),
    );
    expect(decoded.sessions.single.exerciseResults.single.pitchSummary, isNull);
  });

  test('imports version 1 sessions without exercise results', () {
    final source = service.createBackup(
      routines: [routine],
      sessions: [session],
      appVersion: '1.0.0',
    );
    final document = jsonDecode(source) as Map<String, dynamic>;
    document['schemaVersion'] = 1;
    final sessions = document['sessions'] as List<dynamic>;
    (sessions.single as Map<String, dynamic>).remove('exerciseResults');

    final decoded = service.parseBytes(
      Uint8List.fromList(utf8.encode(jsonEncode(document))),
    );

    expect(decoded.sessions.single.completedExercises, hasLength(1));
    expect(decoded.sessions.single.exerciseResults, isEmpty);
  });

  test('rejects unexpected fields that could smuggle a device path', () {
    final source = service.createBackup(
      routines: [routine],
      sessions: [session],
      appVersion: '1.0.0',
    );
    final document = jsonDecode(source) as Map<String, dynamic>;
    final sessions = document['sessions'] as List<dynamic>;
    (sessions.single as Map<String, dynamic>)['audioFilePath'] = '/tmp/a.m4a';

    expect(
      () => service.parseBytes(
        Uint8List.fromList(utf8.encode(jsonEncode(document))),
      ),
      throwsA(isA<JournalBackupException>()),
    );
  });

  test('rejects unsupported future schema versions', () {
    final source = service.createBackup(
      routines: const [],
      sessions: const [],
      appVersion: '1.0.0',
    );
    final document = jsonDecode(source) as Map<String, dynamic>;
    document['schemaVersion'] = JournalBackupService.schemaVersion + 1;

    expect(
      () => service.parseBytes(
        Uint8List.fromList(utf8.encode(jsonEncode(document))),
      ),
      throwsA(isA<JournalBackupException>()),
    );
  });

  test(
    'an identical imported session preserves its local audio attachment',
    () {
      final source = service.createBackup(
        routines: [routine],
        sessions: [session],
        appVersion: '1.0.0',
      );
      final backup = service.parseBytes(
        Uint8List.fromList(utf8.encode(source)),
      );

      final plan = service.createImportPlan(
        backup: backup,
        existingRoutines: [routine],
        existingSessions: [session],
      );

      expect(plan.routinesToAdd, isEmpty);
      expect(plan.sessionsToAdd, isEmpty);
      expect(plan.skippedCount, 2);
      expect(session.audioFilePath, '/private/device/recording.m4a');
    },
  );

  test(
    'conflicts are cloned deterministically and re-imports are idempotent',
    () {
      final source = service.createBackup(
        routines: const [],
        sessions: [session],
        appVersion: '1.0.0',
      );
      final backup = service.parseBytes(
        Uint8List.fromList(utf8.encode(source)),
      );
      final conflicting = SessionRecord(
        id: session.id,
        startTime: session.startTime,
        endTime: session.endTime,
        startUtcOffsetMinutes: session.startUtcOffsetMinutes,
        endUtcOffsetMinutes: session.endUtcOffsetMinutes,
        totalDurationInSeconds: session.totalDurationInSeconds,
        completedExercises: session.completedExercises,
        exerciseResults: session.exerciseResults,
        rehearsedPieces: session.rehearsedPieces,
        notes: 'Different local record',
        audioFilePath: '/private/existing.m4a',
      );

      final first = service.createImportPlan(
        backup: backup,
        existingRoutines: const [],
        existingSessions: [conflicting],
      );
      expect(first.sessionConflicts, 1);
      expect(first.sessionsToAdd, hasLength(1));
      expect(first.sessionsToAdd.single.id, startsWith('import_session_'));
      expect(first.sessionsToAdd.single.audioFilePath, isNull);

      final second = service.createImportPlan(
        backup: backup,
        existingRoutines: const [],
        existingSessions: [conflicting, first.sessionsToAdd.single],
      );
      expect(second.sessionsToAdd, isEmpty);
      expect(second.skippedSessions, 1);
    },
  );
}
