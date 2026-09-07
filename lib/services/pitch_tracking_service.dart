import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../models/flute_dynamic.dart';
import '../models/pitch_tracking.dart';
import 'capture_lifecycle_service.dart';

enum PitchCaptureMode { tuning, tracking }

abstract interface class PitchAudioInput {
  Future<bool> hasPermission();
  Future<Stream<Uint8List>> start();
  Future<void> stop();
  Future<void> dispose();
}

class RecordPitchAudioInput implements PitchAudioInput {
  RecordPitchAudioInput({AudioRecorder? recorder})
    : _recorderInstance = recorder;

  AudioRecorder? _recorderInstance;
  AudioRecorder get _recorder => _recorderInstance ??= AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<Stream<Uint8List>> start() => _recorder.startStream(
    const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: PitchTrackingService.sampleRate,
      numChannels: 1,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
      streamBufferSize: PitchTrackingService.frameSize * 2,
    ),
  );

  @override
  Future<void> stop() async {
    await _recorder.stop();
  }

  @override
  Future<void> dispose() async {
    await _recorderInstance?.dispose();
  }
}

class PitchTrackingService {
  PitchTrackingService({
    PitchAudioInput? audioInput,
    AudioCaptureLifecycleController? captureLifecycle,
  }) : _audioInput = audioInput ?? RecordPitchAudioInput(),
       _captureLifecycle =
           captureLifecycle ?? PlatformAudioCaptureLifecycleController();

  static const sampleRate = 48000;
  static const frameSize = 2048;
  static const _minimumClarity = 0.65;
  static const _noteNames = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  final PitchAudioInput _audioInput;
  final AudioCaptureLifecycleController _captureLifecycle;
  final List<int> _pendingSamples = [];
  int? _pendingByte;
  final List<int> _recentMidiNotes = [];
  StreamSubscription<Uint8List>? _subscription;
  Future<void> _analysisQueue = Future.value();
  static const maxPendingFrames = 3;
  int _pendingAnalysisFrames = 0;
  int droppedFrames = 0;
  int get pendingAnalysisFrames => _pendingAnalysisFrames;
  Future<void> _captureOperationQueue = Future<void>.value();
  ValueChanged<PitchReading?>? onReading;
  ValueChanged<FluteDynamicReading?>? onDynamicReading;

  int _dynamicCalibrationOffsetDb = 0;
  double _smoothedDecibels = 0.0;
  double _peakDecibels = 0.0;
  DateTime _lastPeakTime = DateTime.now();

  int get dynamicCalibrationOffsetDb => _dynamicCalibrationOffsetDb;
  set dynamicCalibrationOffsetDb(int value) {
    _dynamicCalibrationOffsetDb = value.clamp(-20, 20);
  }

  PitchCaptureMode? _mode;
  int _referenceHz = 440;
  int _toleranceCents = 10;
  bool _isListening = false;
  bool _pitchCaptureActive = false;
  bool _isDisposed = false;
  DateTime? _trackingStartedAt;
  int _inTuneSamples = 0;
  int _analyzedSamples = 0;

  bool get isListening => _isListening;
  PitchCaptureMode? get mode => _mode;

  Future<void> start({
    required PitchCaptureMode mode,
    required int referenceHz,
    required int toleranceCents,
    bool Function()? excludeFrame,
  }) => _enqueueCaptureOperation(
    () => _startInternal(
      mode: mode,
      referenceHz: referenceHz,
      toleranceCents: toleranceCents,
      excludeFrame: excludeFrame,
    ),
  );

  Future<void> _startInternal({
    required PitchCaptureMode mode,
    required int referenceHz,
    required int toleranceCents,
    bool Function()? excludeFrame,
  }) async {
    if (_isDisposed) throw StateError('Pitch tracker has been disposed.');
    if (_isListening) await _stopInternal();
    if (!await _audioInput.hasPermission()) {
      throw StateError('Microphone permission was not granted.');
    }

    _mode = mode;
    _referenceHz = referenceHz.clamp(410, 480);
    _toleranceCents = toleranceCents.clamp(5, 20);
    _pendingSamples.clear();
    _pendingByte = null;
    _recentMidiNotes.clear();
    _inTuneSamples = 0;
    _analyzedSamples = 0;
    _trackingStartedAt = mode == PitchCaptureMode.tracking
        ? DateTime.now()
        : null;
    try {
      await _captureLifecycle.begin(AudioCaptureKind.pitchTracking);
      _pitchCaptureActive = true;
      final stream = await _audioInput.start();
      _isListening = true;
      _subscription = stream.listen(
        (bytes) => _acceptBytes(bytes, excludeFrame: excludeFrame),
        onError: (_) => unawaited(stop()),
        onDone: () {
          unawaited(stop());
        },
      );
    } catch (_) {
      await _endPitchCapture();
      _mode = null;
      _trackingStartedAt = null;
      rethrow;
    }
  }

