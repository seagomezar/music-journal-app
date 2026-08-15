import 'package:flutter/foundation.dart';

@immutable
class PitchReading {
  const PitchReading({
    required this.frequencyHz,
    required this.noteName,
    required this.octave,
    required this.cents,
    required this.clarity,
    required this.isStable,
    required this.isOnPitch,
  });

  final double frequencyHz;
  final String noteName;
  final int octave;
  final double cents;
  final double clarity;
  final bool isStable;
  final bool isOnPitch;

  String get displayNote => '$noteName$octave';
}

@immutable
class ExercisePitchSummary {
  const ExercisePitchSummary({
    required this.inTuneMilliseconds,
    required this.analyzedMilliseconds,
    required this.trackingMilliseconds,
    required this.referenceHz,
    required this.toleranceCents,
  });

  final int inTuneMilliseconds;
  final int analyzedMilliseconds;
  final int trackingMilliseconds;
  final int referenceHz;
  final int toleranceCents;

  bool get hasEnoughData => analyzedMilliseconds >= 2000;

  double get onPitchPercentage => analyzedMilliseconds == 0
      ? 0
      : inTuneMilliseconds * 100 / analyzedMilliseconds;

  Map<String, dynamic> toJson() => {
    'inTuneMilliseconds': inTuneMilliseconds,
    'analyzedMilliseconds': analyzedMilliseconds,
    'trackingMilliseconds': trackingMilliseconds,
    'referenceHz': referenceHz,
    'toleranceCents': toleranceCents,
  };

  factory ExercisePitchSummary.fromJson(Map<String, dynamic> json) {
    final analyzed = (json['analyzedMilliseconds'] as num? ?? 0).toInt().clamp(
      0,
      86400000,
    );
    return ExercisePitchSummary(
      inTuneMilliseconds: (json['inTuneMilliseconds'] as num? ?? 0)
          .toInt()
          .clamp(0, analyzed),
      analyzedMilliseconds: analyzed,
      trackingMilliseconds: (json['trackingMilliseconds'] as num? ?? analyzed)
          .toInt()
          .clamp(analyzed, 86400000),
      referenceHz: (json['referenceHz'] as num? ?? 440).toInt().clamp(420, 460),
      toleranceCents: (json['toleranceCents'] as num? ?? 10).toInt().clamp(
        5,
        20,
      ),
    );
  }
}
