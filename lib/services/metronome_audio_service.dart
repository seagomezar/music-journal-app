import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart' as background_audio;
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

@immutable
class MetronomeClockSnapshot {
  const MetronomeClockSnapshot({
    required this.generation,
    required this.bpm,
    required this.engineTime,
    required this.beatIndex,
    required this.barPosition,
    required this.phase,
  });

  final int generation;
  final int bpm;
  final Duration engineTime;
  final int beatIndex;
  final int barPosition;
  final Duration phase;
}

abstract interface class MetronomeAudioController {
  ValueChanged<bool>? onExternalPlayingChanged;

  MetronomeClockSnapshot? get clockSnapshot;

  Future<void> start({required int bpm, required double volume});
  Future<void> setTempo(int bpm);
  Future<void> setVolume(double volume);
  Future<void> stop();

  Future<void> playReferenceTone(int hz);
  Future<void> stopReferenceTone();
  bool get isReferenceTonePlaying;
}

class NoopMetronomeAudioController implements MetronomeAudioController {
  @override
  ValueChanged<bool>? onExternalPlayingChanged;

  @override
  MetronomeClockSnapshot? get clockSnapshot => null;

  @override
  Future<void> setTempo(int bpm) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> start({required int bpm, required double volume}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> playReferenceTone(int hz) async {}

  @override
  Future<void> stopReferenceTone() async {}

  @override
  bool get isReferenceTonePlaying => false;
}

class MetronomeAudioService implements MetronomeAudioController {
  _MetronomeAudioHandler? _handler;
  Future<void>? _initialization;
  Future<void> _operationQueue = Future<void>.value();
  int _operationGeneration = 0;

  @override
  ValueChanged<bool>? onExternalPlayingChanged;

  @override
  MetronomeClockSnapshot? get clockSnapshot => _handler?.clockSnapshot;

  @override
  bool get isReferenceTonePlaying => _handler?.isReferenceTonePlaying ?? false;

  Future<void> initialize() async {
    if (_handler != null) return;
    final inFlight = _initialization;
    if (inFlight != null) return inFlight;
    final initialization = _initialize();
    _initialization = initialization;
    try {
      await initialization;
    } finally {
      if (identical(_initialization, initialization)) {
        _initialization = null;
      }
    }
  }

  Future<void> _initialize() async {
    final engine = SoLoud.instance;
    if (!engine.isInitialized) {
      await engine.init(
        sampleRate: MetronomeWave.sampleRate,
        bufferSize: 256,
        channels: Channels.stereo,
        lowLatency: true,
      );
    }
    final handler = _MetronomeAudioHandler(
      engine: engine,
      onExternalPlayingChanged: (playing) {
        onExternalPlayingChanged?.call(playing);
      },
    );
    await background_audio.AudioService.init(
      builder: () => handler,
      config: const background_audio.AudioServiceConfig(
        androidNotificationChannelId:
            'com.seagomezar.flutepracticecoach.metronome',
        androidNotificationChannelName: 'Practice metronome',
        androidNotificationChannelDescription:
            'Keeps the practice metronome playing while the screen is locked.',
        androidNotificationOngoing: true,
      ),
    );
    _handler = handler;
  }

  @override
  Future<void> start({required int bpm, required double volume}) async {
    await _enqueueOperation((generation) async {
      await initialize();
      if (generation != _operationGeneration) return;
      final handler = _handler;
      if (handler == null) return;
      await handler.startMetronome(bpm: bpm, volume: volume);
      if (generation != _operationGeneration) {
        await handler.stopMetronome();
      }
    });
  }

  @override
  Future<void> setTempo(int bpm) async {
    await _enqueueOperation((generation) async {
      final handler = _handler;
      if (handler == null || generation != _operationGeneration) return;
      await handler.setTempo(bpm);
    });
  }

  @override
  Future<void> setVolume(double volume) async {
    await _enqueueOperation((generation) async {
      final handler = _handler;
      if (handler == null || generation != _operationGeneration) return;
      await handler.setVolume(volume);
    });
  }

  @override
  Future<void> stop() async {
    _operationGeneration++;
    await _enqueueOperation((_) async {
      await _handler?.stopMetronome();
    });
  }

