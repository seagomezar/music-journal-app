import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:flute/services/audio_service.dart';
import 'package:flute/services/capture_lifecycle_service.dart';
import 'package:flute/services/file_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'recording balances capture lifecycle around recorder start and stop',
    () async {
      final previousPlatform = RecordPlatform.instance;
      final recordPlatform = _FakeRecordPlatform();
      final lifecycle = _FakeCaptureLifecycleController();
      RecordPlatform.instance = recordPlatform;
      addTearDown(() async {
        RecordPlatform.instance = previousPlatform;
        await recordPlatform.dispose('test');
      });

      final audio = AudioService(
        storageService: _FakeFileStorageService(),
        captureLifecycle: lifecycle,
      );
      await audio.startRecording();

      expect(audio.isRecording, true);
      expect(lifecycle.started, [AudioCaptureKind.recording]);

      final path = await audio.stopRecording();

      expect(path, '/fake/practice.m4a');
      expect(audio.isRecording, false);
      expect(lifecycle.ended, [AudioCaptureKind.recording]);
      await audio.dispose();
    },
  );
}

class _FakeCaptureLifecycleController
    implements AudioCaptureLifecycleController {
  final List<AudioCaptureKind> started = [];
  final List<AudioCaptureKind> ended = [];

  @override
  Future<void> begin(AudioCaptureKind kind) async {
    started.add(kind);
  }

  @override
  Future<void> end(AudioCaptureKind kind) async {
    ended.add(kind);
  }
}

class _FakeFileStorageService extends FileStorageService {
  @override
  Future<String> createRecordingPath() async => '/fake/practice.m4a';
}

class _FakeRecordPlatform extends RecordPlatform {
  final _states = StreamController<RecordState>.broadcast(sync: true);

  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<void> start(
    String recorderId,
    RecordConfig config, {
    required String path,
  }) async {
    _states.add(RecordState.record);
  }

  @override
  Future<Stream<Uint8List>> startStream(
    String recorderId,
    RecordConfig config,
  ) async => const Stream.empty();

  @override
  Future<String?> stop(String recorderId) async {
    _states.add(RecordState.stop);
    return '/fake/practice.m4a';
  }

  @override
  Future<void> pause(String recorderId) async {}

  @override
  Future<void> resume(String recorderId) async {}

  @override
  Future<bool> isRecording(String recorderId) async => true;

  @override
  Future<bool> isPaused(String recorderId) async => false;

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async =>
      true;

  @override
  Future<void> dispose(String recorderId) async {
    await _states.close();
  }

  @override
  Future<Amplitude> getAmplitude(String recorderId) async =>
      Amplitude(current: 0, max: 0);

  @override
  Future<bool> isEncoderSupported(
    String recorderId,
    AudioEncoder encoder,
  ) async => true;

  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async =>
      const [];

  @override
  Future<void> cancel(String recorderId) async {}

  @override
  Stream<RecordState> onStateChanged(String recorderId) => _states.stream;

  @override
  void setOnConfigChanged(
    String recorderId,
    void Function(RecordConfig config)? handler,
  ) {}
}
