const _musicSheetPieceIdNotProvided = Object();

class Exercise {
  final String id;
  final String name;
  final int targetBpm;
  final String
  articulation; // e.g., 'Staccato', 'Legato', 'Double Tonguing', 'Triple Tonguing'
  final String? musicSheetPieceId;

  Exercise({
    required this.id,
    required this.name,
    required this.targetBpm,
    required this.articulation,
    this.musicSheetPieceId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'targetBpm': targetBpm,
    'articulation': articulation,
    'musicSheetPieceId': musicSheetPieceId,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] as String,
    name: json['name'] as String,
    targetBpm: (json['targetBpm'] as num? ?? 120)
        .toInt()
        .clamp(40, 240)
        .toInt(),
    articulation: json['articulation'] as String? ?? 'Staccato',
    musicSheetPieceId: json['musicSheetPieceId'] as String?,
  );

  Exercise copyWith({
    String? name,
    int? targetBpm,
    String? articulation,
    Object? musicSheetPieceId = _musicSheetPieceIdNotProvided,
  }) {
    return Exercise(
      id: id,
      name: name ?? this.name,
      targetBpm: targetBpm ?? this.targetBpm,
      articulation: articulation ?? this.articulation,
      musicSheetPieceId:
          identical(musicSheetPieceId, _musicSheetPieceIdNotProvided)
          ? this.musicSheetPieceId
          : musicSheetPieceId as String?,
    );
  }
}
