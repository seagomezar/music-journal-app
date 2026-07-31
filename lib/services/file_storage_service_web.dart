class FileStorageService {
  FileStorageService({Object? rootOverride});

  Future<String> createRecordingPath() async => '';

  Future<String> importPdf(String sourcePath, {String? originalName}) {
    throw UnsupportedError(
      'Persistent PDF attachments are not supported in the browser.',
    );
  }

  Future<bool> isManagedPath(String path) async => false;

  Future<void> deleteManagedFile(String? path) async {}

  Future<void> deleteAllManagedFiles() async {}
}
