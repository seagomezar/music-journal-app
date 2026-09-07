import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flute/providers/localization_provider.dart';
import 'package:flute/providers/practice_provider.dart';
import 'package:flute/widgets/practice_tuner_card.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:flute/services/capture_lifecycle_service.dart';
import 'package:flute/services/pitch_tracking_service.dart';

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

void main() {
  Widget buildTestableWidget({required PracticeProvider practiceProvider}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LocalizationProvider(initialLocale: 'es'),
        ),
        ChangeNotifierProvider.value(value: practiceProvider),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('es'), Locale('en')],
        locale: Locale('es'),
        home: Scaffold(
          body: SingleChildScrollView(child: PracticeTunerCardTestWrapper()),
        ),
      ),
    );
  }

  testWidgets('PracticeTunerCard renders dynamic meter scale', (tester) async {
    final input = _FakeInput();
    final provider = PracticeProvider(
      pitchTrackingService: PitchTrackingService(
        audioInput: input,
        captureLifecycle: NoopAudioCaptureLifecycleController(),
      ),
    );

    await tester.pumpWidget(buildTestableWidget(practiceProvider: provider));
    await tester.pumpAndSettle();

    // Verify dynamic symbols are rendered
    expect(find.text('ppp'), findsOneWidget);
    expect(find.text('pp'), findsOneWidget);
    expect(find.text('p'), findsOneWidget);
    expect(find.text('mp'), findsOneWidget);
    expect(find.text('mf'), findsOneWidget);
    expect(find.text('f'), findsOneWidget);
    expect(find.text('ff'), findsOneWidget);
    expect(find.text('fff'), findsOneWidget);
    expect(find.text('- / 100'), findsOneWidget);

    provider.dispose();
  });
}

class PracticeTunerCardTestWrapper extends StatelessWidget {
  const PracticeTunerCardTestWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<PracticeProvider>(context);
    return PracticeTunerCard(practiceProvider: prov);
  }
}
