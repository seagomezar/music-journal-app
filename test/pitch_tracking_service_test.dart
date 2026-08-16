import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flute/models/pitch_tracking.dart';
import 'package:flute/services/capture_lifecycle_service.dart';
import 'package:flute/services/pitch_tracking_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MPM pitch detector', () {
    for (final frequency in [261.6256, 440.0, 1046.502]) {
      test('detects ${frequency.toStringAsFixed(1)} Hz within two cents', () {
        final result = detectPitchFrame({
          'samples': _tone(frequency),
          'sampleRate': PitchTrackingService.sampleRate,
        });

        expect(result, isNotNull);
        final cents =
            1200 * math.log(result!.frequencyHz / frequency) / math.ln2;
        expect(cents.abs(), lessThan(2));
        expect(result.clarity, greaterThan(0.9));
      });
    }

    test('rejects silence', () {
      final result = detectPitchFrame({
        'samples': Float64List(PitchTrackingService.frameSize),
        'sampleRate': PitchTrackingService.sampleRate,
      });
      expect(result, isNull);
    });

    test('finds the fundamental with strong flute-like harmonics', () {
      const frequency = 523.251;
      final samples = Float64List.fromList([
        for (var index = 0; index < PitchTrackingService.frameSize; index++)
          0.35 *
                  math.sin(
                    2 *
                        math.pi *
                        frequency *
                        index /
                        PitchTrackingService.sampleRate,
                  ) +
              0.45 *
                  math.sin(
                    4 *
                        math.pi *
                        frequency *
                        index /
                        PitchTrackingService.sampleRate,
                  ),
      ]);
      final result = detectPitchFrame({
        'samples': samples,
        'sampleRate': PitchTrackingService.sampleRate,
      });
      expect(result, isNotNull);
      final cents = 1200 * math.log(result!.frequencyHz / frequency) / math.ln2;
      expect(cents.abs(), lessThan(2));
    });
  });

  test(
    'streaming tracker handles split PCM bytes and scores stable frames',
    () async {
      final input = _FakePitchAudioInput();
      final lifecycle = _FakeCaptureLifecycleController();
      final tracker = PitchTrackingService(
        audioInput: input,
        captureLifecycle: lifecycle,
      );
      final stableReading = Completer<PitchReading>();
      tracker.onReading = (reading) {
        if (reading?.isStable == true && !stableReading.isCompleted) {
          stableReading.complete(reading);
        }
      };
      await tracker.start(
        mode: PitchCaptureMode.tracking,
        referenceHz: 440,
        toleranceCents: 10,
      );

      final bytes = _pcm16([..._tone(440), ..._tone(440)]);
      input.add(bytes.sublist(0, 101));
      input.add(bytes.sublist(101, 4097));
      input.add(bytes.sublist(4097));

      final reading = await stableReading.future.timeout(
        const Duration(seconds: 3),
      );
      expect(reading.displayNote, 'A4');
      expect(reading.cents.abs(), lessThan(2));
      expect(reading.isOnPitch, true);

      final summary = await tracker.stop();
      expect(summary, isNotNull);
      expect(summary!.analyzedMilliseconds, 43);
      expect(summary.inTuneMilliseconds, summary.analyzedMilliseconds);
      expect(lifecycle.started, [AudioCaptureKind.pitchTracking]);
      expect(lifecycle.ended, [AudioCaptureKind.pitchTracking]);
      await tracker.dispose();
    },
  );

  test('excluded metronome-click frames never enter the score', () async {
    final input = _FakePitchAudioInput();
    final tracker = PitchTrackingService(audioInput: input);
    await tracker.start(
      mode: PitchCaptureMode.tracking,
      referenceHz: 440,
      toleranceCents: 10,
      excludeFrame: () => true,
    );
    final stable = _stableReading(tracker);
    input.add(_pcm16([..._tone(440), ..._tone(440), ..._tone(440)]));
    await stable;
    final summary = await tracker.stop();
    expect(summary!.analyzedMilliseconds, 0);
    await tracker.dispose();
  });

  test('tolerance boundary marks six cents sharp correctly', () async {
    final frequency = (440 * math.pow(2, 6 / 1200)).toDouble();
    for (final tolerance in [5, 10]) {
      final input = _FakePitchAudioInput();
      final tracker = PitchTrackingService(audioInput: input);
      final readingFuture = _stableReading(tracker);
      await tracker.start(
        mode: PitchCaptureMode.tracking,
        referenceHz: 440,
        toleranceCents: tolerance,
      );
      input.add(_pcm16([..._tone(frequency), ..._tone(frequency)]));
      final reading = await readingFuture;
      expect(reading.isOnPitch, tolerance == 10);
      final summary = await tracker.stop();
      expect(summary!.analyzedMilliseconds, 43);
      expect(summary.inTuneMilliseconds, tolerance == 10 ? 43 : 0);
      await tracker.dispose();
    }
  });

  test('permission and capture failures leave the tracker idle', () async {
    final denied = _FakePitchAudioInput(permission: false);
    final deniedTracker = PitchTrackingService(audioInput: denied);
    await expectLater(
      deniedTracker.start(
        mode: PitchCaptureMode.tuning,
        referenceHz: 440,
        toleranceCents: 10,
      ),
      throwsStateError,
    );
    expect(deniedTracker.isListening, false);
    expect(deniedTracker.mode, isNull);
    await deniedTracker.dispose();

    final broken = _FakePitchAudioInput(startError: StateError('unavailable'));
    final brokenTracker = PitchTrackingService(audioInput: broken);
    await expectLater(
      brokenTracker.start(
        mode: PitchCaptureMode.tracking,
        referenceHz: 440,
        toleranceCents: 10,
      ),
      throwsStateError,
    );
    expect(brokenTracker.isListening, false);
    expect(brokenTracker.mode, isNull);
    expect(brokenTracker.currentSummary(), isNull);
    await brokenTracker.dispose();
  });

  test('pitch summary requires two seconds of voiced analysis', () {
    const short = ExercisePitchSummary(
      inTuneMilliseconds: 1900,
      analyzedMilliseconds: 1900,
      trackingMilliseconds: 2500,
      referenceHz: 440,
      toleranceCents: 10,
    );
    const enough = ExercisePitchSummary(
      inTuneMilliseconds: 1500,
      analyzedMilliseconds: 2000,
      trackingMilliseconds: 3000,
      referenceHz: 440,
      toleranceCents: 10,
    );
    expect(short.hasEnoughData, false);
    expect(enough.hasEnoughData, true);
    expect(enough.onPitchPercentage, 75);
  });
}

