import 'dart:async';
import 'dart:collection';
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
}

class MetronomeAudioService implements MetronomeAudioController {
  _MetronomeAudioHandler? _handler;
  Future<void>? _initialization;

  @override
  ValueChanged<bool>? onExternalPlayingChanged;

  @override
  MetronomeClockSnapshot? get clockSnapshot => _handler?.clockSnapshot;

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
    await initialize();
    await _handler?.startMetronome(bpm: bpm, volume: volume);
  }

  @override
  Future<void> setTempo(int bpm) async {
    await _handler?.setTempo(bpm);
  }

  @override
  Future<void> setVolume(double volume) async {
    await _handler?.setVolume(volume);
  }

  @override
  Future<void> stop() async {
    await _handler?.stopMetronome();
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

  static const _scheduleLead = Duration(milliseconds: 80);
  static const _retirementGrace = Duration(milliseconds: 100);
  static const _maxCachedSources = 8;

  final SoLoud _engine;
  final Bus _bus;
  final ValueChanged<bool> onExternalPlayingChanged;
  final LinkedHashMap<String, AudioSource> _sourceCache = LinkedHashMap();
  final Map<String, Future<AudioSource>> _loadingSources = {};
  final List<_RetiredSource> _retiredSources = [];

  int _bpm = 80;
  double _volume = 0.7;
  int _generation = 0;
  bool _playing = false;
  SoundHandle? _activeHandle;
  AudioSource? _activeSource;
  _ClockSegment? _activeSegment;
  SoundHandle? _pendingHandle;
  AudioSource? _pendingSource;
  _ClockSegment? _pendingSegment;

  MetronomeClockSnapshot? get clockSnapshot {
    if (!_playing || !_engine.isInitialized) return null;
    final now = _engine.getEngineTime();
    _promotePendingIfDue(now);
    return _activeSegment?.snapshot(now, _generation);
  }

  Future<void> startMetronome({
    required int bpm,
    required double volume,
  }) async {
    final generation = ++_generation;
    _bpm = bpm.clamp(40, 240).toInt();
    _volume = volume.clamp(0.0, 1.0);
    _playing = true;
    _setBusVolume(_volume);

    final source = await _sourceFor(_bpm, 0);
    if (generation != _generation || !_playing) return;
    await _stopHandles();
    if (generation != _generation || !_playing) return;

    final startAt = _engine.getEngineTime() + _scheduleLead;
    final segment = _ClockSegment(
      bpm: _bpm,
      startAt: startAt,
      startBeatIndex: 0,
    );
    final handle = _scheduleLoop(source, segment);
    _activeSource = source;
    _activeHandle = handle;
    _activeSegment = segment;
    _broadcast(playing: true);
    _cleanupSources();
  }

  Future<void> setTempo(int bpm) async {
    final nextBpm = bpm.clamp(40, 240).toInt();
    _bpm = nextBpm;
    mediaItem.add(_mediaItemFor(_bpm));
    if (!_playing) return;

    final generation = ++_generation;
    final nowBeforeLoad = _engine.getEngineTime();
    _promotePendingIfDue(nowBeforeLoad);
    final boundary = _transitionBoundary(nowBeforeLoad);
    final phase = boundary.beatIndex % MetronomeWave.beatCount;
    final source = await _sourceFor(nextBpm, phase);
    if (generation != _generation || !_playing) return;

    final now = _engine.getEngineTime();
    _promotePendingIfDue(now);
    final effectiveBoundary = boundary.atTime - now >= _scheduleLead
        ? boundary
        : _transitionBoundary(now);
    final effectivePhase =
        effectiveBoundary.beatIndex % MetronomeWave.beatCount;
    final effectiveSource = effectivePhase == phase
        ? source
        : await _sourceFor(nextBpm, effectivePhase);
    if (generation != _generation || !_playing) return;

    _cancelPendingLoop();
    final segment = _ClockSegment(
      bpm: nextBpm,
      startAt: effectiveBoundary.atTime,
      startBeatIndex: effectiveBoundary.beatIndex,
    );
    final handle = _scheduleLoop(effectiveSource, segment);
    final activeHandle = _activeHandle;
    if (activeHandle != null) {
      _engine.stopScheduled(activeHandle, effectiveBoundary.atTime);
    }
    _pendingHandle = handle;
    _pendingSource = effectiveSource;
    _pendingSegment = segment;
    _broadcast(playing: true);
    _cleanupSources();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    _setBusVolume(_volume);
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
    await _stopHandles();
    _activeSegment = null;
    _pendingSegment = null;
    playbackState.add(
      playbackState.value.copyWith(
        controls: const [],
        playing: false,
        processingState: background_audio.AudioProcessingState.idle,
      ),
    );
    if (notifyExternal) onExternalPlayingChanged(false);
    if (callSuperStop) await super.stop();
    _cleanupSources();
  }

  Future<AudioSource> _sourceFor(int bpm, int startingBeat) async {
    final phase = startingBeat % MetronomeWave.beatCount;
    final key = '$bpm:$phase';
    final cached = _sourceCache.remove(key);
    if (cached != null) {
      _sourceCache[key] = cached;
      return cached;
    }
    final loading = _loadingSources[key];
    if (loading != null) return loading;
    final future = _loadSource(key, bpm, phase);
    _loadingSources[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_loadingSources[key], future)) {
        _loadingSources.remove(key);
      }
    }
  }

  Future<AudioSource> _loadSource(String key, int bpm, int phase) async {
    final bytes = MetronomeWave.create(bpm, startingBeat: phase);
    final source = await _engine.loadMem('metronome-$key.wav', bytes);
    final cached = _sourceCache.remove(key);
    if (cached != null) {
      _sourceCache[key] = cached;
      unawaited(_disposeSourceSafely(source));
      return cached;
    }
    _sourceCache[key] = source;
    return source;
  }

  SoundHandle _scheduleLoop(AudioSource source, _ClockSegment segment) {
    final handle = _bus.playScheduled(source, segment.startAt);
    _engine.setLooping(handle, true);
    _engine.setLoopPoint(handle, Duration.zero);
    _engine.setLoopEndPoint(handle, null);
    return handle;
  }

  _BeatBoundary _transitionBoundary(Duration now) {
    final pending = _pendingSegment;
    if (pending != null && now < pending.startAt) {
      return _BeatBoundary(pending.startAt, pending.startBeatIndex);
    }
    final active = _activeSegment;
    if (active == null) {
      return _BeatBoundary(now + _scheduleLead, 0);
    }
    var boundary = active.nextBeatAfter(now);
    while (boundary.atTime - now < _scheduleLead) {
      boundary = active.nextBeatAfter(boundary.atTime);
    }
    return boundary;
  }

  void _promotePendingIfDue(Duration now) {
    final pending = _pendingSegment;
    if (pending == null || now < pending.startAt) return;
    final oldSource = _activeSource;
    if (oldSource != null && oldSource != _pendingSource) {
      _retiredSources.add(
        _RetiredSource(oldSource, pending.startAt + _retirementGrace),
      );
    }
    _activeHandle = _pendingHandle;
    _activeSource = _pendingSource;
    _activeSegment = pending;
    _pendingHandle = null;
    _pendingSource = null;
    _pendingSegment = null;
  }

  void _cancelPendingLoop() {
    final handle = _pendingHandle;
    _pendingHandle = null;
    _pendingSource = null;
    _pendingSegment = null;
    if (handle != null) unawaited(_stopHandle(handle));
  }

  Future<void> _stopHandles() async {
    final handles = <SoundHandle>{?_activeHandle, ?_pendingHandle};
    _activeHandle = null;
    _pendingHandle = null;
    _activeSource = null;
    _pendingSource = null;
    _pendingSegment = null;
    for (final handle in handles) {
      await _stopHandle(handle);
    }
  }

  Future<void> _stopHandle(SoundHandle handle) async {
    try {
      await _engine.stop(handle);
    } catch (error) {
      debugPrint('Unable to stop metronome voice: $error');
    }
  }

  void _setBusVolume(double volume) {
    final handle = _bus.soundHandle;
    if (handle != null) _engine.setVolume(handle, volume);
  }

  void _cleanupSources() {
    if (!_engine.isInitialized) return;
    final now = _engine.getEngineTime();
    _retiredSources.removeWhere((entry) => entry.safeAfter <= now);
    final protectedSources = <AudioSource>{
      ?_activeSource,
      ?_pendingSource,
      for (final entry in _retiredSources) entry.source,
    };
    while (_sourceCache.length > _maxCachedSources) {
      String? removableKey;
      for (final entry in _sourceCache.entries) {
        if (!protectedSources.contains(entry.value)) {
          removableKey = entry.key;
          break;
        }
      }
      if (removableKey == null) break;
      final source = _sourceCache.remove(removableKey)!;
      unawaited(_disposeSourceSafely(source));
    }
  }

  Future<void> _disposeSourceSafely(AudioSource source) async {
    try {
      await _engine.disposeSource(source);
    } catch (error) {
      debugPrint('Unable to dispose metronome source: $error');
    }
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

class _ClockSegment {
  const _ClockSegment({
    required this.bpm,
    required this.startAt,
    required this.startBeatIndex,
  });

  final int bpm;
  final Duration startAt;
  final int startBeatIndex;

  MetronomeClockSnapshot snapshot(Duration now, int generation) {
    final elapsedMicros = math.max(0, (now - startAt).inMicroseconds);
    final elapsedSamples =
        elapsedMicros *
        MetronomeWave.sampleRate ~/
        Duration.microsecondsPerSecond;
    final totalSamples = MetronomeWave.totalSamplesForBpm(bpm);
    final completedBars = elapsedSamples ~/ totalSamples;
    final sampleInBar = elapsedSamples % totalSamples;
    final offsets = MetronomeWave.beatSampleOffsets(bpm);
    var beatInBar = 0;
    for (var index = 1; index < offsets.length; index++) {
      if (offsets[index] > sampleInBar) break;
      beatInBar = index;
    }
    final beatIndex =
        startBeatIndex + (completedBars * MetronomeWave.beatCount) + beatInBar;
    final phaseSamples = sampleInBar - offsets[beatInBar];
    return MetronomeClockSnapshot(
      generation: generation,
      bpm: bpm,
      engineTime: now,
      beatIndex: beatIndex,
      barPosition: beatIndex % MetronomeWave.beatCount,
      phase: Duration(
        microseconds:
            phaseSamples *
            Duration.microsecondsPerSecond ~/
            MetronomeWave.sampleRate,
      ),
    );
  }

  _BeatBoundary nextBeatAfter(Duration now) {
    if (now < startAt) return _BeatBoundary(startAt, startBeatIndex);
    final elapsedMicros = (now - startAt).inMicroseconds;
    final elapsedSamples =
        elapsedMicros *
        MetronomeWave.sampleRate ~/
        Duration.microsecondsPerSecond;
    final totalSamples = MetronomeWave.totalSamplesForBpm(bpm);
    final completedBars = elapsedSamples ~/ totalSamples;
    final sampleInBar = elapsedSamples % totalSamples;
    final offsets = MetronomeWave.beatSampleOffsets(bpm);
    var nextBeatInBar = offsets.indexWhere((offset) => offset > sampleInBar);
    var absoluteBeatOffset = completedBars * MetronomeWave.beatCount;
    var absoluteSample = completedBars * totalSamples;
    if (nextBeatInBar == -1) {
      nextBeatInBar = 0;
      absoluteBeatOffset += MetronomeWave.beatCount;
      absoluteSample += totalSamples;
    } else {
      absoluteBeatOffset += nextBeatInBar;
      absoluteSample += offsets[nextBeatInBar];
    }
    return _BeatBoundary(
      startAt +
          Duration(
            microseconds:
                (absoluteSample *
                        Duration.microsecondsPerSecond /
                        MetronomeWave.sampleRate)
                    .round(),
          ),
      startBeatIndex + absoluteBeatOffset,
    );
  }
}

class _BeatBoundary {
  const _BeatBoundary(this.atTime, this.beatIndex);

  final Duration atTime;
  final int beatIndex;
}

class _RetiredSource {
  const _RetiredSource(this.source, this.safeAfter);

  final AudioSource source;
  final Duration safeAfter;
}

@visibleForTesting
class MetronomeWave {
  static const int sampleRate = 48000;
  static const int channelCount = 1;
  static const int bitsPerSample = 16;
  static const int beatCount = 4;

  static int totalSamplesForBpm(int bpm) {
    return (sampleRate * 60 * beatCount / bpm).round();
  }

  static List<int> beatSampleOffsets(int bpm) {
    return List<int>.generate(
      beatCount,
      (beat) => (sampleRate * 60 * beat / bpm).round(),
      growable: false,
    );
  }

  static Uint8List create(int bpm, {int startingBeat = 0}) {
    final safeBpm = bpm.clamp(40, 240).toInt();
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
