import 'package:flutter_test/flutter_test.dart';
import 'package:flute/models/user_profile.dart';
import 'package:flute/models/exercise.dart';
import 'package:flute/models/routine.dart';
import 'package:flute/models/piece.dart';
import 'package:flute/providers/practice_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Data Models Tests', () {
    test('UserProfile JSON serialization', () {
      final profile = UserProfile(
        id: 'u1',
        name: 'Alex Flutist',
        email: 'alex@flute.com',
        weeklyPracticeGoalMinutes: 180,
      );

      final json = profile.toJson();
      expect(json['id'], 'u1');
      expect(json['name'], 'Alex Flutist');
      expect(json['email'], 'alex@flute.com');
      expect(json['weeklyPracticeGoalMinutes'], 180);

      final parsed = UserProfile.fromJson(json);
      expect(parsed.id, 'u1');
      expect(parsed.name, 'Alex Flutist');
      expect(parsed.email, 'alex@flute.com');
      expect(parsed.weeklyPracticeGoalMinutes, 180);
    });

    test('Exercise and Routine models', () {
      final exercise = Exercise(
        id: 'ex1',
        name: 'Legato Scale',
        targetBpm: 90,
        articulation: 'Legato',
      );

      final routine = Routine(
        id: 'r1',
        title: 'Daily Scale Routine',
        description: 'Scales in all keys',
        exercises: [exercise],
      );

      final json = routine.toJson();
      expect(json['title'], 'Daily Scale Routine');
      expect(json['exercises'].length, 1);
      expect(json['exercises'][0]['name'], 'Legato Scale');

      final parsed = Routine.fromJson(json);
      expect(parsed.title, 'Daily Scale Routine');
      expect(parsed.exercises.length, 1);
      expect(parsed.exercises[0].name, 'Legato Scale');
      expect(parsed.exercises[0].targetBpm, 90);
    });

    test('Piece progress calculation', () {
      final piece = Piece(
        id: 'p1',
        title: 'Syrinx',
        composer: 'Debussy',
        targetBpm: 60,
        measuresTotal: 40,
        measuresCompleted: 10,
      );

      expect(piece.progressPercentage, 0.25);
    });
  });

  group('PracticeProvider Tests', () {
    test('Initial practice session state', () {
      final provider = PracticeProvider();
      expect(provider.isActive, false);
      expect(provider.isPaused, false);
      expect(provider.secondsElapsed, 0);
      expect(provider.completedExerciseIds.isEmpty, true);
    });

    test('Starting a session', () {
      final provider = PracticeProvider();
      final routine = Routine(
        id: 'r1',
        title: 'Morning Scales',
        description: 'Scales in all keys',
        exercises: [
          Exercise(id: 'ex1', name: 'Legato Scale', targetBpm: 90, articulation: 'Legato')
        ],
      );

      provider.startSession(routine);

      expect(provider.isActive, true);
      expect(provider.isPaused, false);
      expect(provider.activeRoutine?.title, 'Morning Scales');
      
      provider.cancelSession();
      expect(provider.isActive, false);
    });
  });
}
