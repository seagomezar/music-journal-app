import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flute/services/capture_lifecycle_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flute/capture_lifecycle');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('serializes and balances overlapping capture lifecycles', () async {
    final controller = PlatformAudioCaptureLifecycleController();

    await Future.wait([
      controller.begin(AudioCaptureKind.recording),
      controller.begin(AudioCaptureKind.pitchTracking),
      controller.end(AudioCaptureKind.recording),
      controller.end(AudioCaptureKind.recording),
      controller.end(AudioCaptureKind.pitchTracking),
    ]);

    expect(calls.map((call) => call.method), ['begin', 'begin', 'end', 'end']);
    expect(calls[0].arguments['kind'], 'recording');
    expect(calls[1].arguments['kind'], 'pitchTracking');
    expect(calls[2].arguments['kind'], 'recording');
    expect(calls[3].arguments['kind'], 'pitchTracking');
  });
}
