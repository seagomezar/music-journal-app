import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../models/pitch_tracking.dart';

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
  PitchTrackingService({PitchAudioInput? audioInput})
    : _audioInput = audioInput ?? RecordPitchAudioInput();

  static const sampleRate = 48000;
  static const frameSize = 2048;
  static const _minimumClarity = 0.80;
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
  final List<int> _pendingSamples = [];
  int? _pendingByte;
  final List<int> _recentMidiNotes = [];
  StreamSubscription<Uint8List>? _subscription;
  Future<void> _analysisQueue = Future.value();
  ValueChanged<PitchReading?>? onReading;

  PitchCaptureMode? _mode;
  int _referenceHz = 440;
  int _toleranceCents = 10;
  bool _isListening = false;
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
  }) async {
    if (_isDisposed) throw StateError('Pitch tracker has been disposed.');
    if (_isListening) await stop();
    if (!await _audioInput.hasPermission()) {
      throw StateError('Microphone permission was not granted.');
    }

    _mode = mode;
    _referenceHz = referenceHz.clamp(420, 460);
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
      final stream = await _audioInput.start();
      _isListening = true;
      _subscription = stream.listen(
        (bytes) => _acceptBytes(bytes, excludeFrame: excludeFrame),
        onError: (_) => unawaited(stop()),
        onDone: () {
          _isListening = false;
          onReading?.call(null);
        },
      );
    } catch (_) {
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
      _analysisQueue = _analysisQueue.then(
        (_) => _analyzeFrame(frame, excluded: excluded),
      );
    }
  }

  Future<void> _analyzeFrame(
    Float64List frame, {
    required bool excluded,
  }) async {
    if (!_isListening) return;
    final result = await compute(detectPitchFrame, {
      'samples': frame,
      'sampleRate': sampleRate,
    });
    if (!_isListening) return;
    if (result == null || result.clarity < _minimumClarity) {
      _recentMidiNotes.clear();
      onReading?.call(null);
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

  Future<ExercisePitchSummary?> stop() async {
    final summary = currentSummary();
    if (!_isListening) {
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
    await _analysisQueue;
    _mode = null;
    _trackingStartedAt = null;
    _pendingSamples.clear();
    _pendingByte = null;
    _recentMidiNotes.clear();
    onReading?.call(null);
    return summary;
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
  if (rms < 0.0032) return null; // Approximately -50 dBFS.

  final minimumLag = (sampleRate / 2500).floor().clamp(2, samples.length - 2);
  final maximumLag = (sampleRate / 220).ceil().clamp(
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
  final cutoff = nsdf[strongest] * 0.93;
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
