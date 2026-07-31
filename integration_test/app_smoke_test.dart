import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flute/main.dart' as app;
import 'package:flute/models/exercise.dart';
import 'package:flute/models/piece.dart';
import 'package:flute/models/routine.dart';
import 'package:flute/services/database_service.dart';
import 'package:flute/services/file_storage_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iOS core user journey remains stable', (tester) async {
    final database = DatabaseService();
    await database.init();
    for (final session in database.getSessions()) {
      await database.deleteSession(session.id);
    }
    for (final routine in database.getRoutines()) {
      await database.deleteRoutine(routine.id);
    }
    for (final piece in database.getPieces()) {
      await database.deletePiece(piece.id);
    }
    await database.deleteUserProfile();
    await database.setPreferredLocale('en');
    await FileStorageService().deleteAllManagedFiles();
    await database.saveRoutine(
      Routine(
        id: 'ios_smoke_routine',
        title: 'Articulation drills',
        description: 'iOS integration test routine',
        exercises: [
          Exercise(
            id: 'ios_smoke_exercise',
            name: 'Double Tonguing T-K Drill',
            targetBpm: 120,
            articulation: 'Double Tonguing',
          ),
        ],
      ),
    );
    await database.savePiece(
      Piece(
        id: 'ios_smoke_piece',
        title: 'Syrinx',
        composer: 'Claude Debussy',
        targetBpm: 50,
        measuresTotal: 35,
        measuresCompleted: 12,
      ),
    );

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Set up your local profile'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Please enter a valid name'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'iOS Smoke Tester');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Welcome back,'), findsOneWidget);
    expect(find.text('iOS Smoke Tester'), findsWidgets);

    await tester.tap(find.byTooltip('Español'));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido de nuevo,'), findsOneWidget);
    await tester.tap(find.byTooltip('English'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Routines'));
    await tester.pumpAndSettle();
    expect(find.text('Study Routines'), findsOneWidget);

    await tester.tap(find.text('Articulation drills'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Exercise'));
    await tester.pumpAndSettle();
    expect(find.text('Add Exercise to Articulation drills'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('Add Exercise to Articulation drills'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Repertoire'));
    await tester.pumpAndSettle();
    expect(find.text('Repertoire Manager'), findsOneWidget);
    await tester.tap(find.text('Syrinx'));
    await tester.pumpAndSettle();
    expect(find.text('Measures Progress: 12 / 35'), findsOneWidget);
    await tester.tap(find.text('Save Progress'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    final quickStart = find.text('Articulation drills');
    await tester.ensureVisible(quickStart);
    await tester.tap(quickStart);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Finish'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump();

    final exercise = find.text('Double Tonguing T-K Drill');
    await tester.ensureVisible(exercise);
    await tester.tap(exercise);
    await tester.pump();

    final metronome = find.text('Visual Metronome');
    await tester.ensureVisible(metronome);
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byType(Switch));
    await tester.pump();

    final openRecorder = find.text('Open Self-Recorder (Pauses Clock)');
    await tester.ensureVisible(openRecorder);
    await tester.tap(openRecorder);
    await tester.pump();
    final startRecording = find.byTooltip('Start recording');
    await tester.ensureVisible(startRecording);
    await tester.tap(startRecording);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Recording audio...'), findsOneWidget);
    final stopRecording = find.byTooltip('Stop recording');
    await tester.ensureVisible(stopRecording);
    await tester.tap(stopRecording);
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.text('Practice recording saved on this device'),
      findsOneWidget,
    );

    final playRecording = find.byTooltip('Play Recording');
    await tester.ensureVisible(playRecording);
    await tester.tap(playRecording);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byTooltip('Stop Playback'), findsOneWidget);
    final stopPlayback = find.byTooltip('Stop Playback');
    await tester.ensureVisible(stopPlayback);
    await tester.tap(stopPlayback);
    await tester.pump();
    final closeRecorder = find.text('Close Recorder & Resume Clock');
    await tester.ensureVisible(closeRecorder);
    await tester.tap(closeRecorder);
    await tester.pump();

    final finish = find.text('Finish');
    await tester.ensureVisible(finish);
    await tester.tap(finish);
    await tester.pump();
    expect(find.text('Finish Practice Session?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'iOS smoke test completed');
    await tester.tap(find.text('Save & Finish'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Practice History'), findsOneWidget);
    expect(find.text('iOS smoke test completed'), findsOneWidget);

    await tester.tap(find.text('Log Past Session'));
    await tester.pumpAndSettle();
    final manualFields = find.byType(TextFormField);
    await tester.enterText(manualFields.at(0), '15');
    await tester.enterText(manualFields.at(1), 'Manually logged on iOS');
    final saveManualSession = find.text('Save Session');
    await tester.ensureVisible(saveManualSession);
    await tester.tap(saveManualSession);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final manualNote = find.text('Manually logged on iOS');
    await tester.scrollUntilVisible(
      manualNote,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    expect(manualNote, findsOneWidget);

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    final settings = find.byTooltip('Settings');
    await tester.ensureVisible(settings);
    await tester.tap(settings);
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Export journal backup'), findsOneWidget);
    expect(find.text('Import journal backup'), findsOneWidget);

    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.text('Data stored on your device'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terms and Conditions'));
    await tester.pumpAndSettle();
    expect(find.text('Acceptance'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final eraseAllData = find.text('Erase all data');
    await tester.ensureVisible(eraseAllData);
    await tester.tap(eraseAllData);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erase everything'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Set up your local profile'), findsOneWidget);
  });
}
