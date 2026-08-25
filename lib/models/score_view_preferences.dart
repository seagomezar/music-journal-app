enum ScoreLayoutMode { singlePage, continuous, halfPage, twoPage }

enum ScoreFitMode { fitPage, fitWidth }

enum ScoreOrientationMode { auto, portrait, landscape }

enum ScoreColorMode { normal, sepia, inverted }

enum AutoScrollPaceMode { speed, duration }

class ScoreViewPreferences {
  static const int currentSchemaVersion = 1;

  final String pieceId;
  final String sourcePath;
  final ScoreLayoutMode layoutMode;
  final ScoreFitMode fitMode;
  final ScoreOrientationMode orientationMode;
  final ScoreColorMode colorMode;
  final AutoScrollPaceMode autoScrollPaceMode;
  final int lastPage;
  final Map<int, double> halfPageSplitRatios;
  final bool firstPageOnRight;
  final double autoScrollViewportHeightsPerMinute;
  final int autoScrollDurationSeconds;
  final int schemaVersion;

  const ScoreViewPreferences({
    required this.pieceId,
    required this.sourcePath,
    this.layoutMode = ScoreLayoutMode.singlePage,
    this.fitMode = ScoreFitMode.fitPage,
    this.orientationMode = ScoreOrientationMode.auto,
    this.colorMode = ScoreColorMode.normal,
    this.autoScrollPaceMode = AutoScrollPaceMode.speed,
    this.lastPage = 1,
    this.halfPageSplitRatios = const {},
    this.firstPageOnRight = false,
    this.autoScrollViewportHeightsPerMinute = 1,
    this.autoScrollDurationSeconds = 300,
    this.schemaVersion = currentSchemaVersion,
  });

  factory ScoreViewPreferences.defaults({
    required String pieceId,
    required String sourcePath,
  }) => ScoreViewPreferences(pieceId: pieceId, sourcePath: sourcePath);

  double splitRatioForPage(int pageNumber) =>
      (halfPageSplitRatios[pageNumber] ?? 0.5).clamp(0.3, 0.7);

  ScoreViewPreferences copyWith({
    ScoreLayoutMode? layoutMode,
    ScoreFitMode? fitMode,
    ScoreOrientationMode? orientationMode,
    ScoreColorMode? colorMode,
    AutoScrollPaceMode? autoScrollPaceMode,
    int? lastPage,
    Map<int, double>? halfPageSplitRatios,
    bool? firstPageOnRight,
    double? autoScrollViewportHeightsPerMinute,
    int? autoScrollDurationSeconds,
  }) {
    return ScoreViewPreferences(
      pieceId: pieceId,
      sourcePath: sourcePath,
      layoutMode: layoutMode ?? this.layoutMode,
      fitMode: fitMode ?? this.fitMode,
      orientationMode: orientationMode ?? this.orientationMode,
      colorMode: colorMode ?? this.colorMode,
      autoScrollPaceMode: autoScrollPaceMode ?? this.autoScrollPaceMode,
      lastPage: lastPage ?? this.lastPage,
      halfPageSplitRatios: halfPageSplitRatios ?? this.halfPageSplitRatios,
      firstPageOnRight: firstPageOnRight ?? this.firstPageOnRight,
      autoScrollViewportHeightsPerMinute:
          autoScrollViewportHeightsPerMinute ??
          this.autoScrollViewportHeightsPerMinute,
      autoScrollDurationSeconds:
          autoScrollDurationSeconds ?? this.autoScrollDurationSeconds,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'pieceId': pieceId,
    'sourcePath': sourcePath,
    'layoutMode': layoutMode.name,
    'fitMode': fitMode.name,
    'orientationMode': orientationMode.name,
    'colorMode': colorMode.name,
    'autoScrollPaceMode': autoScrollPaceMode.name,
    'lastPage': lastPage,
    'halfPageSplitRatios': halfPageSplitRatios.map(
      (page, ratio) => MapEntry(page.toString(), ratio),
    ),
    'firstPageOnRight': firstPageOnRight,
    'autoScrollViewportHeightsPerMinute': autoScrollViewportHeightsPerMinute,
    'autoScrollDurationSeconds': autoScrollDurationSeconds,
  };

  factory ScoreViewPreferences.fromJson(Map<String, dynamic> json) {
    final splitRatios = <int, double>{};
    final rawSplits = Map<String, dynamic>.from(
      json['halfPageSplitRatios'] as Map? ?? const {},
    );
    for (final entry in rawSplits.entries) {
      final page = int.tryParse(entry.key);
      if (page != null && page > 0 && entry.value is num) {
        splitRatios[page] = (entry.value as num).toDouble().clamp(0.3, 0.7);
      }
    }

    return ScoreViewPreferences(
      pieceId: json['pieceId'] as String? ?? '',
      sourcePath: json['sourcePath'] as String? ?? '',
      layoutMode: _enumByName(
        ScoreLayoutMode.values,
        json['layoutMode'],
        ScoreLayoutMode.singlePage,
      ),
      fitMode: _enumByName(
        ScoreFitMode.values,
        json['fitMode'],
        ScoreFitMode.fitPage,
      ),
      orientationMode: _enumByName(
        ScoreOrientationMode.values,
        json['orientationMode'],
        ScoreOrientationMode.auto,
      ),
      colorMode: _enumByName(
        ScoreColorMode.values,
        json['colorMode'],
        ScoreColorMode.normal,
      ),
      autoScrollPaceMode: _enumByName(
        AutoScrollPaceMode.values,
        json['autoScrollPaceMode'],
        AutoScrollPaceMode.speed,
      ),
      lastPage: (json['lastPage'] as num? ?? 1).toInt().clamp(1, 100000),
      halfPageSplitRatios: splitRatios,
      firstPageOnRight: json['firstPageOnRight'] as bool? ?? false,
      autoScrollViewportHeightsPerMinute:
          (json['autoScrollViewportHeightsPerMinute'] as num? ?? 1)
              .toDouble()
              .clamp(0.25, 3.0),
      autoScrollDurationSeconds:
          (json['autoScrollDurationSeconds'] as num? ?? 300).toInt().clamp(
            60,
            14400,
          ),
      schemaVersion: json['schemaVersion'] as int? ?? currentSchemaVersion,
    );
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  return values.cast<T>().firstWhere(
    (value) => value.name == name,
    orElse: () => fallback,
  );
}
