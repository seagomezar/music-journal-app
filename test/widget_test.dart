import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flute/models/user_profile.dart';
import 'package:flute/models/exercise.dart';
import 'package:flute/models/routine.dart';
import 'package:flute/models/piece.dart';
import 'package:flute/models/session_record.dart';
import 'package:flute/providers/localization_provider.dart';
import 'package:flute/providers/history_provider.dart';
import 'package:flute/providers/practice_provider.dart';
import 'package:flute/providers/routine_provider.dart';
import 'package:flute/screens/manual_session_screen.dart';
import 'package:flute/services/audio_service.dart';
import 'package:flute/services/file_storage_service.dart';
import 'package:provider/provider.dart';

class FakeAudioService extends AudioService {
  bool recording = false;
  bool playing = false;
  int stopRecordingCalls = 0;
  int deleteRecordingCalls = 0;

  @override
  bool get isRecording => recording;

  @override
  bool get isPlaying => playing;

  @override
  Future<void> startRecording() async {
    recording = true;
  }

  @override
  Future<String?> stopRecording() async {
    stopRecordingCalls++;
    if (!recording) return null;
    recording = false;
    return '/managed/practice.m4a';
  }

  @override
  Future<void> stopPlayback() async {
    playing = false;
  }

  @override
  Future<void> deleteRecording(String? path) async {
    deleteRecordingCalls++;
    recording = false;
    playing = false;
  }

  @override
  Future<void> dispose() async {}
}

class FakeHistoryProvider extends HistoryProvider {
  SessionRecord? savedSession;

  @override
  Future<void> saveSession(SessionRecord session) async {
    savedSession = session;
  }
}

class FakeRoutineProvider extends RoutineProvider {
  @override
  List<Routine> get routines => const [];

  @override
  Future<void> loadRoutines() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  group('Data Models Tests', () {
    test('UserProfile JSON serialization', () {
      final profile = UserProfile(
        id: 'u1',
        name: 'Alex Flutist',
        email: 'alex@flute.com',
        weeklyPracticeGoalMinutes: 180,
      );

      final json = profile.toJson();
      expect(json['id'], 'u1');
      expect(json['name'], 'Alex Flutist');
      expect(json['email'], 'alex@flute.com');
      expect(json['weeklyPracticeGoalMinutes'], 180);

      final parsed = UserProfile.fromJson(json);
      expect(parsed.id, 'u1');
      expect(parsed.name, 'Alex Flutist');
      expect(parsed.email, 'alex@flute.com');
      expect(parsed.weeklyPracticeGoalMinutes, 180);
    });

    test('Exercise and Routine models', () {
      final exercise = Exercise(
        id: 'ex1',
        name: 'Legato Scale',
        targetBpm: 90,
        articulation: 'Legato',
      );

      final routine = Routine(
        id: 'r1',
        title: 'Daily Scale Routine',
        description: 'Scales in all keys',
        exercises: [exercise],
      );

      final json = routine.toJson();
      expect(json['title'], 'Daily Scale Routine');
      expect(json['exercises'].length, 1);
      expect(json['exercises'][0]['name'], 'Legato Scale');

      final parsed = Routine.fromJson(json);
      expect(parsed.title, 'Daily Scale Routine');
      expect(parsed.exercises.length, 1);
      expect(parsed.exercises[0].name, 'Legato Scale');
      expect(parsed.exercises[0].targetBpm, 90);
    });

    test('Piece progress calculation', () {
      final piece = Piece(
        id: 'p1',
        title: 'Syrinx',
        composer: 'Debussy',
        targetBpm: 60,
        measuresTotal: 40,
        measuresCompleted: 10,
      );

      expect(piece.progressPercentage, 0.25);
    });

    test('Piece JSON clamps unsafe persisted values', () {
      final parsed = Piece.fromJson({
        'id': 'p2',
        'title': 'Unsafe values',
        'targetBpm': 1000,
        'measuresTotal': -5,
        'measuresCompleted': 40,
      });

      expect(parsed.targetBpm, 240);
      expect(parsed.measuresTotal, 0);
      expect(parsed.measuresCompleted, 0);
    });
  });

