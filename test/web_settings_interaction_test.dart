import 'package:flute/providers/auth_provider.dart';
import 'package:flute/providers/history_provider.dart';
import 'package:flute/providers/localization_provider.dart';
import 'package:flute/providers/practice_provider.dart';
import 'package:flute/providers/routine_provider.dart';
import 'package:flute/screens/settings_screen.dart';
import 'package:flute/theme/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('compact web settings apply and persist a dark theme selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ThemeMode? persistedMode;
    final practice = PracticeProvider(
      persistThemeMode: (mode) async => persistedMode = mode,
    );
    addTearDown(practice.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: practice),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => HistoryProvider()),
          ChangeNotifierProvider(create: (_) => RoutineProvider()),
          ChangeNotifierProvider(
            create: (_) => LocalizationProvider(initialLocale: 'en'),
          ),
        ],
        child: Consumer<PracticeProvider>(
          builder: (context, preferences, _) => MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: preferences.themeMode,
            home: const SettingsScreen(),
          ),
        ),
      ),
    );

    final darkTheme = find.byKey(const ValueKey('theme_dark'));
    await tester.scrollUntilVisible(
      darkTheme,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(darkTheme);
    await tester.pumpAndSettle();
    await tester.tap(darkTheme);
    await tester.pumpAndSettle();

    expect(practice.themeMode, ThemeMode.dark);
    expect(persistedMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('Settings'))).brightness,
      Brightness.dark,
    );
  }, skip: !kIsWeb);
}
