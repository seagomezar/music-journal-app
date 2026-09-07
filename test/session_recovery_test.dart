import 'package:flutter_test/flutter_test.dart';
import 'package:flute/providers/practice_provider.dart';
import 'package:flute/models/routine.dart';
import 'package:flute/models/exercise.dart';
import 'widget_test.dart' show FakeStopwatch;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'relaunch recovers elapsed practice and notes paused with stable save ID',
    () async {
      Map<String, dynamic>? saved;
      final clock = FakeStopwatch();
      final exercise = Exercise(
        id: 'ex',
        name: 'Long tones',
        targetBpm: 80,
        articulation: 'Legato',
      );
      final first = PracticeProvider(
        activeStopwatch: clock,
        persistDraft: (value) async => saved = value,
      );
      first.startSession(
        Routine(
          id: 'routine',
          title: 'Warmup',
          description: '',
          exercises: [exercise],
        ),
      );
      first.startExercise(exercise.id, 90);
      first.notesController.text = 'Remember this passage';
      clock.advance(const Duration(seconds: 63));
      await first.checkpointSession();
      first.dispose();
      await Future<void>.delayed(Duration.zero);
      final recovered = PracticeProvider(
        recoveredDraft: saved,
        persistDraft: (value) async => saved = value,
      );
      expect(recovered.isActive, true);
      expect(recovered.isPaused, true);
      expect(recovered.isPitchListening, false);
      expect(recovered.secondsElapsed, 63);
      expect(recovered.notesController.text, 'Remember this passage');
      final record = await recovered.prepareSessionRecord([]);
      expect(record!.id, saved!['sessionId']);
      expect(record.exerciseResults.single.practicedBpm, 90);
      expect(record.exerciseResults.single.durationInSeconds, 63);
      recovered.completeSession();
      await recovered.checkpointSession();
      expect(saved, null);
      recovered.dispose();
    },
  );
}
