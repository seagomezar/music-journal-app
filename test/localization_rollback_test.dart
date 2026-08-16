import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flute/providers/localization_provider.dart';

/// These tests run in an isolate where Hive is never initialized, so the
/// singleton DatabaseService backing LocalizationProvider throws the moment a
/// locale is persisted. That lets us assert the persistence *rollback* path
/// end-to-end: the visible locale must revert when the write fails.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('locale reverts to the previous value when persistence fails', () async {
    final provider = LocalizationProvider(initialLocale: 'en');
    final observed = <String>[];
    provider.addListener(() => observed.add(provider.localeCode));

    expect(provider.isSpanish, isFalse);

    // The DB write throws (Hive uninitialized) so setLocale must rethrow.
    await expectLater(provider.setLocale('es'), throwsA(anything));

    // Visible locale rolled back to English despite the optimistic switch.
    expect(provider.localeCode, 'en');
    expect(provider.isSpanish, isFalse);

    // Listeners saw the optimistic 'es' then the rollback to 'en'.
    expect(observed, ['es', 'en']);
  });

  test('setting the current locale is a no-op and never persists', () async {
    final provider = LocalizationProvider(initialLocale: 'es');
    var notified = false;
    provider.addListener(() => notified = true);

    // Same locale must short-circuit before touching the (failing) DB.
    await provider.setLocale('es');

    expect(provider.isSpanish, isTrue);
    expect(notified, isFalse);
  });

  test('unsupported locale codes are ignored', () async {
    final provider = LocalizationProvider(initialLocale: 'en');
    await provider.setLocale('fr');
    expect(provider.localeCode, 'en');
    debugPrint('rollback + guard behavior verified');
  });
}
