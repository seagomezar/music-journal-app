import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AudioCaptureKind { recording, pitchTracking }

abstract interface class AudioCaptureLifecycleController {
  Future<void> begin(AudioCaptureKind kind);
  Future<void> end(AudioCaptureKind kind);
}

class PlatformAudioCaptureLifecycleController
    implements AudioCaptureLifecycleController {
  static const _channel = MethodChannel('flute/capture_lifecycle');

  @override
  Future<void> begin(AudioCaptureKind kind) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('begin', {'kind': kind.name});
    } on MissingPluginException {
      // Desktop targets do not currently provide a background capture host.
    }
  }

  @override
  Future<void> end(AudioCaptureKind kind) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('end', {'kind': kind.name});
    } on MissingPluginException {
      // Desktop targets do not currently provide a background capture host.
    }
  }
}

class NoopAudioCaptureLifecycleController
    implements AudioCaptureLifecycleController {
  @override
  Future<void> begin(AudioCaptureKind kind) async {}

  @override
  Future<void> end(AudioCaptureKind kind) async {}
}