  @override
  Future<void> playReferenceTone(int hz) async {
    await _enqueueOperation((generation) async {
      await initialize();
      if (generation != _operationGeneration) return;
      await _handler?.playReferenceTone(hz);
    });
  }

  @override
  Future<void> stopReferenceTone() async {
    await _enqueueOperation((_) async {
      await _handler?.stopReferenceTone();
    });
  }

  Future<void> _enqueueOperation(
    Future<void> Function(int generation) operation,
  ) {
    final generation = _operationGeneration;
    final queued = _operationQueue.then((_) => operation(generation));
    _operationQueue = queued.then<void>((_) {}, onError: (_, _) {});
    return queued;
  }
}

class _MetronomeAudioHandler extends background_audio.BaseAudioHandler {
  _MetronomeAudioHandler({
    required SoLoud engine,
    required this.onExternalPlayingChanged,
  }) : _engine = engine,
       _bus = engine.createMixingBus(name: 'metronome') {
    _bus.playOnEngine(volume: _volume);
    mediaItem.add(_mediaItemFor(_bpm));
  }

  final SoLoud _engine;
  final Bus _bus;
  final ValueChanged<bool> onExternalPlayingChanged;

  AudioSource? _clickSource;
  Future<AudioSource>? _loadingClick;

  AudioSource? _referenceToneSource;
  SoundHandle? _referenceToneHandle;
  int? _referenceToneHz;

  int _bpm = 80;
  double _volume = 0.7;
  int _generation = 0;
  bool _playing = false;

  Timer? _tickerTimer;
  Duration _nextBeatTime = Duration.zero;
  Duration _lastBeatTime = Duration.zero;
  int _beatIndex = 0;
  Duration _interval = const Duration(milliseconds: 750);

  bool get isReferenceTonePlaying => _referenceToneHandle != null;

  MetronomeClockSnapshot? get clockSnapshot {
    if (!_playing || !_engine.isInitialized) return null;
    final now = _engine.getEngineTime();
    final phase = now >= _lastBeatTime ? now - _lastBeatTime : Duration.zero;
    return MetronomeClockSnapshot(
      generation: _generation,
      bpm: _bpm,
      engineTime: now,
      beatIndex: _beatIndex,
      barPosition: 0,
      phase: phase,
    );
  }

  Future<AudioSource> _ensureClickSource() async {
    if (_clickSource != null) return _clickSource!;
    final pending = _loadingClick;
    if (pending != null) return pending;

    final future = () async {
      final bytes = MetronomeWave.createClick();
      return await _engine.loadMem('metronome-single-click.wav', bytes);
    }();
    _loadingClick = future;
    try {
      final source = await future;
      _clickSource = source;
      return source;
    } finally {
      if (identical(_loadingClick, future)) {
        _loadingClick = null;
      }
    }
  }

  Future<void> startMetronome({
    required int bpm,
    required double volume,
  }) async {
    final generation = ++_generation;
    await _ensureClickSource();
    if (generation != _generation) return;

    _bpm = bpm.clamp(MetronomeWave.minBpm, MetronomeWave.maxBpm).toInt();
    _volume = volume.clamp(0.0, 1.0);
    _interval = Duration(microseconds: (60000000 / _bpm).round());
    _setBusVolume(_volume);
    _playing = true;

    final now = _engine.getEngineTime();
    _nextBeatTime = now + const Duration(milliseconds: 60);
    _lastBeatTime = _nextBeatTime;
    _beatIndex = 0;

    _scheduleAhead();
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(
      const Duration(milliseconds: 35),
      (_) => _scheduleAhead(),
    );

    _broadcast(playing: true);
  }

  Future<void> setTempo(int bpm) async {
    final nextBpm = bpm
        .clamp(MetronomeWave.minBpm, MetronomeWave.maxBpm)
        .toInt();
    _bpm = nextBpm;
    _interval = Duration(microseconds: (60000000 / _bpm).round());
    mediaItem.add(_mediaItemFor(_bpm));
    if (!_playing) return;

    final now = _engine.getEngineTime();
    // Re-anchor the next beat smoothly if scheduled beyond the new tempo horizon
    if (_nextBeatTime > now + const Duration(milliseconds: 40)) {
      final candidate = _lastBeatTime + _interval;
      _nextBeatTime = candidate > now + const Duration(milliseconds: 20)
          ? candidate
          : now + const Duration(milliseconds: 20);
    }
    _scheduleAhead();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    _setBusVolume(_volume);
  }

