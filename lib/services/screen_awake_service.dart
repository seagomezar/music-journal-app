import 'dart:async';

import 'package:wakelock_plus/wakelock_plus.dart';

abstract interface class ScreenAwakeController {
  Future<void> setEnabled(bool enabled);
}

class WakelockScreenAwakeController implements ScreenAwakeController {
  @override
  Future<void> setEnabled(bool enabled) {
    return WakelockPlus.toggle(enable: enabled);
  }
}

class NoopScreenAwakeController implements ScreenAwakeController {
  @override
  Future<void> setEnabled(bool enabled) async {}
}

class ScreenAwakeCoordinator implements ScreenAwakeController {
  static final ScreenAwakeCoordinator instance = ScreenAwakeCoordinator(
    WakelockScreenAwakeController(),
  );

  final ScreenAwakeController _platform;
  final Set<String> _activeReasons = {};
  Future<void> _updateQueue = Future.value();
  bool _platformEnabled = false;

  ScreenAwakeCoordinator(this._platform);

  @override
  Future<void> setEnabled(bool enabled) {
    return setReasonEnabled('practice', enabled);
  }

  Future<void> setPerformanceEnabled(bool enabled) {
    return setReasonEnabled('performance', enabled);
  }

  Future<void> setReasonEnabled(String reason, bool enabled) {
    if (enabled) {
      _activeReasons.add(reason);
    } else {
      _activeReasons.remove(reason);
    }
    final shouldEnable = _activeReasons.isNotEmpty;
    final operation = _updateQueue.then((_) async {
      if (shouldEnable == _platformEnabled) return;
      await _platform.setEnabled(shouldEnable);
      _platformEnabled = shouldEnable;
    });
    _updateQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}
