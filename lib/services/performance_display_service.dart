import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../models/score_view_preferences.dart';

abstract interface class PerformanceDisplayController {
  Future<void> applyOrientation(ScoreOrientationMode mode);
  Future<void> applyBrightness(double brightness);
  Future<void> enterFullscreen();
  Future<void> leaveFullscreen();
  Future<void> restore();
}

class SystemPerformanceDisplayController
    implements PerformanceDisplayController {
  final ScreenBrightness _brightness;

  SystemPerformanceDisplayController({ScreenBrightness? brightness})
    : _brightness = brightness ?? ScreenBrightness.instance;

  @override
  Future<void> applyOrientation(ScoreOrientationMode mode) {
    final orientations = switch (mode) {
      ScoreOrientationMode.portrait => const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
      ScoreOrientationMode.landscape => const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      ScoreOrientationMode.auto => const <DeviceOrientation>[],
    };
    return SystemChrome.setPreferredOrientations(orientations);
  }

  @override
  Future<void> applyBrightness(double brightness) {
    return _brightness.setApplicationScreenBrightness(
      brightness.clamp(0.1, 1.0),
    );
  }

  @override
  Future<void> enterFullscreen() {
    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Future<void> leaveFullscreen() {
    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Future<void> restore() async {
    await leaveFullscreen();
    await SystemChrome.setPreferredOrientations(const []);
    await _brightness.resetApplicationScreenBrightness();
  }
}
