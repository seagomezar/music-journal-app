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