  void _acceptBytes(Uint8List bytes, {bool Function()? excludeFrame}) {
    var offset = 0;
    if (_pendingByte != null && bytes.isNotEmpty) {
      final value = _pendingByte! | (bytes[0] << 8);
      _pendingSamples.add(value >= 0x8000 ? value - 0x10000 : value);
      _pendingByte = null;
      offset = 1;
    }
    for (; offset + 1 < bytes.length; offset += 2) {
      final value = bytes[offset] | (bytes[offset + 1] << 8);
      _pendingSamples.add(value >= 0x8000 ? value - 0x10000 : value);
    }
    if (offset < bytes.length) _pendingByte = bytes[offset];
    while (_pendingSamples.length >= frameSize) {
      final frame = Float64List(frameSize);
      for (var index = 0; index < frameSize; index++) {
        frame[index] = _pendingSamples[index] / 32768.0;
      }
      _pendingSamples.removeRange(0, frameSize);
      final excluded = excludeFrame?.call() ?? false;

      final dynamicReading = _processDynamicFrame(frame, isExcluded: excluded);
      if (_isListening) {
        onDynamicReading?.call(dynamicReading);
      }

      if (_pendingAnalysisFrames >= maxPendingFrames) {
        droppedFrames++;
        continue;
      }
      _pendingAnalysisFrames++;
      _analysisQueue = _analysisQueue.then((_) async {
        try {
          await _analyzeFrame(
            frame,
            dynamicReading: dynamicReading,
            excluded: excluded,
          );
        } catch (error) {
          debugPrint('Pitch frame analysis failed: $error');
        } finally {
          _pendingAnalysisFrames--;
        }
      });
    }
  }

  FluteDynamicReading _processDynamicFrame(
    Float64List frame, {
    bool isExcluded = false,
  }) {
    var energy = 0.0;
    for (var i = 0; i < frame.length; i++) {
      energy += frame[i] * frame[i];
    }
    final rms = math.sqrt(energy / frame.length);
    // A relative display scale only. Device gain is not calibrated to SPL.
    final double rawDb;
    if (rms <= 0.001) {
      rawDb = 30.0;
    } else {
      final dbfs = 20.0 * (math.log(rms) / math.ln10);
      final normalized = ((dbfs + 60.0) / 54.0).clamp(0.0, 1.0);
      rawDb = (30.0 + (normalized * 70.0) + _dynamicCalibrationOffsetDb).clamp(
        30.0,
        105.0,
      );
    }

    if (!isExcluded) {
      final alpha = rawDb > _smoothedDecibels ? 0.35 : 0.12;
      _smoothedDecibels = (_smoothedDecibels == 0.0)
          ? rawDb
          : (alpha * rawDb + (1.0 - alpha) * _smoothedDecibels);

      final now = DateTime.now();
      if (rawDb >= _peakDecibels) {
        _peakDecibels = rawDb;
        _lastPeakTime = now;
      } else if (now.difference(_lastPeakTime).inMilliseconds > 1500) {
        _peakDecibels = math.max(rawDb, _peakDecibels - 1.2);
      }
    }

    final fluteDynamic = FluteDynamic.fromDecibels(_smoothedDecibels);
    return FluteDynamicReading(
      decibels: rawDb,
      smoothedDecibels: _smoothedDecibels,
      peakDecibels: _peakDecibels,
      dynamic: fluteDynamic,
    );
  }

  Future<void> _analyzeFrame(
    Float64List frame, {
    required FluteDynamicReading dynamicReading,
    required bool excluded,
  }) async {
    if (!_isListening) return;
    final result = await compute(detectPitchFrame, {
      'samples': frame,
      'sampleRate': sampleRate,
    });
    if (!_isListening) return;
    if (result == null || result.clarity < _minimumClarity) {
      if (!excluded) {
        _recentMidiNotes.clear();
        onReading?.call(null);
      }
      return;
    }

    final midiFloat =
        69 + 12 * (math.log(result.frequencyHz / _referenceHz) / math.ln2);
    final midiNote = midiFloat.round();
    final targetHz = _referenceHz * math.pow(2, (midiNote - 69) / 12);
    final cents = 1200 * (math.log(result.frequencyHz / targetHz) / math.ln2);
    _recentMidiNotes.add(midiNote);
    if (_recentMidiNotes.length > 3) _recentMidiNotes.removeAt(0);
    final stable =
        _recentMidiNotes.length >= 2 &&
        _recentMidiNotes.every((note) => note == midiNote);
    final onPitch = cents.abs() <= _toleranceCents;

    if (_mode == PitchCaptureMode.tracking && stable && !excluded) {
      _analyzedSamples += frameSize;
      if (onPitch) _inTuneSamples += frameSize;
    }

    onReading?.call(
      PitchReading(
        frequencyHz: result.frequencyHz,
        noteName: _noteNames[(midiNote % 12 + 12) % 12],
        octave: midiNote ~/ 12 - 1,
        cents: cents.clamp(-50.0, 50.0),
        clarity: result.clarity,
        isStable: stable,
        isOnPitch: stable && onPitch,
        decibels: dynamicReading.smoothedDecibels,
        dynamic: dynamicReading.dynamic,
      ),
    );
  }

