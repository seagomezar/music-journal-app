import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  AudioRecorder? _recorderInstance;
  AudioPlayer? _playerInstance;

  AudioRecorder get _recorder => _recorderInstance ??= AudioRecorder();
  
  AudioPlayer get _player {
    if (_playerInstance == null) {
      _playerInstance = AudioPlayer();
      _playerInstance!.onPlayerStateChanged.listen((state) {
        _isPlaying = state == PlayerState.playing;
      });
    }
    return _playerInstance!;
  }

  bool _isRecording = false;
  bool _isPlaying = false;
  String? _lastRecordedPath;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  String? get lastRecordedPath => _lastRecordedPath;

  AudioService();

  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('Error checking mic permission: $e');
      return false;
    }
  }

  Future<void> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        String? path;
        if (!kIsWeb) {
          final tempDir = await getTemporaryDirectory();
          path = '${tempDir.path}/flute_practice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }
        
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path ?? '',
        );
        _isRecording = true;
      }
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
      _isRecording = false;
      rethrow;
    }
  }

  Future<String?> stopRecording() async {
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
    }
  }

  Future<void> startPlayback(String path) async {
    try {
      if (kIsWeb || path.startsWith('http') || path.startsWith('blob:')) {
        await _player.play(UrlSource(path));
      } else {
        await _player.play(DeviceFileSource(path));
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
      rethrow;
    }
  }

  Future<void> pausePlayback() async {
    await _player.pause();
  }

  Future<void> stopPlayback() async {
    await _player.stop();
  }

  void dispose() {
    _recorderInstance?.dispose();
    _playerInstance?.dispose();
  }
}
