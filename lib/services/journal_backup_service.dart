import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../models/exercise.dart';
import '../models/routine.dart';
import '../models/session_record.dart';

class JournalBackupException implements Exception {
  const JournalBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class JournalBackupData {
  const JournalBackupData({
    required this.exportedAt,
    required this.appVersion,
    required this.routines,
    required this.sessions,
  });

  final DateTime exportedAt;
  final String appVersion;
  final List<Routine> routines;
  final List<SessionRecord> sessions;
}

class JournalImportPlan {
  const JournalImportPlan({
    required this.backup,
    required this.routinesToAdd,
    required this.sessionsToAdd,
    required this.skippedRoutines,
    required this.skippedSessions,
    required this.routineConflicts,
    required this.sessionConflicts,
  });

  final JournalBackupData backup;
  final List<Routine> routinesToAdd;
  final List<SessionRecord> sessionsToAdd;
  final int skippedRoutines;
  final int skippedSessions;
  final int routineConflicts;
  final int sessionConflicts;

  int get importedCount => routinesToAdd.length + sessionsToAdd.length;
  int get skippedCount => skippedRoutines + skippedSessions;
}

class JournalBackupService {
  static const format = 'flute-practice-coach-journal';
  static const schemaVersion = 1;
  static const maxBackupBytes = 20 * 1024 * 1024;

  String createBackup({
    required List<Routine> routines,
    required List<SessionRecord> sessions,
    required String appVersion,
    DateTime? exportedAt,
  }) {
    final document = <String, dynamic>{
      'format': format,
      'schemaVersion': schemaVersion,
      'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'appVersion': appVersion,
      'routines': routines.map(_routineJson).toList(),
      'sessions': sessions.map(_sessionJson).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(document);
  }

  JournalBackupData parseBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const JournalBackupException('The backup file is empty.');
    }
    if (bytes.length > maxBackupBytes) {
      throw const JournalBackupException('The backup file is too large.');
    }

    String source;
    try {
      source = utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw const JournalBackupException('The backup is not valid UTF-8.');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const JournalBackupException('The backup is not valid JSON.');
    }

    final root = _object(decoded, r'$');
    _keys(root, r'$', const {
      'format',
      'schemaVersion',
      'exportedAt',
      'appVersion',
      'routines',
      'sessions',
    });
    if (_string(root['format'], r'$.format', max: 100) != format) {
      throw const JournalBackupException(
        'This file is not a Flute Practice Coach journal backup.',
      );
    }
    final version = _integer(
      root['schemaVersion'],
      r'$.schemaVersion',
      min: 1,
      max: 1000000,
    );
    if (version != schemaVersion) {
      throw JournalBackupException(
        version > schemaVersion
            ? 'This backup was created by a newer app version.'
            : 'This backup version is no longer supported.',
      );
    }

    final routineValues = _list(root['routines'], r'$.routines', max: 10000);
    final sessionValues = _list(root['sessions'], r'$.sessions', max: 100000);
    final routines = <Routine>[];
    final routineIds = <String>{};
    for (var index = 0; index < routineValues.length; index++) {
      final routine = _parseRoutine(
        routineValues[index],
        '\$.routines[$index]',
      );
      if (!routineIds.add(routine.id)) {
        throw JournalBackupException(
          'Duplicate routine ID at routines[$index].',
        );
      }
      routines.add(routine);
    }

    final sessions = <SessionRecord>[];
    final sessionIds = <String>{};
    for (var index = 0; index < sessionValues.length; index++) {
      final session = _parseSession(
        sessionValues[index],
        '\$.sessions[$index]',
      );
      if (!sessionIds.add(session.id)) {
        throw JournalBackupException(
          'Duplicate session ID at sessions[$index].',
        );
      }
      sessions.add(session);
    }

    return JournalBackupData(
      exportedAt: _timestamp(root['exportedAt'], r'$.exportedAt'),
      appVersion: _string(root['appVersion'], r'$.appVersion', max: 50),
      routines: List.unmodifiable(routines),
      sessions: List.unmodifiable(sessions),
    );
  }

