import 'package:flute/models/exercise.dart';
import 'package:flute/models/routine.dart';
import 'package:flute/providers/localization_provider.dart';
import 'package:flute/providers/routine_provider.dart';
import 'package:flute/screens/routine_config_view.dart';
import 'package:flute/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _EditableRoutineProvider extends RoutineProvider {
  _EditableRoutineProvider(List<Routine> routines)
    : _routines = List<Routine>.from(routines);

  List<Routine> _routines;
  int saveCalls = 0;

  @override
  List<Routine> get routines => _routines;

  @override
  Future<void> loadRoutines() async {}

  @override
  Future<void> saveRoutine(Routine routine) async {
    saveCalls += 1;
    final index = _routines.indexWhere(
      (candidate) => candidate.id == routine.id,
    );
    final updated = List<Routine>.from(_routines);
    if (index == -1) {
      updated.add(routine);
    } else {
      updated[index] = routine;
    }
    _routines = updated;
    notifyListeners();
  }
}

Routine _routineWithExercises() => Routine(
  id: 'routine-1',
  title: 'Technique',
  description: 'Daily fundamentals',
  exercises: [
    Exercise(
      id: 'exercise-1',
      name: 'Long Tones',
      targetBpm: 60,
      articulation: 'Legato',
    ),
    Exercise(
      id: 'exercise-2',
      name: 'Major Scales',
      targetBpm: 90,
      articulation: 'Staccato',
    ),
    Exercise(
      id: 'exercise-3',
      name: 'Double Tonguing',
      targetBpm: 120,
      articulation: 'Double Tonguing',
    ),
  ],
);

Future<void> _pumpRoutineScreen(
  WidgetTester tester,
  _EditableRoutineProvider routineProvider,
) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<RoutineProvider>.value(value: routineProvider),
        ChangeNotifierProvider(
          create: (_) => LocalizationProvider(initialLocale: 'en'),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const RoutineConfigView(),
      ),
    ),
  );
  await tester.tap(find.text('Technique'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('edits an exercise without changing its identity or position', (
    tester,
  ) async {
    final provider = _EditableRoutineProvider([_routineWithExercises()]);
    addTearDown(provider.dispose);
    await _pumpRoutineScreen(tester, provider);

    await tester.tap(find.byKey(const ValueKey('edit_exercise_exercise-1')));
    await tester.pumpAndSettle();

    expect(find.text('Edit Exercise in Technique'), findsOneWidget);
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'Long Tones – Low Register');
    await tester.enterText(fields.at(1), '72');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    final exercises = provider.routines.single.exercises;
    expect(provider.saveCalls, 1);
    expect(exercises.map((exercise) => exercise.id), [
      'exercise-1',
      'exercise-2',
      'exercise-3',
    ]);
    expect(exercises.first.name, 'Long Tones – Low Register');
    expect(exercises.first.targetBpm, 72);
    expect(exercises.first.articulation, 'Legato');
    expect(find.text('Long Tones – Low Register'), findsOneWidget);
  });

  testWidgets(
    'reorders exercises from the drag handle and preserves the order',
    (tester) async {
      final provider = _EditableRoutineProvider([_routineWithExercises()]);
      addTearDown(provider.dispose);
      await _pumpRoutineScreen(tester, provider);

      expect(find.byType(ReorderableDragStartListener), findsNWidgets(3));
      expect(
        find.text('Drag the handle to reorder exercises.'),
        findsOneWidget,
      );

      final reorderableList = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      reorderableList.onReorderItem!(0, 2);
      await tester.pumpAndSettle();

      expect(provider.saveCalls, 1);
      expect(
        provider.routines.single.exercises.map((exercise) => exercise.id),
        ['exercise-2', 'exercise-3', 'exercise-1'],
      );

      final restored = Routine.fromJson(provider.routines.single.toJson());
      expect(restored.exercises.map((exercise) => exercise.id), [
        'exercise-2',
        'exercise-3',
        'exercise-1',
      ]);
    },
  );
}
