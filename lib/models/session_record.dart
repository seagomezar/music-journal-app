import 'exercise.dart';

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

  factory SessionPieceRecord.fromJson(Map<String, dynamic> json) => SessionPieceRecord(
        pieceId: json['pieceId'] as String,
        pieceTitle: json['pieceTitle'] as String? ?? 'Untitled',
        durationInSeconds: json['durationInSeconds'] as int? ?? 0,
        measuresWorked: json['measuresWorked'] as int? ?? 0,
      );
}

class SessionRecord {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int totalDurationInSeconds;
  final List<Exercise> completedExercises;
  final List<SessionPieceRecord> rehearsedPieces;
  final String notes;
  final String? audioFilePath;

  SessionRecord({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.totalDurationInSeconds,
    required this.completedExercises,
    required this.rehearsedPieces,
    required this.notes,
    this.audioFilePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'totalDurationInSeconds': totalDurationInSeconds,
        'completedExercises': completedExercises.map((e) => e.toJson()).toList(),
        'rehearsedPieces': rehearsedPieces.map((p) => p.toJson()).toList(),
        'notes': notes,
        'audioFilePath': audioFilePath,
      };

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
        id: json['id'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: DateTime.parse(json['endTime'] as String),
        totalDurationInSeconds: json['totalDurationInSeconds'] as int? ?? 0,
        completedExercises: (json['completedExercises'] as List<dynamic>?)
                ?.map((e) => Exercise.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        rehearsedPieces: (json['rehearsedPieces'] as List<dynamic>?)
                ?.map((p) => SessionPieceRecord.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [],
        notes: json['notes'] as String? ?? '',
        audioFilePath: json['audioFilePath'] as String?,
      );
}
