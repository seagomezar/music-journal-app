import 'package:flutter_test/flutter_test.dart';
import 'package:flute/services/analytics_service.dart';

void main() {
  test('measurement events are safe when Plausible is not configured', () {
    expect(
      () => AnalyticsService.track(
        'practice_session_started',
        properties: {'routine': 'quick_start'},
      ),
      returnsNormally,
    );
  });
}
