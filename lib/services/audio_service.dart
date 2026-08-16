import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'file_storage_service.dart';
import 'capture_lifecycle_service.dart';

class AudioService {
  AudioService({
    FileStorageService? storageService,
    AudioCaptureLifecycleController? captureLifecycle,
    this.onPlaybackChanged,
  }) : _storageService = storageService ?? FileStorageService(),
       _captureLifecycle =
           captureLifecycle ?? PlatformAudioCaptureLifecycleController();

  final FileStorageService _storageService;
  final AudioCaptureLifecycleController _captureLifecycle;
  ValueChanged<bool>? onPlaybackChanged;
  AudioRecorder? _recorderInstance;
  AudioPlayer? _playerInstance;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<RecordState>? _recordStateSubscription;
  Future<void> _recordingOperationQueue = Future<void>.value();
  Future<void> _playbackOperationQueue = Future<void>.value();
  int _playbackGeneration = 0;

  AudioRecorder get _recorder => _recorderInstance ??= AudioRecorder();

  AudioPlayer get _player => _playerInstance ??= AudioPlayer();

  bool _isRecording = false;
  bool _recordingCaptureActive = false;
  bool _isPlaying = false;
  String? _lastRecordedPath;
  String? _pendingRecordingPath;
  String? _playingStoragePath;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  String? get lastRecordedPath => _lastRecordedPath;

