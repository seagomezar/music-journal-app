import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../models/piece.dart';
import '../models/repertoire_folder.dart';
import '../models/pdf_annotation.dart';
import '../models/routine.dart';
import '../models/score_view_preferences.dart';
import '../models/session_record.dart';
import '../models/user_profile.dart';
import 'database_service.dart';
import 'file_storage_service.dart';

class FullBackupData {
  const FullBackupData(this.records, this.media, this.exportedAt);
  final Map<String, Map<String, dynamic>> records;
  final Map<String, Uint8List> media;
  final DateTime exportedAt;
  int get sessionCount => records['sessions']!.length;
  int get pieceCount => records['repertoire']!.length;
}

/// Full, user-controlled backups. No archive pathname is extracted to disk.
/// Media uses content-addressed identifiers and is written before metadata.
class FullBackupService {
  FullBackupService({FileStorageService? storage})
    : _storage = storage ?? FileStorageService();
  final FileStorageService _storage;
  static const maxBytes = 256 * 1024 * 1024;
  static const _tables = {
    'profile',
    'routines',
    'repertoire',
    'folders',
    'annotations',
    'scorePreferences',
    'sessions',
  };
  static const _pathKeys = {
    'pdfPath',
    'sourcePath',
    'storagePath',
    'audioFilePath',
  };

