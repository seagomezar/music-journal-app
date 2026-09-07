import 'dart:async';
import 'dart:convert';

/// Serializes checkpoints and deletions so an old write cannot revive a draft.
class SessionDraftService {
  SessionDraftService({required this.write, required this.snapshot});
  final Future<void> Function(Map<String, dynamic>?) write;
  final Map<String, dynamic>? Function() snapshot;
  Future<void> _queue = Future.value();
  Timer? _timer;
  Object? lastError;

  void schedule() {
    _timer ??= Timer(const Duration(seconds: 1), () {
      _timer = null;
      unawaited(flush().catchError((Object _) {}));
    });
  }

  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    final current = snapshot();
    final data = current == null
        ? null
        : jsonDecode(jsonEncode(current)) as Map<String, dynamic>;
    final next = _queue.then((_) => write(data));
    _queue = next.then<void>(
      (_) => lastError = null,
      onError: (Object error, StackTrace _) {
        lastError = error;
      },
    );
    return next;
  }

  void dispose() {
    _timer?.cancel();
  }
}
