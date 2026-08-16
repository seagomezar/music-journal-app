import 'dart:js_interop';
import 'dart:js_interop_unsafe';

class AnalyticsService {
  const AnalyticsService._();

  static void track(String eventName, {Map<String, String>? properties}) {
    final plausible = globalContext['plausible'];
    if (plausible == null || !plausible.isA<JSFunction>()) return;

    final payload = <String, dynamic>{
      'props': <String, dynamic>{...?properties},
    };
    (plausible as JSFunction).callAsFunction(
      null,
      eventName.toJS,
      payload.jsify(),
    );
  }
}
