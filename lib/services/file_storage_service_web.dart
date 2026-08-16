import 'dart:typed_data';
import 'dart:js_interop';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

class FileStorageService {
  FileStorageService({Object? rootOverride});

  static const _recordingPrefix = 'recording://';
  Box<Uint8List>? _recordingBox;
  static final _playbackUrls = <String, String>{};
  static final _playbackUrlUsers = <String, int>{};

  Future<Box<Uint8List>> _recordings() async {
    return _recordingBox ??= await Hive.openBox<Uint8List>(
      'flute_recording_blobs',
    );
  }

  Future<String> createRecordingPath() async =>
      '$_recordingPrefix${DateTime.now().microsecondsSinceEpoch}';

  Future<String> persistRecording(String? sourcePath, String targetPath) async {
    if (sourcePath == null || sourcePath.isEmpty) {
      throw StateError('The browser did not produce an audio recording.');
    }
    try {
      final response = await http.get(Uri.parse(sourcePath));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('The browser recording could not be saved.');
      }
      final key = _keyFor(targetPath);
      final box = await _recordings();
      await box.put(key, Uint8List.fromList(response.bodyBytes));
      return targetPath;
    } finally {
      if (sourcePath.startsWith('blob:')) {
        web.URL.revokeObjectURL(sourcePath);
      }
    }
  }

  Future<String> playableRecordingPath(String path) async {
    if (!path.startsWith(_recordingPrefix)) return path;
    final existing = _playbackUrls[path];
    if (existing != null) {
      _playbackUrlUsers[path] = (_playbackUrlUsers[path] ?? 0) + 1;
      return existing;
    }
    final bytes = (await _recordings()).get(_keyFor(path));
    if (bytes == null) throw StateError('Recording file not found.');
    final blob = web.Blob([bytes.toJS].toJS);
    final url = web.URL.createObjectURL(blob);
    _playbackUrls[path] = url;
    _playbackUrlUsers[path] = 1;
    return url;
  }

  Future<void> releasePlaybackUrl(String path) async {
    final users = (_playbackUrlUsers[path] ?? 1) - 1;
    if (users > 0) {
      _playbackUrlUsers[path] = users;
      return;
    }
    _playbackUrlUsers.remove(path);
    final url = _playbackUrls.remove(path);
    if (url != null) web.URL.revokeObjectURL(url);
  }

  Future<String> importPdf(String sourcePath, {String? originalName}) {
    throw UnsupportedError(
      'Persistent PDF attachments are not supported in the browser.',
    );
  }

  Future<bool> isManagedPath(String path) async =>
      path.startsWith(_recordingPrefix);

  Future<void> deleteManagedFile(String? path) async {
    if (path == null || !path.startsWith(_recordingPrefix)) return;
    await (await _recordings()).delete(_keyFor(path));
    final url = _playbackUrls.remove(path);
    _playbackUrlUsers.remove(path);
    if (url != null) web.URL.revokeObjectURL(url);
  }

  Future<void> deleteAllManagedFiles() async {
    final box = await _recordings();
    await box.clear();
    for (final url in _playbackUrls.values) {
      web.URL.revokeObjectURL(url);
    }
    _playbackUrls.clear();
    _playbackUrlUsers.clear();
  }

  String _keyFor(String path) => path.substring(_recordingPrefix.length);
}
