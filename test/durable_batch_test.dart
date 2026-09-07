import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:flute/services/durable_batch_service.dart';

void main() {
  test(
    'interrupted rollback preserves original values in durable log',
    () async {
      final directory = await Directory.systemTemp.createTemp('flute_batch_');
      Hive.init(directory.path);
      var records = await Hive.openBox('records');
      var journal = await Hive.openBox('journal');
      await records.put('original', 'my journal');
      final batch = DurableBatchService(
        journal,
        {'records': records},
        afterWrite: () async {
          await records.close();
          throw StateError('storage unavailable');
        },
      );
      await expectLater(
        batch.apply({
          'records': {'original': 'replacement', 'new': 'new entry'},
        }),
        throwsA(anything),
      );
      expect(journal.containsKey('pending'), true);
      await Hive.close();
      Hive.init(directory.path);
      records = await Hive.openBox('records');
      journal = await Hive.openBox('journal');
      await DurableBatchService(journal, {'records': records}).recover();
      expect(records.get('original'), 'my journal');
      expect(records.containsKey('new'), false);
      expect(journal.containsKey('pending'), false);
      await Hive.close();
      await directory.delete(recursive: true);
    },
  );
}