  JournalImportPlan createImportPlan({
    required JournalBackupData backup,
    required List<Routine> existingRoutines,
    required List<SessionRecord> existingSessions,
  }) {
    final routinesById = <String, Routine>{
      for (final routine in existingRoutines) routine.id: routine,
    };
    final sessionsById = <String, SessionRecord>{
      for (final session in existingSessions) session.id: session,
    };
    final routinesToAdd = <Routine>[];
    final sessionsToAdd = <SessionRecord>[];
    var skippedRoutines = 0;
    var skippedSessions = 0;
    var routineConflicts = 0;
    var sessionConflicts = 0;

    for (final incoming in backup.routines) {
      final existing = routinesById[incoming.id];
      if (existing == null) {
        routinesToAdd.add(incoming);
        routinesById[incoming.id] = incoming;
        continue;
      }
      if (_sameRoutineContent(existing, incoming)) {
        skippedRoutines++;
        continue;
      }

      routineConflicts++;
      final conflictId = _availableConflictId(
        kind: 'routine',
        content: _routineContentJson(incoming),
        existingIds: routinesById.keys,
        isSameContent: (id) => _sameRoutineContent(routinesById[id]!, incoming),
      );
      if (conflictId == null) {
        skippedRoutines++;
        continue;
      }
      final imported = Routine(
        id: conflictId,
        title: incoming.title,
        description: incoming.description,
        exercises: incoming.exercises,
      );
      routinesToAdd.add(imported);
      routinesById[imported.id] = imported;
    }

    for (final incoming in backup.sessions) {
      final existing = sessionsById[incoming.id];
      if (existing == null) {
        sessionsToAdd.add(incoming);
        sessionsById[incoming.id] = incoming;
        continue;
      }
      if (_sameSessionContent(existing, incoming)) {
        skippedSessions++;
        continue;
      }

      sessionConflicts++;
      final conflictId = _availableConflictId(
        kind: 'session',
        content: _sessionContentJson(incoming),
        existingIds: sessionsById.keys,
        isSameContent: (id) => _sameSessionContent(sessionsById[id]!, incoming),
      );
      if (conflictId == null) {
        skippedSessions++;
        continue;
      }
      final imported = SessionRecord(
        id: conflictId,
        startTime: incoming.startTime,
        endTime: incoming.endTime,
        startUtcOffsetMinutes: incoming.startUtcOffsetMinutes,
        endUtcOffsetMinutes: incoming.endUtcOffsetMinutes,
        totalDurationInSeconds: incoming.totalDurationInSeconds,
        completedExercises: incoming.completedExercises,
        rehearsedPieces: incoming.rehearsedPieces,
        notes: incoming.notes,
      );
      sessionsToAdd.add(imported);
      sessionsById[imported.id] = imported;
    }

    return JournalImportPlan(
      backup: backup,
      routinesToAdd: List.unmodifiable(routinesToAdd),
      sessionsToAdd: List.unmodifiable(sessionsToAdd),
      skippedRoutines: skippedRoutines,
      skippedSessions: skippedSessions,
      routineConflicts: routineConflicts,
      sessionConflicts: sessionConflicts,
    );
  }

  static Map<String, dynamic> _routineJson(Routine routine) => {
    'id': routine.id,
    ..._routineContentJson(routine),
  };

  static Map<String, dynamic> _routineContentJson(Routine routine) => {
    'title': routine.title,
    'description': routine.description,
    'exercises': routine.exercises.map(_exerciseJson).toList(),
  };

  static Map<String, dynamic> _exerciseJson(Exercise exercise) => {
    'id': exercise.id,
    'name': exercise.name,
    'targetBpm': exercise.targetBpm,
    'articulation': exercise.articulation,
  };

  static Map<String, dynamic> _sessionJson(SessionRecord session) => {
    'id': session.id,
    ..._sessionContentJson(session),
  };

