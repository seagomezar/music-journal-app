class Exercise {
  final String id;
  final String name;
  final int targetBpm;
  final String articulation; // e.g., 'Staccato', 'Legato', 'Double Tonguing', 'Triple Tonguing'

  Exercise({
    required this.id,
    required this.name,
    required this.targetBpm,
    required this.articulation,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetBpm': targetBpm,
        'articulation': articulation,
      };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String,
        name: json['name'] as String,
        targetBpm: json['targetBpm'] as int? ?? 120,
        articulation: json['articulation'] as String? ?? 'Staccato',
      );

  Exercise copyWith({
    String? name,
    int? targetBpm,
    String? articulation,
  }) {
    return Exercise(
      id: id,
      name: name ?? this.name,
      targetBpm: targetBpm ?? this.targetBpm,
      articulation: articulation ?? this.articulation,
    );
  }
}