Float64List _tone(double frequency) {
  return Float64List.fromList([
    for (var index = 0; index < PitchTrackingService.frameSize; index++)
      0.5 *
          math.sin(
            2 * math.pi * frequency * index / PitchTrackingService.sampleRate,
          ),
  ]);
}

Uint8List _pcm16(List<double> samples) {
  final bytes = ByteData(samples.length * 2);
  for (var index = 0; index < samples.length; index++) {
    bytes.setInt16(
      index * 2,
      (samples[index].clamp(-1.0, 1.0) * 32767).round(),
      Endian.little,
    );
  }
  return bytes.buffer.asUint8List();
}

class _FakePitchAudioInput implements PitchAudioInput {
  _FakePitchAudioInput({this.permission = true, this.startError});

  final _controller = StreamController<Uint8List>();
  final bool permission;
  final Object? startError;

  void add(Uint8List bytes) => _controller.add(bytes);

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<Stream<Uint8List>> start() async {
    if (startError case final error?) throw error;
    return _controller.stream;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    unawaited(_controller.close());
  }
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

Future<PitchReading> _stableReading(PitchTrackingService tracker) {
  final completer = Completer<PitchReading>();
  tracker.onReading = (reading) {
    if (reading?.isStable == true && !completer.isCompleted) {
      completer.complete(reading);
    }
  };
  return completer.future.timeout(const Duration(seconds: 3));
}
