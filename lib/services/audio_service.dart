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
      final path = kIsWeb ? '' : await _storageService.createRecordingPath();
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
      final path = await _recorder.stop();
      _isRecording = false;
      _lastRecordedPath = path;
      return path;
    } catch (e) {
      debugPrint('Error stopping audio recording: $e');
      _isRecording = false;
      return null;
    } finally {
      await _recordStateSubscription?.cancel();
      _recordStateSubscription = null;
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
    try {
      if (kIsWeb || path.startsWith('http') || path.startsWith('blob:')) {
        await _player.play(UrlSource(path));
      } else {
        await _player.play(DeviceFileSource(path));
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
    final stoppedPath = await stopRecording();
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
