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
  final Map<AudioCaptureKind, int> _activeCaptures = {};
  Future<void> _operationQueue = Future<void>.value();

  @override
  Future<void> begin(AudioCaptureKind kind) => _enqueue(() async {
    await _invoke('begin', kind);
    _activeCaptures[kind] = (_activeCaptures[kind] ?? 0) + 1;
  });

  @override
  Future<void> end(AudioCaptureKind kind) => _enqueue(() async {
    final count = _activeCaptures[kind] ?? 0;
    if (count == 0) return;
    await _invoke('end', kind);
    if (count == 1) {
      _activeCaptures.remove(kind);
    } else {
      _activeCaptures[kind] = count - 1;
    }
  });

  Future<void> _invoke(String method, AudioCaptureKind kind) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>(method, {'kind': kind.name});
    } on MissingPluginException {
      // Desktop targets do not currently provide a background capture host.
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _operationQueue.then((_) => operation());
    _operationQueue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }
}

class NoopAudioCaptureLifecycleController
    implements AudioCaptureLifecycleController {
  @override
  Future<void> begin(AudioCaptureKind kind) async {}

  @override
  Future<void> end(AudioCaptureKind kind) async {}
}
