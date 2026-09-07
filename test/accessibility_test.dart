import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flute/providers/localization_provider.dart';
import 'package:flute/providers/practice_provider.dart';
import 'package:flute/widgets/practice_tuner_card.dart';
import 'package:flute/theme/app_theme.dart';

void main() {
  for (final locale in ['en', 'es']) {
    testWidgets('tuner supports 200% text at phone width in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final practice = PracticeProvider();
      addTearDown(practice.dispose);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LocalizationProvider(initialLocale: locale),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: PracticeTunerCard(practiceProvider: practice),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
    });
  }
}
