import 'dart:io';

import 'package:path_provider/path_provider.dart';

class FileStorageService {
  FileStorageService({Directory? rootOverride}) : _rootOverride = rootOverride;

  final Directory? _rootOverride;

  Future<Directory> _managedRoot() async {
    final supportDirectory =
        _rootOverride ?? await getApplicationSupportDirectory();
    final root = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}flute_practice_coach',
    );
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
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
    return File(path).absolute.path.startsWith(rootPrefix);
  }

  Future<void> deleteManagedFile(String? path) async {
    if (path == null || path.isEmpty || !await isManagedPath(path)) return;
    final file = File(path);
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
