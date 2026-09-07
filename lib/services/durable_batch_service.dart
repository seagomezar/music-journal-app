import 'package:hive_ce/hive.dart';

/// A durable undo log for changes spanning Hive boxes.
/// Recovery is idempotent, touches only affected keys, and retains its log if
/// any recovery write fails. Call recover before exposing the database.
class DurableBatchService {
  DurableBatchService(this.journal, this.boxes, {this.afterWrite});

  final Box journal;
  final Map<String, Box> boxes;
  final Future<void> Function()? afterWrite;
  Future<void> _queue = Future.value();

  Future<void> recover() async {
    final pending = journal.get('pending');
    if (pending == null) return;
    for (final entry in (pending as Map).entries) {
      final box = boxes[entry.key]!;
      for (final previous in (entry.value as Map).entries) {
        final value = previous.value as Map;
        if (value['present'] == true) {
          await box.put(previous.key, value['value']);
        } else {
          await box.delete(previous.key);
        }
      }
      await box.flush();
    }
    await journal.delete('pending');
    await journal.flush();
  }

  Future<void> apply(
    Map<String, Map<String, dynamic>> writes, {
    Map<String, List<String>> deletions = const {},
  }) {
    final operation = _queue.then((_) async {
      await recover();
      final previous = <String, dynamic>{};
      for (final name in {...writes.keys, ...deletions.keys}) {
        final box = boxes[name]!;
        previous[name] = {
          for (final key in {...?writes[name]?.keys, ...?deletions[name]})
            key: {'present': box.containsKey(key), 'value': box.get(key)},
        };
      }
      await journal.put('pending', previous);
      await journal.flush();
      try {
        for (final name in previous.keys) {
          final box = boxes[name]!;
          await box.putAll(writes[name] ?? {});
          await box.deleteAll(deletions[name] ?? []);
          await box.flush();
          await afterWrite?.call();
        }
        await journal.delete('pending');
        await journal.flush();
      } catch (_) {
        // If recovery itself fails, the durable log is kept for next launch.
        await recover();
        rethrow;
      }
    });
    _queue = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }
}
