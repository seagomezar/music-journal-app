import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class FileStorageService {
  FileStorageService({Directory? rootOverride}) : _rootOverride = rootOverride;

  final Directory? _rootOverride;
  String? _rootPath;

  Future<void> initialize() async {
    await _managedRoot();
  }

  String portablePath(String path) {
    if (path.startsWith('media://') || path.startsWith('recording://')) {
      return path;
    }
    final normalized = path.replaceAll('\\', '/');
    const marker = '/flute_practice_coach/';
    final offset = normalized.lastIndexOf(marker);
    if (offset < 0) return path;
    final key = normalized.substring(offset + marker.length);
    _validateKey(key);
    return 'media://$key';
  }

  static void _validateKey(String key) {
    if (!RegExp(r'^(scores|recordings)/[A-Za-z0-9_.-]+$').hasMatch(key) ||
        key.contains('..')) {
      throw const FormatException('Invalid media identifier.');
    }
  }

  String resolveStoredPath(String path) {
    var portable = portablePath(path);
    if (portable.startsWith('recording://')) {
      portable = 'media://recordings/${portable.substring(12)}.audio';
    }
    if (!portable.startsWith('media://')) return path;
    final key = portable.substring(8);
    _validateKey(key);
    if (_rootPath == null) throw StateError('File storage is not initialized.');
    return '$_rootPath/${key.replaceAll('/', Platform.pathSeparator)}';
  }

  Future<Uint8List> readMedia(String path) async {
    await initialize();
    return File(resolveStoredPath(path)).readAsBytes();
  }

  Future<void> writeMedia(String identifier, Uint8List bytes) async {
    await initialize();
    if (!identifier.startsWith('media://') &&
        !identifier.startsWith('recording://')) {
      throw const FormatException('A portable media identifier is required.');
    }
    final file = File(resolveStoredPath(identifier));
    await file.parent.create(recursive: true);
    // Restores may repair a damaged copy of a content-addressed attachment.
    // Stage and flush before replacement so metadata never points at a
    // partially written file.
    final temporary = File('${file.path}.partial');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(file.path);
  }

  Future<Directory> _managedRoot() async {
    final supportDirectory =
        _rootOverride ?? await getApplicationSupportDirectory();
    final root = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}flute_practice_coach',
    );
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    _rootPath = root.path;
    return root;
  }

  Future<String> createRecordingPath() async {
    final root = await _managedRoot();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}recordings',
    );
    await directory.create(recursive: true);
    return '${directory.path}${Platform.pathSeparator}'
        'practice_${DateTime.now().microsecondsSinceEpoch}.m4a';
  }

  Future<String> persistRecording(String? sourcePath, String targetPath) async {
    return targetPath;
  }

  Future<String> playableRecordingPath(String path) async {
    await initialize();
    return resolveStoredPath(path);
  }

  Future<void> releasePlaybackUrl(String path) async {}

  Future<String> importPdf(String sourcePath, {String? originalName}) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('The selected PDF is no longer available.');
    }

    final root = await _managedRoot();
    final directory = Directory('${root.path}${Platform.pathSeparator}scores');
    await directory.create(recursive: true);

    final rawName = originalName ?? source.uri.pathSegments.last;
    final safeName = rawName
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final normalizedName = safeName.toLowerCase().endsWith('.pdf')
        ? safeName
        : '$safeName.pdf';
    final destination = File(
      '${directory.path}${Platform.pathSeparator}'
      '${DateTime.now().microsecondsSinceEpoch}_$normalizedName',
    );
    return (await source.copy(destination.path)).path;
  }

  Future<bool> isManagedPath(String path) async {
    final root = await _managedRoot();
    final rootPrefix = '${root.absolute.path}${Platform.pathSeparator}';
    return File(
      resolveStoredPath(path),
    ).absolute.uri.normalizePath().toFilePath().startsWith(rootPrefix);
  }

  Future<void> deleteManagedFile(String? path) async {
    if (path == null || path.isEmpty || !await isManagedPath(path)) return;
    final file = File(resolveStoredPath(path));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteAllManagedFiles() async {
    final root = await _managedRoot();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }
}