  ExercisePitchSummary? currentSummary() {
    if (_mode != PitchCaptureMode.tracking || _trackingStartedAt == null) {
      return null;
    }
    return ExercisePitchSummary(
      inTuneMilliseconds: (_inTuneSamples * 1000 / sampleRate).round(),
      analyzedMilliseconds: (_analyzedSamples * 1000 / sampleRate).round(),
      trackingMilliseconds: DateTime.now()
          .difference(_trackingStartedAt!)
          .inMilliseconds
          .clamp(0, 86400000),
      referenceHz: _referenceHz,
      toleranceCents: _toleranceCents,
    );
  }

  Future<ExercisePitchSummary?> stop() =>
      _enqueueCaptureOperation(_stopInternal);

  Future<ExercisePitchSummary?> _stopInternal() async {
    final summary = currentSummary();
    if (!_isListening) {
      await _endPitchCapture();
      _mode = null;
      _trackingStartedAt = null;
      onReading?.call(null);
      return summary;
    }
    _isListening = false;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _audioInput.stop();
    } catch (_) {
      // The input may already have stopped after an interruption.
    }
    await _endPitchCapture();
    await _analysisQueue;
    _mode = null;
    _trackingStartedAt = null;
    _pendingSamples.clear();
    _pendingByte = null;
    _recentMidiNotes.clear();
    _smoothedDecibels = 0.0;
    _peakDecibels = 0.0;
    onReading?.call(null);
    onDynamicReading?.call(null);
    return summary;
  }

  Future<void> _endPitchCapture() async {
    if (!_pitchCaptureActive) return;
    _pitchCaptureActive = false;
    await _captureLifecycle.end(AudioCaptureKind.pitchTracking);
  }

  Future<T> _enqueueCaptureOperation<T>(Future<T> Function() operation) {
    final result = _captureOperationQueue.then((_) => operation());
    _captureOperationQueue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    await stop();
    _isDisposed = true;
    await _audioInput.dispose();
  }
}

class PitchDetectionResult {
  const PitchDetectionResult(this.frequencyHz, this.clarity);

  final double frequencyHz;
  final double clarity;
}

PitchDetectionResult? detectPitchFrame(Map<String, Object> input) {
  final samples = input['samples']! as Float64List;
  final sampleRate = input['sampleRate']! as int;
  var energy = 0.0;
  var mean = 0.0;
  for (final sample in samples) {
    mean += sample;
  }
  mean /= samples.length;
  for (var index = 0; index < samples.length; index++) {
    samples[index] -= mean;
    energy += samples[index] * samples[index];
  }
  final rms = math.sqrt(energy / samples.length);
  if (rms < 0.001) return null; // Approximately -60 dBFS.

  // Pitch range matching Yamaha TDM-710GL: C1 (30.5 Hz) to C8 (4200 Hz).
  final minimumLag = (sampleRate / 4200).floor().clamp(2, samples.length - 2);
  final maximumLag = (sampleRate / 30.5).ceil().clamp(
    minimumLag + 1,
    samples.length - 2,
  );
  final nsdf = Float64List(maximumLag + 1);
  for (var lag = minimumLag; lag <= maximumLag; lag++) {
    var correlation = 0.0;
    var divisor = 0.0;
    final limit = samples.length - lag;
    for (var index = 0; index < limit; index++) {
      final first = samples[index];
      final second = samples[index + lag];
      correlation += first * second;
      divisor += first * first + second * second;
    }
    if (divisor > 0) nsdf[lag] = 2 * correlation / divisor;
  }

  final maxima = <int>[];
  for (var lag = minimumLag + 1; lag < maximumLag; lag++) {
    if (nsdf[lag] > nsdf[lag - 1] && nsdf[lag] >= nsdf[lag + 1]) {
      maxima.add(lag);
    }
  }
  if (maxima.isEmpty) return null;
  var strongest = maxima.first;
  for (final lag in maxima.skip(1)) {
    if (nsdf[lag] > nsdf[strongest]) strongest = lag;
  }
  final cutoff = nsdf[strongest] * 0.85;
  final selected = maxima.firstWhere(
    (lag) => nsdf[lag] >= cutoff,
    orElse: () => strongest,
  );
  final clarity = nsdf[selected];
  if (clarity < PitchTrackingService._minimumClarity) return null;

  final left = nsdf[selected - 1];
  final center = nsdf[selected];
  final right = nsdf[selected + 1];
  final denominator = left - 2 * center + right;
  final offset = denominator.abs() < 1e-12
      ? 0.0
      : 0.5 * (left - right) / denominator;
  final refinedLag = selected + offset.clamp(-1.0, 1.0);
  return PitchDetectionResult(sampleRate / refinedLag, clarity);
}