  void _scheduleAhead() {
    if (!_playing || !_engine.isInitialized) return;
    final source = _clickSource;
    if (source == null) return;

    final now = _engine.getEngineTime();
    final horizon = now + const Duration(milliseconds: 140);
    while (_nextBeatTime <= horizon) {
      _bus.playScheduled(source, _nextBeatTime);
      _lastBeatTime = _nextBeatTime;
      _beatIndex++;
      _nextBeatTime += _interval;
    }
  }

  @override
  Future<void> play() async {
    if (_playing) return;
    await startMetronome(bpm: _bpm, volume: _volume);
    onExternalPlayingChanged(true);
  }

  @override
  Future<void> pause() async {
    await _halt(notifyExternal: true, callSuperStop: false);
  }

  @override
  Future<void> stop() async {
    await _halt(notifyExternal: true, callSuperStop: true);
  }

  Future<void> stopMetronome() async {
    await _halt(notifyExternal: false, callSuperStop: true);
  }

  Future<void> _halt({
    required bool notifyExternal,
    required bool callSuperStop,
  }) async {
    _playing = false;
    _generation++;
    _tickerTimer?.cancel();
    _tickerTimer = null;
    playbackState.add(
      playbackState.value.copyWith(
        controls: const [],
        playing: false,
        processingState: background_audio.AudioProcessingState.idle,
      ),
    );
    if (notifyExternal) onExternalPlayingChanged(false);
    if (callSuperStop) await super.stop();
  }

  Future<void> playReferenceTone(int hz) async {
    final safeHz = hz.clamp(410, 480);
    if (_referenceToneHandle != null && _referenceToneHz == safeHz) return;
    await stopReferenceTone();

    final bytes = MetronomeWave.createTone(safeHz);
    final source = await _engine.loadMem('ref-tone-$safeHz.wav', bytes);
    final handle = _bus.play(source, volume: 0.6, looping: true);
    _referenceToneSource = source;
    _referenceToneHandle = handle;
    _referenceToneHz = safeHz;
  }

  Future<void> stopReferenceTone() async {
    final handle = _referenceToneHandle;
    final source = _referenceToneSource;
    _referenceToneHandle = null;
    _referenceToneSource = null;
    _referenceToneHz = null;

    if (handle != null) {
      try {
        await _engine.stop(handle);
      } catch (error) {
        debugPrint('Unable to stop reference tone: $error');
      }
    }
    if (source != null) {
      try {
        await _engine.disposeSource(source);
      } catch (error) {
        debugPrint('Unable to dispose reference tone source: $error');
      }
    }
  }

  void _setBusVolume(double volume) {
    final handle = _bus.soundHandle;
    if (handle != null) _engine.setVolume(handle, volume);
  }

  void _broadcast({required bool playing}) {
    mediaItem.add(_mediaItemFor(_bpm));
    playbackState.add(
      playbackState.value.copyWith(
        controls: playing
            ? const [
                background_audio.MediaControl.pause,
                background_audio.MediaControl.stop,
              ]
            : const [
                background_audio.MediaControl.play,
                background_audio.MediaControl.stop,
              ],
        androidCompactActionIndices: const [0, 1],
        playing: playing,
        processingState: background_audio.AudioProcessingState.ready,
      ),
    );
  }

  static background_audio.MediaItem _mediaItemFor(int bpm) {
    return background_audio.MediaItem(
      id: 'practice-metronome',
      album: 'Flute Practice Coach',
      title: 'Practice Metronome',
      artist: '$bpm BPM',
    );
  }
}

@visibleForTesting
class MetronomeWave {
  static const int sampleRate = 48000;
  static const int channelCount = 1;
  static const int bitsPerSample = 16;
  static const int minBpm = 30;
  static const int maxBpm = 252;
  static const int beatCount = 4;