  group('PracticeProvider Tests', () {
    test('Initial practice session state', () {
      final provider = PracticeProvider();
      expect(provider.isActive, false);
      expect(provider.isPaused, false);
      expect(provider.secondsElapsed, 0);
      expect(provider.completedExerciseIds.isEmpty, true);
      provider.dispose();
    });

    test('Starting a session', () async {
      final provider = PracticeProvider();
      final routine = Routine(
        id: 'r1',
        title: 'Morning Scales',
        description: 'Scales in all keys',
        exercises: [
          Exercise(
            id: 'ex1',
            name: 'Legato Scale',
            targetBpm: 90,
            articulation: 'Legato',
          ),
        ],
      );

      provider.startSession(routine);

      expect(provider.isActive, true);
      expect(provider.isPaused, false);
      expect(provider.activeRoutine?.title, 'Morning Scales');

      await provider.cancelSession();
      expect(provider.isActive, false);
      provider.dispose();
    });

    test('Closing the recorder stops capture before resuming', () async {
      final audio = FakeAudioService();
      final provider = PracticeProvider(audioService: audio);
      provider.startSession(null);
      provider.activateAudioRecorder();
      await provider.startRecording();

      await provider.resumeSession();

      expect(audio.recording, false);
      expect(audio.stopRecordingCalls, 1);
      expect(provider.isAudioRecorderActive, false);
      expect(provider.isPaused, false);
      await provider.cancelSession();
      provider.dispose();
    });

    test(
      'Preparing a session stops capture but waits to reset state',
      () async {
        final audio = FakeAudioService();
        final provider = PracticeProvider(audioService: audio);
        provider.startSession(null);
        provider.activateAudioRecorder();
        await provider.startRecording();

        final record = await provider.prepareSessionRecord(const []);

        expect(audio.recording, false);
        expect(record?.audioFilePath, '/managed/practice.m4a');
        expect(provider.isActive, true);
        provider.completeSession();
        expect(provider.isActive, false);
        provider.dispose();
      },
    );

    test('Canceling a session discards its recording', () async {
      final audio = FakeAudioService();
      final provider = PracticeProvider(audioService: audio);
      provider.startSession(null);
      provider.activateAudioRecorder();
      await provider.startRecording();

      await provider.cancelSession();

      expect(audio.recording, false);
      expect(audio.deleteRecordingCalls, 1);
      expect(provider.isActive, false);
      provider.dispose();
    });

    test('Metronome BPM is clamped to the supported range', () {
      final provider = PracticeProvider(audioService: FakeAudioService());
      provider.setMetronomeBpm(-10);
      expect(provider.metronomeBpm, 40);
      provider.setMetronomeBpm(1000);
      expect(provider.metronomeBpm, 240);
      provider.dispose();
    });
  });

  group('Managed file storage', () {
    test('imports and deletes a PDF inside app-owned storage', () async {
      final root = await Directory.systemTemp.createTemp('flute_storage_test_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final source = File('${root.path}${Platform.pathSeparator}source.pdf');
      await source.writeAsBytes([0x25, 0x50, 0x44, 0x46]);
      final service = FileStorageService(rootOverride: root);

      final imported = await service.importPdf(
        source.path,
        originalName: 'My Score.pdf',
      );

      expect(await File(imported).exists(), true);
      expect(await service.isManagedPath(imported), true);
      await service.deleteManagedFile(imported);
      expect(await File(imported).exists(), false);
    });
  });

  testWidgets('translations are safe inside event callbacks', (tester) async {
    String? translated;

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LocalizationProvider(initialLocale: 'en'),
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => translated = context.translate('app_title'),
              child: const Text('Translate'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Translate'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(translated, 'Flute Practice Coach');
  });

  testWidgets('a past session can be entered manually', (tester) async {
    final history = FakeHistoryProvider();
    final routines = FakeRoutineProvider();
    final initialDate = DateTime.now().subtract(const Duration(days: 1));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocalizationProvider>.value(
            value: LocalizationProvider(initialLocale: 'en'),
          ),
          ChangeNotifierProvider<HistoryProvider>.value(value: history),
          ChangeNotifierProvider<RoutineProvider>.value(value: routines),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ManualSessionScreen(initialDate: initialDate),
                    ),
                  ),
                  child: const Text('Open form'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    expect(find.text('Log Past Session'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '45');
    await tester.enterText(fields.at(1), 'Manually logged practice');
    final saveSession = find.text('Save Session');
    await tester.ensureVisible(saveSession);
    await tester.tap(saveSession);
    await tester.pumpAndSettle();

    expect(history.savedSession, isNotNull);
    expect(history.savedSession!.totalDurationInSeconds, 2700);
    expect(history.savedSession!.notes, 'Manually logged practice');
    expect(history.savedSession!.audioFilePath, isNull);
    expect(history.savedSession!.localStartTime.day, initialDate.day);
  });
}