  static Map<String, dynamic> _sessionContentJson(SessionRecord session) => {
    'startTime': session.startTime.toUtc().toIso8601String(),
    'endTime': session.endTime.toUtc().toIso8601String(),
    'startUtcOffsetMinutes': session.startUtcOffsetMinutes,
    'endUtcOffsetMinutes': session.endUtcOffsetMinutes,
    'totalDurationInSeconds': session.totalDurationInSeconds,
    'completedExercises': session.completedExercises
        .map(_exerciseJson)
        .toList(),
    'rehearsedPieces': session.rehearsedPieces
        .map(
          (piece) => {
            'pieceId': piece.pieceId,
            'pieceTitle': piece.pieceTitle,
            'durationInSeconds': piece.durationInSeconds,
            'measuresWorked': piece.measuresWorked,
          },
        )
        .toList(),
    'notes': session.notes,
  };

  static Routine _parseRoutine(dynamic value, String path) {
    final map = _object(value, path);
    _keys(map, path, const {'id', 'title', 'description', 'exercises'});
    final exercisesValue = _list(
      map['exercises'],
      '$path.exercises',
      max: 1000,
    );
    final exercises = <Exercise>[];
    final exerciseIds = <String>{};
    for (var index = 0; index < exercisesValue.length; index++) {
      final exercise = _parseExercise(
        exercisesValue[index],
        '$path.exercises[$index]',
      );
      if (!exerciseIds.add(exercise.id)) {
        throw JournalBackupException(
          'Duplicate exercise ID at $path.exercises[$index].',
        );
      }
      exercises.add(exercise);
    }
    return Routine(
      id: _identifier(map['id'], '$path.id'),
      title: _string(map['title'], '$path.title', min: 1, max: 100),
      description: _string(map['description'], '$path.description', max: 5000),
      exercises: exercises,
    );
  }

  static Exercise _parseExercise(dynamic value, String path) {
    final map = _object(value, path);
    _keys(map, path, const {'id', 'name', 'targetBpm', 'articulation'});
    return Exercise(
      id: _identifier(map['id'], '$path.id'),
      name: _string(map['name'], '$path.name', min: 1, max: 200),
      targetBpm: _integer(
        map['targetBpm'],
        '$path.targetBpm',
        min: 40,
        max: 240,
      ),
      articulation: _string(
        map['articulation'],
        '$path.articulation',
        min: 1,
        max: 100,
      ),
    );
  }

  static SessionRecord _parseSession(dynamic value, String path) {
    final map = _object(value, path);
    _keys(map, path, const {
      'id',
      'startTime',
      'endTime',
      'startUtcOffsetMinutes',
      'endUtcOffsetMinutes',
      'totalDurationInSeconds',
      'completedExercises',
      'rehearsedPieces',
      'notes',
    });
    final startTime = _timestamp(map['startTime'], '$path.startTime');
    final endTime = _timestamp(map['endTime'], '$path.endTime');
    if (endTime.isBefore(startTime)) {
      throw JournalBackupException('$path.endTime is before its start time.');
    }
    if (startTime.year < 1900 || startTime.year > 2100) {
      throw JournalBackupException(
        '$path.startTime is outside the supported range.',
      );
    }

    final completedValues = _list(
      map['completedExercises'],
      '$path.completedExercises',
      max: 1000,
    );
    final completedExercises = <Exercise>[];
    for (var index = 0; index < completedValues.length; index++) {
      completedExercises.add(
        _parseExercise(
          completedValues[index],
          '$path.completedExercises[$index]',
        ),
      );
    }

    final pieceValues = _list(
      map['rehearsedPieces'],
      '$path.rehearsedPieces',
      max: 1000,
    );
    final pieces = <SessionPieceRecord>[];
    for (var index = 0; index < pieceValues.length; index++) {
      final piecePath = '$path.rehearsedPieces[$index]';
      final piece = _object(pieceValues[index], piecePath);
      _keys(piece, piecePath, const {
        'pieceId',
        'pieceTitle',
        'durationInSeconds',
        'measuresWorked',
      });
      pieces.add(
        SessionPieceRecord(
          pieceId: _identifier(piece['pieceId'], '$piecePath.pieceId'),
          pieceTitle: _string(
            piece['pieceTitle'],
            '$piecePath.pieceTitle',
            min: 1,
            max: 500,
          ),
          durationInSeconds: _integer(
            piece['durationInSeconds'],
            '$piecePath.durationInSeconds',
            min: 0,
            max: 86400,
          ),
          measuresWorked: _integer(
            piece['measuresWorked'],
            '$piecePath.measuresWorked',
            min: 0,
            max: 10000,
          ),
        ),
      );
    }

    return SessionRecord(
      id: _identifier(map['id'], '$path.id'),
      startTime: startTime,
      endTime: endTime,
      startUtcOffsetMinutes: _integer(
        map['startUtcOffsetMinutes'],
        '$path.startUtcOffsetMinutes',
        min: -840,
        max: 840,
      ),
      endUtcOffsetMinutes: _integer(
        map['endUtcOffsetMinutes'],
        '$path.endUtcOffsetMinutes',
        min: -840,
        max: 840,
      ),
      totalDurationInSeconds: _integer(
        map['totalDurationInSeconds'],
        '$path.totalDurationInSeconds',
        min: 0,
        max: 86400,
      ),
      completedExercises: completedExercises,
      rehearsedPieces: pieces,
      notes: _string(map['notes'], '$path.notes', max: 50000),
    );
  }

