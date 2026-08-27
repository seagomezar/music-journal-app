import 'package:flute/providers/history_provider.dart';
import 'package:flute/providers/localization_provider.dart';
import 'package:flute/screens/calendar_history_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

class _EmptyHistoryProvider extends HistoryProvider {
  @override
  Future<void> loadSessions() async {}
}

void main() {
  testWidgets('history calendar fits a compact iPhone viewport', (
    tester,
  ) async {
    await initializeDateFormatting('en');
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<HistoryProvider>(
            create: (_) => _EmptyHistoryProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => LocalizationProvider(initialLocale: 'en'),
          ),
        ],
        child: const MaterialApp(home: CalendarHistoryView()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Practice History'), findsOneWidget);
  });

  testWidgets('history exposes calendar and sessions in phone landscape', (
    tester,
  ) async {
    await initializeDateFormatting('en');
    tester.view.physicalSize = const Size(667, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<HistoryProvider>(
            create: (_) => _EmptyHistoryProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => LocalizationProvider(initialLocale: 'en'),
          ),
        ],
        child: const MaterialApp(home: CalendarHistoryView()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('landscape_history_split')),
      findsOneWidget,
    );
    expect(find.textContaining('Sessions on'), findsOneWidget);
  });
}
