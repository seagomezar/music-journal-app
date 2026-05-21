class Piece {
  final String id;
  final String title;
  final String composer;
  final String? pdfPath; // Local path or file name
  final int targetBpm;
  final int measuresTotal;
  final int measuresCompleted;
  final String notes;

  Piece({
    required this.id,
    required this.title,
    required this.composer,
    this.pdfPath,
    required this.targetBpm,
    this.measuresTotal = 0,
    this.measuresCompleted = 0,
    this.notes = '',
  });

  double get progressPercentage {
    if (measuresTotal <= 0) return 0.0;
    return (measuresCompleted / measuresTotal).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'composer': composer,
        'pdfPath': pdfPath,
        'targetBpm': targetBpm,
        'measuresTotal': measuresTotal,
        'measuresCompleted': measuresCompleted,
        'notes': notes,
      };

  factory Piece.fromJson(Map<String, dynamic> json) => Piece(
        id: json['id'] as String,
        title: json['title'] as String,
        composer: json['composer'] as String? ?? 'Unknown',
        pdfPath: json['pdfPath'] as String?,
        targetBpm: json['targetBpm'] as int? ?? 120,
        measuresTotal: json['measuresTotal'] as int? ?? 0,
        measuresCompleted: json['measuresCompleted'] as int? ?? 0,
        notes: json['notes'] as String? ?? '',
      );

  Piece copyWith({
    String? title,
    String? composer,
    String? pdfPath,
    int? targetBpm,
    int? measuresTotal,
    int? measuresCompleted,
    String? notes,
  }) {
    return Piece(
      id: id,
      title: title ?? this.title,
      composer: composer ?? this.composer,
      pdfPath: pdfPath ?? this.pdfPath,
      targetBpm: targetBpm ?? this.targetBpm,
      measuresTotal: measuresTotal ?? this.measuresTotal,
      measuresCompleted: measuresCompleted ?? this.measuresCompleted,
      notes: notes ?? this.notes,
    );
  }
}