  static dynamic _walk(dynamic value, String Function(String, String) path) {
    if (value is List) return value.map((v) => _walk(v, path)).toList();
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(
          key.toString(),
          _pathKeys.contains(key) && item is String
              ? path(key as String, item)
              : _walk(item, path),
        ),
      );
    }
    return value;
  }

  static Map<String, Map<String, dynamic>> _mapRecords(
    Map<String, Map<String, dynamic>> records,
    String Function(String, String) transform,
  ) => {
    for (final table in records.entries)
      table.key: {
        for (final record in table.value.entries)
          record.key: table.key == 'profile'
              ? record.value
              : jsonEncode(
                  _walk(jsonDecode(record.value as String), transform),
                ),
      },
  };

  Future<Uint8List> create(DatabaseService db) async {
    final records = db.exportSnapshot();
    final paths = <String, String>{};
    _mapRecords(records, (kind, path) {
      paths[path] = kind;
      return path;
    });
    final replacements = <String, String>{};
    final media = <String, Uint8List>{};
    var size = 0;
    for (final path in paths.entries) {
      final bytes = await _storage.readMedia(path.key);
      final hash = sha256.convert(bytes).toString();
      final identifier = path.value == 'pdfPath' || path.value == 'sourcePath'
          ? 'media://scores/$hash.pdf'
          : 'media://recordings/$hash.${_audioExtension(bytes, path.key)}';
      replacements[path.key] = identifier;
      if (!media.containsKey(identifier)) size += bytes.length;
      if (size > maxBytes) {
        throw const FormatException(
          'Full backup exceeds the supported 256 MB limit.',
        );
      }
      media[identifier] = bytes;
    }
    final normalized = _mapRecords(records, (_, path) => replacements[path]!);
    final document = {
      'format': 'flute-practice-coach-full',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'records': normalized,
      'media': {
        for (final entry in media.entries)
          entry.key: {
            'entry': 'media/${sha256.convert(entry.value)}',
            'sha256': sha256.convert(entry.value).toString(),
            'size': entry.value.length,
          },
      },
    };
    final manifest = utf8.encode(jsonEncode(document));
    if (size + manifest.length > maxBytes) {
      throw const FormatException('Backup exceeds 256 MB.');
    }
    final archive = Archive()
      ..add(ArchiveFile('manifest.json', manifest.length, manifest));
    final added = <String>{};
    for (final bytes in media.values) {
      final name = 'media/${sha256.convert(bytes)}';
      if (added.add(name)) archive.add(ArchiveFile(name, bytes.length, bytes));
    }
    final result = Uint8List.fromList(ZipEncoder().encode(archive));
    parse(result); // Only offer a download that passes our restore contract.
    return result;
  }

  FullBackupData parse(Uint8List bytes) {
    if (bytes.length > maxBytes || bytes.isEmpty) {
      throw const FormatException('Invalid backup size (maximum 256 MB).');
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    var expandedSize = 0;
    if (archive.length > 20000) {
      throw const FormatException('Too many media files.');
    }
    for (final file in archive) {
      expandedSize += file.size;
      if (!file.isFile ||
          file.isSymbolicLink ||
          expandedSize > maxBytes ||
          !(file.name == 'manifest.json' ||
              RegExp(r'^media/[a-f0-9]{64}$').hasMatch(file.name))) {
        throw const FormatException('Invalid backup entry.');
      }
    }
    final manifest = archive.find('manifest.json');
    if (manifest == null) {
      throw const FormatException('Backup manifest is missing.');
    }
    final root =
        jsonDecode(utf8.decode(manifest.content)) as Map<String, dynamic>;
    if (root['format'] != 'flute-practice-coach-full' || root['version'] != 1) {
      throw const FormatException('Unsupported full backup version.');
    }
    final records = (root['records'] as Map).map(
      (key, value) =>
          MapEntry(key as String, Map<String, dynamic>.from(value as Map)),
    );
    if (records.length != _tables.length ||
        !records.keys.toSet().containsAll(_tables)) {
      throw const FormatException('Incomplete backup records.');
    }
    _validateRecords(records);
    final media = <String, Uint8List>{};
    for (final item in (root['media'] as Map).entries) {
      final identifier = item.key as String;
      if (!RegExp(
        r'^media://(scores/[a-f0-9]{64}\.pdf|recordings/[a-f0-9]{64}\.(audio|m4a|mp4|aac|wav|webm|ogg|opus|mp3))$',
      ).hasMatch(identifier)) {
        throw const FormatException('Invalid media identifier.');
      }
      final metadata = item.value as Map;
      final file = archive.find(metadata['entry'] as String);
      if (file == null || file.size != metadata['size']) {
        throw const FormatException('Missing or incomplete media.');
      }
      final content = file.content;
      final hash = sha256.convert(content).toString();
      if (hash != metadata['sha256'] || !identifier.contains('/$hash.')) {
        throw const FormatException('Media integrity check failed.');
      }
      media[identifier] = Uint8List.fromList(content);
    }
    _mapRecords(records, (_, path) {
      if (!media.containsKey(path)) {
        throw const FormatException(
          'A media reference is missing from this backup.',
        );
      }
      return path;
    });
    return FullBackupData(
      records,
      media,
      DateTime.parse(root['exportedAt'] as String),
    );
  }

  static void _validateRecords(Map<String, Map<String, dynamic>> records) {
    final parsers = <String, void Function(Map<String, dynamic>)>{
      'routines': Routine.fromJson,
      'repertoire': Piece.fromJson,
      'folders': RepertoireFolder.fromJson,
      'annotations': PdfAnnotationDocument.fromJson,
      'scorePreferences': ScoreViewPreferences.fromJson,
      'sessions': SessionRecord.fromJson,
    };
    for (final table in parsers.entries) {
      for (final entry in records[table.key]!.entries) {
        final value = Map<String, dynamic>.from(
          jsonDecode(entry.value as String) as Map,
        );
        table.value(value);
        if ((value['id'] ?? value['pieceId']) != entry.key) {
          throw const FormatException('Record identifier mismatch.');
        }
      }
    }
    final profile = records['profile']!;
    if (profile['active_user'] != null) {
      UserProfile.fromJson(
        jsonDecode(profile['active_user'] as String) as Map<String, dynamic>,
      );
    }
    for (final entry in profile.entries) {
      if (entry.key == 'active_user') continue;
      final value = entry.value;
      if (entry.key == 'seed_version' && value is! int) {
        throw const FormatException('Invalid seed version.');
      }
      if (const {
        'keep_screen_awake',
        'metronome_sound',
        'practice_haptics',
        'practice_sound_cues',
        'practice_reduced_motion',
        'practice_show_celebrations',
      }.contains(entry.key)) {
        if (value is! bool) throw const FormatException('Invalid preference.');
      } else if (const {
        'seed_version',
        'metronome_volume',
        'tuner_reference_hz',
        'tuner_tolerance_cents',
        'performance_brightness',
      }.contains(entry.key)) {
        if (value is! num || !value.isFinite) {
          throw const FormatException('Invalid numeric preference.');
        }
      } else if (value is! String) {
        throw const FormatException('Invalid preference value.');
      }
    }
  }

  // Native players can require a recognizable extension even when bytes are
  // intact. Browser recording identifiers do not carry a filename, so inspect
  // the container signature first and preserve known source extensions second.
  static String _audioExtension(Uint8List bytes, String source) {
    bool signature(int offset, List<int> expected) {
      if (bytes.length < offset + expected.length) return false;
      for (var i = 0; i < expected.length; i++) {
        if (bytes[offset + i] != expected[i]) return false;
      }
      return true;
    }

    if (signature(0, [0x52, 0x49, 0x46, 0x46]) &&
        signature(8, [0x57, 0x41, 0x56, 0x45])) {
      return 'wav';
    }
    if (signature(4, [0x66, 0x74, 0x79, 0x70])) return 'm4a';
    if (signature(0, [0x1a, 0x45, 0xdf, 0xa3])) return 'webm';
    if (signature(0, [0x4f, 0x67, 0x67, 0x53])) return 'ogg';
    if (signature(0, [0x49, 0x44, 0x33])) return 'mp3';
    if (bytes.length >= 2 && bytes[0] == 0xff) {
      if ((bytes[1] & 0xf6) == 0xf0) return 'aac';
      if ((bytes[1] & 0xe0) == 0xe0) return 'mp3';
    }
    final extension = source.split('.').last.toLowerCase();
    return const {
          'm4a',
          'mp4',
          'aac',
          'wav',
          'webm',
          'ogg',
          'opus',
          'mp3',
        }.contains(extension)
        ? extension
        : 'audio';
  }

  Future<void> restore(DatabaseService db, FullBackupData backup) async {
    for (final entry in backup.media.entries) {
      await _storage.writeMedia(entry.key, entry.value);
      if (sha256.convert(await _storage.readMedia(entry.key)).toString() !=
          sha256.convert(entry.value).toString()) {
        throw const FormatException('Could not verify restored media.');
      }
    }
    await db.restoreSnapshot(backup.records);
  }
}