  /// Synthesizes a single crisp percussive click (~25 ms).
  ///
  /// Woodblock/rimshot harmonic profile (1500 Hz + 3000 Hz) with exponential decay,
  /// matching the classic acoustic click of the Yamaha TDM-710 series.
  static Uint8List createClick() {
    final sampleCount = (sampleRate * 0.025).round(); // 25 ms
    final samples = Int16List(sampleCount);

    for (var i = 0; i < sampleCount; i++) {
      final time = i / sampleRate;
      final envelope = math.exp(-150 * time);
      final fundamental = math.sin(2 * math.pi * 1500.0 * time);
      final harmonic = 0.35 * math.sin(2 * math.pi * 3000.0 * time);
      final value = 0.95 * envelope * (fundamental + harmonic);
      samples[i] = (value.clamp(-1.0, 1.0) * 32767).round();
    }

    return _writeWave(samples);
  }

  /// Synthesizes a pure sine reference tone for ear tuning (Sound Out mode).
  ///
  /// The duration is locked to an exact integer number of cycles to guarantee
  /// a seamless zero-crossing loop without clicks.
  static Uint8List createTone(int hz, {double durationSeconds = 1.0}) {
    final safeHz = hz.clamp(410, 480);
    final cycles = (safeHz * durationSeconds).round();
    final sampleCount = (cycles * sampleRate / safeHz).round();
    final samples = Int16List(sampleCount);

    for (var i = 0; i < sampleCount; i++) {
      final time = i / sampleRate;
      final value = 0.70 * math.sin(2 * math.pi * safeHz * time);
      samples[i] = (value.clamp(-1.0, 1.0) * 32767).round();
    }

    return _writeWave(samples);
  }

  static int totalSamplesForBpm(int bpm) {
    final safeBpm = bpm.clamp(minBpm, maxBpm).toInt();
    return (sampleRate * 60 * beatCount / safeBpm).round();
  }

  static List<int> beatSampleOffsets(int bpm) {
    final safeBpm = bpm.clamp(minBpm, maxBpm).toInt();
    return List<int>.generate(
      beatCount,
      (beat) => (sampleRate * 60 * beat / safeBpm).round(),
      growable: false,
    );
  }

  /// Generates a multi-beat wave for legacy tests and 4-beat pattern compatibility.
  static Uint8List create(int bpm, {int startingBeat = 0}) {
    final safeBpm = bpm.clamp(minBpm, maxBpm).toInt();
    final totalSamples = totalSamplesForBpm(safeBpm);
    final samples = Int16List(totalSamples);
    final clickSamples = (sampleRate * 0.04).round();
    final offsets = beatSampleOffsets(safeBpm);

    for (var beat = 0; beat < beatCount; beat++) {
      final start = offsets[beat];
      final isAccent = (startingBeat + beat) % beatCount == 0;
      final frequency = isAccent ? 1760.0 : 1100.0;
      final gain = isAccent ? 0.88 : 0.68;
      for (var offset = 0; offset < clickSamples; offset++) {
        final sampleIndex = start + offset;
        if (sampleIndex >= samples.length) break;
        final time = offset / sampleRate;
        final envelope = math.exp(-70 * time);
        final fundamental = math.sin(2 * math.pi * frequency * time);
        final harmonic = 0.25 * math.sin(4 * math.pi * frequency * time);
        final value = gain * envelope * (fundamental + harmonic);
        samples[sampleIndex] = (value.clamp(-1.0, 1.0) * 32767).round();
      }
    }

    return _writeWave(samples);
  }

  static Uint8List _writeWave(Int16List samples) {
    final dataLength = samples.length * 2;
    final output = Uint8List(44 + dataLength);
    final bytes = ByteData.sublistView(output);

    _writeAscii(output, 0, 'RIFF');
    bytes.setUint32(4, 36 + dataLength, Endian.little);
    _writeAscii(output, 8, 'WAVE');
    _writeAscii(output, 12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, channelCount, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(
      28,
      sampleRate * channelCount * (bitsPerSample ~/ 8),
      Endian.little,
    );
    bytes.setUint16(32, channelCount * (bitsPerSample ~/ 8), Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);
    _writeAscii(output, 36, 'data');
    bytes.setUint32(40, dataLength, Endian.little);
    for (var index = 0; index < samples.length; index++) {
      bytes.setInt16(44 + (index * 2), samples[index], Endian.little);
    }
    return output;
  }

  static void _writeAscii(Uint8List target, int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      target[offset + index] = value.codeUnitAt(index);
    }
  }
}
