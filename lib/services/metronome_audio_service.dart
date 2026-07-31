import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart' as background_audio;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

abstract interface class MetronomeAudioController {
  ValueChanged<bool>? onExternalPlayingChanged;

  Future<void> start({required int bpm, required double volume});
  Future<void> setTempo(int bpm);
  Future<void> setVolume(double volume);
  Future<void> stop();
}

class NoopMetronomeAudioController implements MetronomeAudioController {
  @override
  ValueChanged<bool>? onExternalPlayingChanged;

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

  @override
  ValueChanged<bool>? onExternalPlayingChanged;

  Future<void> initialize() async {
    if (_handler != null) return;
    final handler = _MetronomeAudioHandler(
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
  _MetronomeAudioHandler({required this.onExternalPlayingChanged}) {
    mediaItem.add(_mediaItemFor(80));
  }

  final ValueChanged<bool> onExternalPlayingChanged;
  final AudioPlayer _player = AudioPlayer();
  Future<void> _operation = Future<void>.value();
  int _bpm = 80;
  double _volume = 0.7;
  bool _hasSource = false;

  static final AudioContext _audioContext = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
    stayAwake: true,
  ).build();

  Future<void> startMetronome({required int bpm, required double volume}) {
    _bpm = bpm.clamp(40, 240).toInt();
    _volume = volume.clamp(0.0, 1.0);
    return _enqueue(() async {
      await _loadLoop();
      await _player.resume();
      _broadcast(playing: true);
    });
  }

  Future<void> setTempo(int bpm) {
    final wasPlaying = playbackState.value.playing;
    _bpm = bpm.clamp(40, 240).toInt();
    if (!wasPlaying) {
      mediaItem.add(_mediaItemFor(_bpm));
      return Future<void>.value();
    }
    return _enqueue(() async {
      await _loadLoop();
      await _player.resume();
      _broadcast(playing: true);
    });
  }

  Future<void> setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    return _enqueue(() => _player.setVolume(_volume));
  }

  @override
  Future<void> play() {
    if (!_hasSource) {
      return startMetronome(
        bpm: _bpm,
        volume: _volume,
      ).then((_) => onExternalPlayingChanged(true));
    }
    return _enqueue(() async {
      await _player.resume();
      _broadcast(playing: true);
      onExternalPlayingChanged(true);
    });
  }

  @override
  Future<void> pause() {
    return _enqueue(() async {
      await _player.pause();
      _broadcast(playing: false);
      onExternalPlayingChanged(false);
    });
  }

  @override
  Future<void> stop() {
    return _stopPlayback(notifyExternal: true);
  }

  Future<void> stopMetronome() {
    return _stopPlayback(notifyExternal: false);
  }

  Future<void> _stopPlayback({required bool notifyExternal}) {
    return _enqueue(() async {
      await _player.stop();
      _hasSource = false;
      playbackState.add(
        playbackState.value.copyWith(
          controls: const [],
          playing: false,
          processingState: background_audio.AudioProcessingState.idle,
        ),
      );
      if (notifyExternal) onExternalPlayingChanged(false);
      await super.stop();
    });
  }

  Future<void> _loadLoop() async {
    final loop = _MetronomeWave.create(_bpm);
    await _player.setAudioContext(_audioContext);
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setSource(BytesSource(loop, mimeType: 'audio/wav'));
    await _player.setVolume(_volume);
    _hasSource = true;
    mediaItem.add(_mediaItemFor(_bpm));
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _operation.then((_) => operation());
    _operation = result.catchError((Object error, StackTrace stackTrace) {
      debugPrint('Metronome audio error: $error');
    });
    return result;
  }

  void _broadcast({required bool playing}) {
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

class _MetronomeWave {
  static const int _sampleRate = 44100;
  static const int _channelCount = 1;
  static const int _bitsPerSample = 16;
  static const int _beatCount = 4;

  static Uint8List create(int bpm) {
    final secondsPerBeat = 60 / bpm;
    final totalSamples = (_sampleRate * secondsPerBeat * _beatCount).round();
    final samples = Int16List(totalSamples);
    final clickSamples = (_sampleRate * 0.04).round();

    for (var beat = 0; beat < _beatCount; beat++) {
      final start = (_sampleRate * secondsPerBeat * beat).round();
      final frequency = beat == 0 ? 1760.0 : 1100.0;
      final gain = beat == 0 ? 0.88 : 0.68;
      for (var offset = 0; offset < clickSamples; offset++) {
        final sampleIndex = start + offset;
        if (sampleIndex >= samples.length) break;
        final time = offset / _sampleRate;
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
    bytes.setUint16(22, _channelCount, Endian.little);
    bytes.setUint32(24, _sampleRate, Endian.little);
    bytes.setUint32(
      28,
      _sampleRate * _channelCount * (_bitsPerSample ~/ 8),
      Endian.little,
    );
    bytes.setUint16(32, _channelCount * (_bitsPerSample ~/ 8), Endian.little);
    bytes.setUint16(34, _bitsPerSample, Endian.little);
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
