import 'exercise.dart';
import 'pitch_tracking.dart';
import 'session_recording.dart';

class SessionExerciseRecord {
  final Exercise exercise;
  final int durationInSeconds;
  final int practicedBpm;
  final ExercisePitchSummary? pitchSummary;

  SessionExerciseRecord({
    required this.exercise,
    required this.durationInSeconds,
    required this.practicedBpm,
    this.pitchSummary,
  });

  Map<String, dynamic> toJson() => {
    'exercise': exercise.toJson(),
    'durationInSeconds': durationInSeconds,
    'practicedBpm': practicedBpm,
    'pitchSummary': pitchSummary?.toJson(),
  };

  factory SessionExerciseRecord.fromJson(Map<String, dynamic> json) =>
      SessionExerciseRecord(
        exercise: Exercise.fromJson(json['exercise'] as Map<String, dynamic>),
        durationInSeconds: (json['durationInSeconds'] as num? ?? 0)
            .toInt()
            .clamp(0, 86400)
            .toInt(),
        practicedBpm: (json['practicedBpm'] as num? ?? 120)
            .toInt()
            .clamp(40, 240)
            .toInt(),
        pitchSummary: json['pitchSummary'] is Map
            ? ExercisePitchSummary.fromJson(
                Map<String, dynamic>.from(json['pitchSummary'] as Map),
              )
            : null,
      );
}

class SessionPieceRecord {
  final String pieceId;
  final String pieceTitle;
  final int durationInSeconds;
  final int measuresWorked;

  SessionPieceRecord({
    required this.pieceId,
    required this.pieceTitle,
    required this.durationInSeconds,
    required this.measuresWorked,
  });

  Map<String, dynamic> toJson() => {
    'pieceId': pieceId,
    'pieceTitle': pieceTitle,
    'durationInSeconds': durationInSeconds,
    'measuresWorked': measuresWorked,
  };

  factory SessionPieceRecord.fromJson(Map<String, dynamic> json) =>
      SessionPieceRecord(
        pieceId: json['pieceId'] as String,
        pieceTitle: json['pieceTitle'] as String? ?? 'Untitled',
        durationInSeconds: (json['durationInSeconds'] as num? ?? 0)
            .toInt()
            .clamp(0, 86400)
            .toInt(),
        measuresWorked: (json['measuresWorked'] as num? ?? 0)
            .toInt()
            .clamp(0, 10000)
            .toInt(),
      );
}

class SessionRecord {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int startUtcOffsetMinutes;
  final int endUtcOffsetMinutes;
  final int totalDurationInSeconds;
  final List<Exercise> completedExercises;
  final List<SessionExerciseRecord> exerciseResults;
  final List<SessionPieceRecord> rehearsedPieces;
  final String notes;
  final List<SessionRecording> recordings;

  SessionRecord({
    required this.id,
    required this.startTime,
    required this.endTime,
    int? startUtcOffsetMinutes,
    int? endUtcOffsetMinutes,
    required this.totalDurationInSeconds,
    required this.completedExercises,
    this.exerciseResults = const [],
    required this.rehearsedPieces,
    required this.notes,
    List<SessionRecording> recordings = const [],
    String? audioFilePath,
  }) : startUtcOffsetMinutes =
           startUtcOffsetMinutes ?? startTime.timeZoneOffset.inMinutes,
       endUtcOffsetMinutes =
           endUtcOffsetMinutes ?? endTime.timeZoneOffset.inMinutes,
       recordings = List.unmodifiable(
         recordings.isNotEmpty
             ? recordings
             : audioFilePath == null
             ? const <SessionRecording>[]
             : [
                 SessionRecording(
                   id: 'legacy_$id',
                   name: 'Recording 1',
                   createdAt: startTime,
                   storagePath: audioFilePath,
                 ),
               ],
       );

  DateTime get localStartTime => _wallTime(startTime, startUtcOffsetMinutes);
  DateTime get localEndTime => _wallTime(endTime, endUtcOffsetMinutes);

  static DateTime _wallTime(DateTime instant, int offsetMinutes) {
    final shifted = instant.toUtc().add(Duration(minutes: offsetMinutes));
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
      shifted.microsecond,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startTime': startTime.toUtc().toIso8601String(),
    'endTime': endTime.toUtc().toIso8601String(),
    'startUtcOffsetMinutes': startUtcOffsetMinutes,
    'endUtcOffsetMinutes': endUtcOffsetMinutes,
    'totalDurationInSeconds': totalDurationInSeconds,
    'completedExercises': completedExercises.map((e) => e.toJson()).toList(),
    'exerciseResults': exerciseResults
        .map((result) => result.toJson())
        .toList(),
    'rehearsedPieces': rehearsedPieces.map((p) => p.toJson()).toList(),
    'notes': notes,
    'recordings': recordings.map((recording) => recording.toJson()).toList(),
  };

  String? get audioFilePath =>
      recordings.isEmpty ? null : recordings.first.storagePath;

  SessionRecord copyWith({List<SessionRecording>? recordings}) {
    return SessionRecord(
      id: id,
      startTime: startTime,
      endTime: endTime,
      startUtcOffsetMinutes: startUtcOffsetMinutes,
      endUtcOffsetMinutes: endUtcOffsetMinutes,
      totalDurationInSeconds: totalDurationInSeconds,
      completedExercises: completedExercises,
      exerciseResults: exerciseResults,
      rehearsedPieces: rehearsedPieces,
      notes: notes,
      recordings: recordings ?? this.recordings,
    );
  }

  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    final startTime = DateTime.parse(json['startTime'] as String);
    final endTime = DateTime.parse(json['endTime'] as String);
    return SessionRecord(
      id: json['id'] as String,
      startTime: startTime,
      endTime: endTime,
      startUtcOffsetMinutes:
          (json['startUtcOffsetMinutes'] as num?)?.toInt() ??
          startTime.timeZoneOffset.inMinutes,
      endUtcOffsetMinutes:
          (json['endUtcOffsetMinutes'] as num?)?.toInt() ??
          endTime.timeZoneOffset.inMinutes,
      totalDurationInSeconds: (json['totalDurationInSeconds'] as num? ?? 0)
          .toInt()
          .clamp(0, 86400)
          .toInt(),
      completedExercises:
          (json['completedExercises'] as List<dynamic>?)
              ?.map((e) => Exercise.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      exerciseResults:
          (json['exerciseResults'] as List<dynamic>?)
              ?.map(
                (result) => SessionExerciseRecord.fromJson(
                  result as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      rehearsedPieces:
          (json['rehearsedPieces'] as List<dynamic>?)
              ?.map(
                (p) => SessionPieceRecord.fromJson(p as Map<String, dynamic>),
              )
              .toList() ??
          [],
      notes: json['notes'] as String? ?? '',
      recordings:
          (json['recordings'] as List<dynamic>?)
              ?.map(
                (recording) => SessionRecording.fromJson(
                  recording as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const [],
      audioFilePath: json['audioFilePath'] as String?,
    );
  }
}
