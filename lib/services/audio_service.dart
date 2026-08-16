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

  AudioRecorder get _recorder => _recorderInstance ??= AudioRecorder();

  AudioPlayer get _player {
    if (_playerInstance == null) {
      _playerInstance = AudioPlayer();
      _playerStateSubscription = _playerInstance!.onPlayerStateChanged.listen((
        state,
      ) {
        _setPlaying(state == PlayerState.playing);
      });
    }
    return _playerInstance!;
  }

  bool _isRecording = false;
  bool _recordingCaptureActive = false;
  bool _isPlaying = false;
  String? _lastRecordedPath;
  String? _pendingRecordingPath;

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

  Future<void> startPlayback(String path) async {
    if (_isRecording) {
      throw StateError('Cannot play a recording while recording.');
    }
    try {
      final playablePath = await _storageService.playableRecordingPath(path);
      if (kIsWeb || path.startsWith('http') || path.startsWith('blob:')) {
        await _player.play(UrlSource(playablePath));
      } else {
        await _player.play(DeviceFileSource(playablePath));
      }
      _setPlaying(true);
    } catch (e) {
      debugPrint('Error playing audio: $e');
      rethrow;
    }
  }

  Future<void> pausePlayback() async {
    await _player.pause();
    _setPlaying(false);
  }

  Future<void> stopPlayback() async {
    if (_playerInstance != null) {
      await _player.stop();
    }
    _setPlaying(false);
  }

  Future<void> deleteRecording(String? path) async {
    String? stoppedPath;
    if (path == null || (_isRecording && path == _pendingRecordingPath)) {
      stoppedPath = await stopRecording();
    }
    await stopPlayback();
    final pathToDelete = path ?? stoppedPath ?? _lastRecordedPath;
    await _storageService.deleteManagedFile(pathToDelete);
    if (_lastRecordedPath == pathToDelete) {
      _lastRecordedPath = null;
    }
  }

  Future<void> dispose() async {
    await stopRecording();
    await stopPlayback();
    await _playerStateSubscription?.cancel();
    await _recordStateSubscription?.cancel();
    await _recorderInstance?.dispose();
    await _playerInstance?.dispose();
  }
}
