import 'dart:async';
import 'dart:typed_data';

import 'package:flute/models/exercise.dart';
import 'package:flute/models/routine.dart';
import 'package:flute/providers/localization_provider.dart';
import 'package:flute/providers/practice_provider.dart';
import 'package:flute/services/capture_lifecycle_service.dart';
import 'package:flute/services/metronome_audio_service.dart';
import 'package:flute/services/pitch_tracking_service.dart';
import 'package:flute/widgets/practice_tuner_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'idle tuner persists A4 and explicit hide stops microphone capture',
    (tester) async {
      final input = _FakeInput();
      var persistedReference = 0;
      final provider = PracticeProvider(
        pitchTrackingService: PitchTrackingService(
          audioInput: input,
          captureLifecycle: NoopAudioCaptureLifecycleController(),
        ),
        persistTunerReference: (value) async => persistedReference = value,
      )..startSession(null);
      await _pumpTuner(tester, provider);

      expect(find.text('A4 = 440 Hz'), findsOneWidget);
      expect(find.text('Tune'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('increase_tuner_reference')));
      await tester.pumpAndSettle();
      expect(find.text('A4 = 441 Hz'), findsOneWidget);
      expect(persistedReference, 441);

      await tester.tap(find.byKey(const ValueKey('start_pitch_capture')));
      await tester.pumpAndSettle();
      expect(provider.isPitchListening, true);
      expect(find.text('Stop listening'), findsOneWidget);

      final hideTuner = find.byKey(const ValueKey('hide_tuner'));
      await tester.ensureVisible(hideTuner);
      await tester.tap(hideTuner);
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (provider.isTunerVisible && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pump();
      expect(provider.isPitchListening, false);
      expect(find.byKey(const ValueKey('show_tuner')), findsOneWidget);
      provider.dispose();
      await tester.pump();
    },
  );

  testWidgets('active exercise offers tracked scoring in Spanish', (
    tester,
  ) async {
    final input = _FakeInput();
    final exercise = Exercise(
      id: 'long-tones',
      name: 'Long tones',
      targetBpm: 60,
      articulation: 'Legato',
    );
    final provider =
        PracticeProvider(
          pitchTrackingService: PitchTrackingService(
            audioInput: input,
            captureLifecycle: NoopAudioCaptureLifecycleController(),
          ),
        )..startSession(
          Routine(
            id: 'warmup',
            title: 'Warmup',
            description: '',
            exercises: [exercise],
          ),
        );
    provider.startExercise(exercise.id, exercise.targetBpm);
    await _pumpTuner(
      tester,
      provider,
      locale: LocalizationProvider(initialLocale: 'es'),
    );

    expect(find.text('Afinador'), findsOneWidget);
    expect(find.text('Medir mi afinación'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('start_pitch_capture')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(provider.isTrackingPitch, true);
    expect(find.text('Detener medición'), findsOneWidget);
    expect(find.text('Esperando una nota estable…'), findsOneWidget);
    provider.dispose();
    await tester.pump();
  });

  testWidgets('tuner card toggles Focus mode (±25¢) and pure third markers', (
    tester,
  ) async {
    final input = _FakeInput();
    final provider = PracticeProvider(
      pitchTrackingService: PitchTrackingService(
        audioInput: input,
        captureLifecycle: NoopAudioCaptureLifecycleController(),
      ),
    )..startSession(null);
    await _pumpTuner(tester, provider);

    // Initial wide scale ±50¢
    expect(find.text('Wide (±50¢)'), findsOneWidget);
    expect(find.text('♭  −50¢'), findsOneWidget);
    expect(find.text('+50¢  ♯'), findsOneWidget);
    expect(find.text('▼ M3 (-13.7¢)'), findsOneWidget);
    expect(find.text('▼ m3 (+15.6¢)'), findsOneWidget);

    // Toggle to Focus mode
    await tester.tap(find.byKey(const ValueKey('toggle_tuner_focus_mode')));
    await tester.pumpAndSettle();
    expect(provider.isTunerFocusMode, true);
    expect(find.text('Focus (±25¢)'), findsOneWidget);
    expect(find.text('♭  −25¢'), findsOneWidget);
    expect(find.text('+25¢  ♯'), findsOneWidget);

    provider.dispose();
    await tester.pump();
  });

  testWidgets('tuner card toggles reference tone (Sound Out)', (tester) async {
    final input = _FakeInput();
    final fakeMetronome = _FakeMetronomeAudio();
    final provider = PracticeProvider(
      metronomeAudioController: fakeMetronome,
      pitchTrackingService: PitchTrackingService(
        audioInput: input,
        captureLifecycle: NoopAudioCaptureLifecycleController(),
      ),
    )..startSession(null);
    await _pumpTuner(tester, provider);

    final soundOutBtn = find.byKey(const ValueKey('toggle_sound_out'));
    expect(soundOutBtn, findsOneWidget);
    expect(fakeMetronome.playedHz, isNull);

    // Tap to play reference tone
    await tester.tap(soundOutBtn);
    await tester.pumpAndSettle();
    expect(fakeMetronome.playedHz, 440);

    // Tap to stop reference tone
    await tester.tap(soundOutBtn);
    await tester.pumpAndSettle();
    expect(fakeMetronome.isReferenceTonePlaying, false);

    provider.dispose();
    await tester.pump();
  });
}

class _FakeMetronomeAudio extends NoopMetronomeAudioController {
  int? playedHz;
  bool _tonePlaying = false;

  @override
  bool get isReferenceTonePlaying => _tonePlaying;

  @override
  Future<void> playReferenceTone(int hz) async {
    playedHz = hz;
    _tonePlaying = true;
  }

  @override
  Future<void> stopReferenceTone() async {
    _tonePlaying = false;
  }
}

Future<void> _pumpTuner(
  WidgetTester tester,
  PracticeProvider provider, {
  LocalizationProvider? locale,
}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: locale ?? LocalizationProvider(initialLocale: 'en'),
        ),
        ChangeNotifierProvider.value(value: provider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Consumer<PracticeProvider>(
              builder: (_, value, _) =>
                  PracticeTunerCard(practiceProvider: value),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FakeInput implements PitchAudioInput {
  final _controller = StreamController<Uint8List>();

  @override
  Future<void> dispose() => _controller.close();

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<Stream<Uint8List>> start() async => _controller.stream;

  @override
  Future<void> stop() async {}
}
