import 'dart:io';

Future<bool> localFileExists(String path) => File(path).exists();
