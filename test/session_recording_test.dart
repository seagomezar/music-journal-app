import 'package:flute/models/session_record.dart';
import 'package:flute/models/session_recording.dart';
import 'package:flute/providers/practice_provider.dart';
import 'package:flute/services/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates the legacy audio path into one named recording', () {
    final session = SessionRecord.fromJson({
      'id': 'session-legacy',
      'startTime': '2026-07-20T15:00:00.000Z',
      'endTime': '2026-07-20T15:30:00.000Z',
      'totalDurationInSeconds': 1800,
      'completedExercises': const [],
      'rehearsedPieces': const [],
      'notes': '',
      'audioFilePath': '/private/recording.m4a',
    });

    expect(session.recordings, hasLength(1));
    expect(session.recordings.single.id, 'legacy_session-legacy');
    expect(session.recordings.single.name, 'Recording 1');
    expect(session.recordings.single.storagePath, '/private/recording.m4a');
    expect(session.toJson(), isNot(contains('audioFilePath')));
  });

  test('round trips multiple recording metadata', () {
    final recordings = [
      SessionRecording(
        id: 'recording-1',
        name: 'Warm-up take',
        createdAt: DateTime.utc(2026, 7, 20, 15, 1),
        storagePath: '/recordings/one.m4a',
      ),
      SessionRecording(
        id: 'recording-2',
        name: 'Final take',
        createdAt: DateTime.utc(2026, 7, 20, 15, 2),
        storagePath: '/recordings/two.m4a',
      ),
    ];
    final source = SessionRecord(
      id: 'session-multiple',
      startTime: DateTime.utc(2026, 7, 20, 15),
      endTime: DateTime.utc(2026, 7, 20, 15, 30),
      totalDurationInSeconds: 1800,
      completedExercises: const [],
      rehearsedPieces: const [],
      notes: '',
      recordings: recordings,
    );

    final restored = SessionRecord.fromJson(source.toJson());

    expect(restored.recordings, hasLength(2));
    expect(restored.recordings.map((recording) => recording.name), [
      'Warm-up take',
      'Final take',
    ]);
  });

  test('active sessions retain and manage multiple recordings', () async {
    final audio = _FakeAudioService();
    final provider = PracticeProvider(audioService: audio);
    addTearDown(provider.dispose);

    provider.startSession(null);
    provider.activateAudioRecorder();
    await provider.startRecording();
    await provider.stopRecording();
    await provider.startRecording();
    await provider.stopRecording();

    expect(provider.recordings, hasLength(2));
    expect(provider.recordings.map((recording) => recording.name), [
      'Recording 1',
      'Recording 2',
    ]);

    await provider.renameRecording(provider.recordings.first, 'Best take');
    expect(provider.recordings.first.name, 'Best take');

    final saved = await provider.prepareSessionRecord(const []);
    expect(saved?.recordings, hasLength(2));
    expect(audio.startPlaybackCalls, 0);
    provider.completeSession();
  });
}

class _FakeAudioService extends AudioService {
  bool recording = false;
  bool playing = false;
  int _recordingNumber = 0;
  int startPlaybackCalls = 0;

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
    if (!recording) return null;
    recording = false;
    _recordingNumber++;
    return '/managed/recording_$_recordingNumber.m4a';
  }

  @override
  Future<void> startPlayback(String path) async {
    startPlaybackCalls++;
    playing = true;
  }

  @override
  Future<void> stopPlayback() async {
    playing = false;
  }

  @override
  Future<void> deleteRecording(String? path) async {
    recording = false;
    playing = false;
  }

  @override
  Future<void> dispose() async {}
}
