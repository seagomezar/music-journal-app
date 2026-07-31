Future<bool> localFileExists(String path) async {
  return path.startsWith('blob:') ||
      path.startsWith('data:') ||
      path.startsWith('http://') ||
      path.startsWith('https://');
}
