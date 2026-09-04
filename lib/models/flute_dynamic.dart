import 'package:flutter/material.dart';

/// Musical dynamic markings calibrated for the concert flute based on
/// modern flute acoustics and pedagogy (Marcel Moyse, Michel Debost, Fletcher & Rossing).
///
/// At a typical music stand distance (~40-60 cm from the embouchure to the device mic),
/// the flute produces an effective dynamic range of approximately 30-35 dB SPL above ambient noise.
enum FluteDynamic {
  ambient,
  ppp,
  pp,
  p,
  mp,
  mf,
  f,
  ff,
  fff;

  /// Standard musical notation symbol.
  String get symbol {
    switch (this) {
      case FluteDynamic.ambient:
        return '—';
      case FluteDynamic.ppp:
        return 'ppp';
      case FluteDynamic.pp:
        return 'pp';
      case FluteDynamic.p:
        return 'p';
      case FluteDynamic.mp:
        return 'mp';
      case FluteDynamic.mf:
        return 'mf';
      case FluteDynamic.f:
        return 'f';
      case FluteDynamic.ff:
        return 'ff';
      case FluteDynamic.fff:
        return 'fff';
    }
  }

  /// Localization key for full descriptive title.
  String get localizationKey {
    switch (this) {
      case FluteDynamic.ambient:
        return 'dynamic_ambient';
      case FluteDynamic.ppp:
        return 'dynamic_ppp';
      case FluteDynamic.pp:
        return 'dynamic_pp';
      case FluteDynamic.p:
        return 'dynamic_p';
      case FluteDynamic.mp:
        return 'dynamic_mp';
      case FluteDynamic.mf:
        return 'dynamic_mf';
      case FluteDynamic.f:
        return 'dynamic_f';
      case FluteDynamic.ff:
        return 'dynamic_ff';
      case FluteDynamic.fff:
        return 'dynamic_fff';
    }
  }

  /// Lower bound in decibels (dB SPL equivalent).
  double get minDb {
    switch (this) {
      case FluteDynamic.ambient:
        return 0.0;
      case FluteDynamic.ppp:
        return 48.0;
      case FluteDynamic.pp:
        return 56.0;
      case FluteDynamic.p:
        return 63.0;
      case FluteDynamic.mp:
        return 70.0;
      case FluteDynamic.mf:
        return 76.0;
      case FluteDynamic.f:
        return 82.0;
      case FluteDynamic.ff:
        return 88.0;
      case FluteDynamic.fff:
        return 94.0;
    }
  }

  /// Upper bound in decibels (dB SPL equivalent).
  double get maxDb {
    switch (this) {
      case FluteDynamic.ambient:
        return 48.0;
      case FluteDynamic.ppp:
        return 56.0;
      case FluteDynamic.pp:
        return 63.0;
      case FluteDynamic.p:
        return 70.0;
      case FluteDynamic.mp:
        return 76.0;
      case FluteDynamic.mf:
        return 82.0;
      case FluteDynamic.f:
        return 88.0;
      case FluteDynamic.ff:
        return 94.0;
      case FluteDynamic.fff:
        return 120.0;
    }
  }

  /// Color associated with each dynamic level in the practice UI.
  Color get color {
    switch (this) {
      case FluteDynamic.ambient:
        return const Color(0xFF9E9E9E); // Neutral grey
      case FluteDynamic.ppp:
        return const Color(0xFF5C9DED); // Soft sky blue
      case FluteDynamic.pp:
        return const Color(0xFF2BB0D7); // Cyan
      case FluteDynamic.p:
        return const Color(0xFF2EB7A3); // Teal
      case FluteDynamic.mp:
        return const Color(0xFF67B576); // Sage green
      case FluteDynamic.mf:
        return const Color(0xFFE2B734); // Golden brass
      case FluteDynamic.f:
        return const Color(0xFFE88A2E); // Warm orange
      case FluteDynamic.ff:
        return const Color(0xFFE5583B); // Bright coral/red
      case FluteDynamic.fff:
        return const Color(0xFFC72C5B); // Intense magenta-red
    }
  }

  /// Classifies a sound pressure level (in dB) into the flute dynamic scale.
  static FluteDynamic fromDecibels(double db) {
    if (db < 48.0) return FluteDynamic.ambient;
    if (db < 56.0) return FluteDynamic.ppp;
    if (db < 63.0) return FluteDynamic.pp;
    if (db < 70.0) return FluteDynamic.p;
    if (db < 76.0) return FluteDynamic.mp;
    if (db < 82.0) return FluteDynamic.mf;
    if (db < 88.0) return FluteDynamic.f;
    if (db < 94.0) return FluteDynamic.ff;
    return FluteDynamic.fff;
  }
}

/// Real-time dynamic and sound pressure level measurement.
@immutable
class FluteDynamicReading {
  const FluteDynamicReading({
    required this.decibels,
    required this.smoothedDecibels,
    required this.peakDecibels,
    required this.dynamic,
  });

  /// Instantaneous sound pressure level in dB.
  final double decibels;

  /// Temporally smoothed sound pressure level (asymmetric exponential moving average).
  final double smoothedDecibels;

  /// Retained peak level within the decay window (for attack/accent awareness).
  final double peakDecibels;

  /// Current musical dynamic category.
  final FluteDynamic dynamic;

  /// Whether the flute sound is actively audible above room background noise.
  bool get isAudible => dynamic != FluteDynamic.ambient;

  /// Normalized progress [0.0, 1.0] across the practical flute scale (40 dB to 98 dB).
  double get normalizedLevel {
    const minScale = 40.0;
    const maxScale = 98.0;
    return ((smoothedDecibels - minScale) / (maxScale - minScale)).clamp(0.0, 1.0);
  }

  /// Normalized progress [0.0, 1.0] for the peak indicator.
  double get normalizedPeak {
    const minScale = 40.0;
    const maxScale = 98.0;
    return ((peakDecibels - minScale) / (maxScale - minScale)).clamp(0.0, 1.0);
  }
}
