import 'dart:async';

import 'package:flute/services/metronome_audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native metronome starts and applies the latest tempo', (
    tester,
  ) async {
    final metronome = MetronomeAudioService();
    await metronome.initialize();

    await metronome.start(bpm: 120, volume: 0);
    await tester.pump(const Duration(milliseconds: 250));
    final initial = metronome.clockSnapshot;
    expect(initial, isNotNull);
    expect(initial!.bpm, 120);

    unawaited(metronome.setTempo(90));
    unawaited(metronome.setTempo(150));
    await metronome.setTempo(180);
    await tester.pump(const Duration(seconds: 2));

    final updated = metronome.clockSnapshot;
    expect(updated, isNotNull);
    expect(updated!.bpm, 180);
    expect(updated.beatIndex, greaterThan(initial.beatIndex));

    await metronome.setVolume(0.5);
    await metronome.setVolume(0);
    await metronome.stop();
    expect(metronome.clockSnapshot, isNull);
  });
}