  void _setPlaying(bool value) {
    if (_isPlaying == value) return;
    _isPlaying = value;
    onPlaybackChanged?.call(value);
  }

  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('Error checking mic permission: $e');
      return false;
    }
  }

  Future<void> startRecording() =>
      _enqueueRecordingOperation(_startRecordingInternal);

  Future<void> _startRecordingInternal() async {
    try {
      if (_isRecording) return;
      await stopPlayback();
      if (!await _recorder.hasPermission()) {
        throw StateError('Microphone permission was not granted.');
      }

      await _captureLifecycle.begin(AudioCaptureKind.recording);
      _recordingCaptureActive = true;
      final path = await _storageService.createRecordingPath();
      _pendingRecordingPath = path;
      _recordStateSubscription ??= _recorder.onStateChanged().listen((state) {
        if (state == RecordState.stop) {
          _isRecording = false;
          unawaited(_endRecordingCapture());
        }
      });
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      _isRecording = true;
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
      _isRecording = false;
      _pendingRecordingPath = null;
      await _recordStateSubscription?.cancel();
      _recordStateSubscription = null;
      await _endRecordingCapture();
      rethrow;
    }
  }

  Future<String?> stopRecording() =>
      _enqueueRecordingOperation(_stopRecordingInternal);

  Future<String?> _stopRecordingInternal() async {
    try {
      if (!_isRecording) return null;
      final transientPath = await _recorder.stop();
      _isRecording = false;
      if (transientPath == null) return null;
      final targetPath = await _storageService.persistRecording(
        transientPath,
        _pendingRecordingPath ?? await _storageService.createRecordingPath(),
      );
      _pendingRecordingPath = null;
      _lastRecordedPath = targetPath;
      return targetPath;
    } catch (e) {
      debugPrint('Error stopping audio recording: $e');
      _isRecording = false;
      _pendingRecordingPath = null;
      rethrow;
    } finally {
      await _recordStateSubscription?.cancel();
      _recordStateSubscription = null;
      _pendingRecordingPath = null;
      await _endRecordingCapture();
    }
  }

  Future<void> _endRecordingCapture() async {
    if (!_recordingCaptureActive) return;
    _recordingCaptureActive = false;
    await _captureLifecycle.end(AudioCaptureKind.recording);
  }

  Future<T> _enqueueRecordingOperation<T>(Future<T> Function() operation) {
    final result = _recordingOperationQueue.then((_) => operation());
    _recordingOperationQueue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  Future<T> _enqueuePlaybackOperation<T>(Future<T> Function() operation) {
    final result = _playbackOperationQueue.then((_) => operation());
    _playbackOperationQueue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  Future<void> startPlayback(String path) =>
      _enqueuePlaybackOperation(() => _startPlaybackInternal(path));

  Future<void> _startPlaybackInternal(String path) async {
    if (_isRecording) {
      throw StateError('Cannot play a recording while recording.');
    }
    await _stopPlaybackInternal();
    try {
      final playablePath = await _storageService.playableRecordingPath(path);
      final generation = _playbackGeneration;
      final player = _player;
      _playingStoragePath = path;
      _playerStateSubscription = player.onPlayerStateChanged.listen((state) {
        if (!_isCurrentPlayback(player, path, generation)) return;
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          unawaited(_finishPlayback(player, path, generation));
        }
        _setPlaying(state == PlayerState.playing);
      });
      if (kIsWeb || path.startsWith('http') || path.startsWith('blob:')) {
        await player.play(UrlSource(playablePath));
      } else {
        await player.play(DeviceFileSource(playablePath));
      }
      _setPlaying(true);
    } catch (e) {
      await _stopPlaybackInternal();
      debugPrint('Error playing audio: $e');
      rethrow;
    }
  }

  bool _isCurrentPlayback(AudioPlayer player, String path, int generation) =>
      generation == _playbackGeneration &&
      identical(_playerInstance, player) &&
      _playingStoragePath == path;

  Future<void> _finishPlayback(
    AudioPlayer player,
    String path,
    int generation,
  ) async {
    if (!_isCurrentPlayback(player, path, generation)) return;
    await _releasePlayingStoragePath(path, generation);
    if (generation == _playbackGeneration &&
        identical(_playerInstance, player)) {
      _setPlaying(false);
    }
  }

  Future<void> pausePlayback() =>
      _enqueuePlaybackOperation(_pausePlaybackInternal);

  Future<void> _pausePlaybackInternal() async {
    final player = _playerInstance;
    final generation = _playbackGeneration;
    final path = _playingStoragePath;
    if (player != null) await player.pause();
    if (generation != _playbackGeneration) return;
    await _releasePlayingStoragePath(path, generation);
    _setPlaying(false);
  }

  Future<void> stopPlayback() =>
      _enqueuePlaybackOperation(_stopPlaybackInternal);

  Future<void> _stopPlaybackInternal() async {
    _playbackGeneration++;
    final subscription = _playerStateSubscription;
    _playerStateSubscription = null;
    await subscription?.cancel();
    try {
      await _playerInstance?.stop();
    } finally {
      await _releasePlayingStoragePath();
      _setPlaying(false);
    }
  }

  Future<void> _releasePlayingStoragePath([
    String? expectedPath,
    int? expectedGeneration,
  ]) async {
    if (expectedGeneration != null &&
        expectedGeneration != _playbackGeneration) {
      return;
    }
    final path = _playingStoragePath;
    if (path == null || (expectedPath != null && expectedPath != path)) return;
    _playingStoragePath = null;
    await _storageService.releasePlaybackUrl(path);
  }

  Future<void> deleteRecording(String? path) async {
    String? stoppedPath;
    if (path == null || (_isRecording && path == _pendingRecordingPath)) {
      stoppedPath = await stopRecording();
    }
    if (path == null || path == _playingStoragePath) {
      await stopPlayback();
    }
    final pathToDelete = path ?? stoppedPath ?? _lastRecordedPath;
    await _storageService.deleteManagedFile(pathToDelete);
    if (_lastRecordedPath == pathToDelete) {
      _lastRecordedPath = null;
    }
  }

  Future<void> dispose() async {
    try {
      await stopRecording();
    } catch (error) {
      debugPrint('Error disposing audio recording: $error');
    }
    await stopPlayback();
    await _playerStateSubscription?.cancel();
    await _recordStateSubscription?.cancel();
    await _recorderInstance?.dispose();
    await _playerInstance?.dispose();
  }
}
