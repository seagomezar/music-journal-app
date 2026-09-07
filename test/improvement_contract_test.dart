import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flute/models/exercise.dart';
import 'package:flute/models/history_summary.dart';
import 'package:flute/models/routine.dart';
import 'package:flute/models/session_record.dart';
import 'package:flute/providers/history_provider.dart';
import 'package:flute/providers/localization_provider.dart';
import 'package:flute/providers/routine_provider.dart';
import 'package:flute/screens/manual_session_screen.dart';
import 'package:flute/services/journal_backup_service.dart';
import 'package:flute/services/seed_localization.dart';
import 'widget_test.dart' show FakeHistoryProvider, FakeRoutineProvider;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });
  testWidgets('editing notes preserves recorded exercise results and media', (
    tester,
  ) async {
    final exercise = Exercise(
      id: 'exercise',
      name: 'Long tones',
      targetBpm: 80,
      articulation: 'Legato',
    );
    final original = SessionRecord(
      id: 'saved',
      startTime: DateTime(2026, 1, 2, 10, 0, 12),
      endTime: DateTime(2026, 1, 2, 10, 10, 15),
      totalDurationInSeconds: 603,
      completedExercises: [exercise],
      exerciseResults: [
        SessionExerciseRecord(
          exercise: exercise,
          durationInSeconds: 500,
          practicedBpm: 90,
        ),
      ],
      rehearsedPieces: [],
      notes: 'Original note',
      audioFilePath: '/recordings/take.m4a',
    );
    final history = FakeHistoryProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<HistoryProvider>.value(value: history),
          ChangeNotifierProvider<RoutineProvider>(
            create: (_) => FakeRoutineProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => LocalizationProvider(initialLocale: 'en'),
          ),
        ],
        child: MaterialApp(
          home: ManualSessionScreen(
            initialDate: original.localStartTime,
            session: original,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Corrected note');
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();
    final saved = history.savedSession!;
    expect(saved.id, original.id);
    expect(saved.notes, 'Corrected note');
    expect(saved.startTime, original.startTime);
    expect(saved.totalDurationInSeconds, 603);
    expect(saved.exerciseResults.single.practicedBpm, 90);
    expect(saved.recordings.single.storagePath, '/recordings/take.m4a');
  });

  test('published v3 tempo contract accepts both supported endpoints', () {
    final schema =
        jsonDecode(
              File('docs/journal-backup-schema-v3.json').readAsStringSync(),
            )
            as Map;
    final definitions = schema[r'$defs'] as Map;
    for (final bpm in [30, 252]) {
      final source = JournalBackupService().createBackup(
        routines: [
          Routine(
            id: 'r',
            title: 'Routine',
            description: '',
            exercises: [
              Exercise(
                id: 'e',
                name: 'Exercise',
                targetBpm: bpm,
                articulation: 'Legato',
              ),
            ],
          ),
        ],
        sessions: [],
        appVersion: '1.0.0',
      );
      final exportedBpm =
          (jsonDecode(source)['routines'][0]['exercises'][0]['targetBpm'])
              as int;
      final rule = definitions['exercise']['properties']['targetBpm'] as Map;
      expect(
        exportedBpm,
        inInclusiveRange(rule['minimum'] as num, rule['maximum'] as num),
      );
      expect(definitions['exerciseResult']['properties']['practicedBpm'], rule);
    }
  });

  test('seed localization preserves customized content', () {
    final routine = Routine(
      id: 'warmup_default',
      title: 'My custom title',
      description: '',
      exercises: [
        Exercise(
          id: 'w1',
          name: 'Long Tones (Low Register)',
          targetBpm: 120,
          articulation: 'Legato',
        ),
      ],
    );
    final spanish = localizeSeedRoutine(routine, 'es');
    expect(spanish.title, 'My custom title');
    expect(spanish.exercises.single.name, 'Notas largas (registro grave)');
    expect(spanish.exercises.single.targetBpm, 120);
  });

  test('large-journal summary indexes days and computes aggregates once', () {
    final records = List.generate(100000, (i) {
      final time = DateTime(2000).add(Duration(minutes: i * 60));
      return SessionRecord(
        id: '$i',
        startTime: time,
        endTime: time.add(const Duration(minutes: 30)),
        totalDurationInSeconds: 1800,
        completedExercises: [],
        rehearsedPieces: [],
        notes: '',
      );
    });
    final watch = Stopwatch()..start();
    final summary = HistorySummary(records);
    watch.stop();
    expect(summary.totalSeconds, 180000000);
    expect(
      summary.byDay.values.fold<int>(0, (sum, rows) => sum + rows.length),
      100000,
    );
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    // Report timing as evidence, not a physical-device performance claim.
    debugPrint('100,000-session summary: ${watch.elapsedMilliseconds} ms');
  });
}
