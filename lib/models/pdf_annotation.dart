class PdfAnnotationPoint {
  final double x;
  final double y;

  const PdfAnnotationPoint({required this.x, required this.y});

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory PdfAnnotationPoint.fromJson(Map<String, dynamic> json) {
    return PdfAnnotationPoint(
      x: (json['x'] as num).toDouble().clamp(0.0, 1.0),
      y: (json['y'] as num).toDouble().clamp(0.0, 1.0),
    );
  }
}

class PdfInkStroke {
  static const double defaultWidthInPdfPoints = 3.5;

  final List<PdfAnnotationPoint> points;
  final int colorArgb;
  final double widthInPdfPoints;

  const PdfInkStroke({
    required this.points,
    required this.colorArgb,
    this.widthInPdfPoints = defaultWidthInPdfPoints,
  });

  PdfInkStroke copyWith({List<PdfAnnotationPoint>? points}) {
    return PdfInkStroke(
      points: points ?? this.points,
      colorArgb: colorArgb,
      widthInPdfPoints: widthInPdfPoints,
    );
  }

  Map<String, dynamic> toJson() => {
    'points': points.map((point) => point.toJson()).toList(),
    'colorArgb': colorArgb,
    'widthInPdfPoints': widthInPdfPoints,
  };

  factory PdfInkStroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? const [];
    return PdfInkStroke(
      points: rawPoints
          .map(
            (point) => PdfAnnotationPoint.fromJson(
              Map<String, dynamic>.from(point as Map),
            ),
          )
          .toList(growable: false),
      colorArgb: json['colorArgb'] as int? ?? 0xffd39b2a,
      widthInPdfPoints:
          (json['widthInPdfPoints'] as num?)?.toDouble() ??
          defaultWidthInPdfPoints,
    );
  }
}

class PdfAnnotationDocument {
  static const int currentSchemaVersion = 1;

  final String pieceId;
  final String sourcePath;
  final Map<int, List<PdfInkStroke>> pages;
  final int schemaVersion;

  const PdfAnnotationDocument({
    required this.pieceId,
    required this.sourcePath,
    required this.pages,
    this.schemaVersion = currentSchemaVersion,
  });

  factory PdfAnnotationDocument.empty({
    required String pieceId,
    required String sourcePath,
  }) {
    return PdfAnnotationDocument(
      pieceId: pieceId,
      sourcePath: sourcePath,
      pages: const {},
    );
  }

  bool get hasAnnotations => pages.values.any((strokes) => strokes.isNotEmpty);

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'pieceId': pieceId,
    'sourcePath': sourcePath,
    'pages': pages.map(
      (pageNumber, strokes) => MapEntry(
        pageNumber.toString(),
        strokes.map((stroke) => stroke.toJson()).toList(),
      ),
    ),
  };

  factory PdfAnnotationDocument.fromJson(Map<String, dynamic> json) {
    final rawPages = Map<String, dynamic>.from(
      json['pages'] as Map? ?? const <String, dynamic>{},
    );
    final pages = <int, List<PdfInkStroke>>{};
    for (final entry in rawPages.entries) {
      final pageNumber = int.tryParse(entry.key);
      if (pageNumber == null || pageNumber < 1 || entry.value is! List) {
        continue;
      }
      final strokes = <PdfInkStroke>[];
      for (final rawStroke in entry.value as List<dynamic>) {
        try {
          final stroke = PdfInkStroke.fromJson(
            Map<String, dynamic>.from(rawStroke as Map),
          );
          if (stroke.points.isNotEmpty && stroke.widthInPdfPoints > 0) {
            strokes.add(stroke);
          }
        } catch (_) {
          // Ignore a malformed stroke without discarding the rest of the PDF.
        }
      }
      if (strokes.isNotEmpty) pages[pageNumber] = strokes;
    }

    return PdfAnnotationDocument(
      pieceId: json['pieceId'] as String? ?? '',
      sourcePath: json['sourcePath'] as String? ?? '',
      pages: pages,
      schemaVersion: json['schemaVersion'] as int? ?? currentSchemaVersion,
    );
  }
}