  static Map<String, dynamic> _object(dynamic value, String path) {
    if (value is! Map) {
      throw JournalBackupException('$path must be an object.');
    }
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw JournalBackupException('$path contains a non-string key.');
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  static List<dynamic> _list(dynamic value, String path, {required int max}) {
    if (value is! List) {
      throw JournalBackupException('$path must be an array.');
    }
    if (value.length > max) {
      throw JournalBackupException('$path contains too many items.');
    }
    return value;
  }

  static void _keys(Map<String, dynamic> value, String path, Set<String> keys) {
    final missing = keys.difference(value.keys.toSet());
    final unexpected = value.keys.toSet().difference(keys);
    if (missing.isNotEmpty) {
      throw JournalBackupException('$path is missing ${missing.first}.');
    }
    if (unexpected.isNotEmpty) {
      throw JournalBackupException(
        '$path contains unsupported ${unexpected.first}.',
      );
    }
  }

  static String _string(
    dynamic value,
    String path, {
    int min = 0,
    required int max,
  }) {
    if (value is! String || value.length < min || value.length > max) {
      throw JournalBackupException('$path has an invalid text value.');
    }
    if (min > 0 && value.trim().isEmpty) {
      throw JournalBackupException('$path cannot be blank.');
    }
    return value;
  }

  static String _identifier(dynamic value, String path) {
    final id = _string(value, path, min: 1, max: 200);
    if (RegExp(r'[\u0000-\u001F\u007F]').hasMatch(id)) {
      throw JournalBackupException('$path contains invalid characters.');
    }
    return id;
  }

  static int _integer(
    dynamic value,
    String path, {
    required int min,
    required int max,
  }) {
    if (value is! int || value < min || value > max) {
      throw JournalBackupException('$path must be between $min and $max.');
    }
    return value;
  }

  static DateTime _timestamp(dynamic value, String path) {
    final source = _string(value, path, min: 1, max: 40);
    if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(source)) {
      throw JournalBackupException('$path must include a UTC offset.');
    }
    final parsed = DateTime.tryParse(source);
    if (parsed == null) {
      throw JournalBackupException('$path is not a valid timestamp.');
    }
    return parsed.toUtc();
  }

  static bool _sameRoutineContent(Routine first, Routine second) =>
      jsonEncode(_routineContentJson(first)) ==
      jsonEncode(_routineContentJson(second));

  static bool _sameSessionContent(SessionRecord first, SessionRecord second) =>
      jsonEncode(_sessionContentJson(first)) ==
      jsonEncode(_sessionContentJson(second));

  static String? _availableConflictId({
    required String kind,
    required Map<String, dynamic> content,
    required Iterable<String> existingIds,
    required bool Function(String id) isSameContent,
  }) {
    final existing = existingIds.toSet();
    final digest = sha256.convert(utf8.encode(jsonEncode(content))).toString();
    final base = 'import_${kind}_${digest.substring(0, 32)}';
    var candidate = base;
    var suffix = 2;
    while (existing.contains(candidate)) {
      if (isSameContent(candidate)) return null;
      candidate = '${base}_$suffix';
      suffix++;
    }
    return candidate;
  }
}
