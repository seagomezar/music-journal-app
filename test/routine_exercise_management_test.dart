import 'dart:async';

import 'package:flute/models/exercise.dart';
import 'package:flute/models/piece.dart';
import 'package:flute/models/routine.dart';
import 'package:flute/providers/localization_provider.dart';
import 'package:flute/providers/repertoire_provider.dart';
import 'package:flute/providers/routine_provider.dart';
import 'package:flute/screens/routine_config_view.dart';
import 'package:flute/theme/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

class _DelayedRoutineProvider extends _EditableRoutineProvider {
  _DelayedRoutineProvider(super.routines);

  final saveStarted = Completer<void>();
  final allowSave = Completer<void>();

  @override
  Future<void> saveRoutine(Routine routine) async {
    saveCalls += 1;
    if (!saveStarted.isCompleted) saveStarted.complete();
    await allowSave.future;
    final index = _routines.indexWhere(
      (candidate) => candidate.id == routine.id,
    );
    final updated = List<Routine>.from(_routines);
    updated[index] = routine;
    _routines = updated;
    notifyListeners();
  }
}

class _MemoryRepertoireProvider extends RepertoireProvider {
  _MemoryRepertoireProvider([this.items = const []]);

  final List<Piece> items;

  @override
  List<Piece> get pieces => List.unmodifiable(items);

  @override
  Future<void> loadPieces() async {}
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
  _EditableRoutineProvider routineProvider, {
  _MemoryRepertoireProvider? repertoireProvider,
  bool expandRoutine = true,
  Size viewportSize = const Size(430, 1000),
}) async {
  tester.view.physicalSize = viewportSize;
  tester.view.devicePixelRatio = 1;
  // Synthetic logical viewports must not inherit the native phone's
  // portrait safe-area pixels at a different device pixel ratio.
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<RoutineProvider>.value(value: routineProvider),
        ChangeNotifierProvider<RepertoireProvider>.value(
          value: repertoireProvider ?? _MemoryRepertoireProvider(),
        ),
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
  if (expandRoutine) {
    await tester.tap(find.text('Technique'));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('new routine dialog remains scrollable in phone landscape', (
    tester,
  ) async {
    final provider = _EditableRoutineProvider(const []);
    addTearDown(provider.dispose);
    await _pumpRoutineScreen(
      tester,
      provider,
      expandRoutine: false,
      viewportSize: const Size(667, 375),
    );

    await tester.tap(find.byTooltip('Create Custom Routine'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.widget<AlertDialog>(find.byType(AlertDialog)).scrollable,
      isTrue,
    );
    expect(find.text('New Study Routine'), findsOneWidget);
  });

  testWidgets('web routine row exposes and performs its expansion action', (
    tester,
  ) async {
    final provider = _EditableRoutineProvider([_routineWithExercises()]);
    addTearDown(provider.dispose);
    await _pumpRoutineScreen(tester, provider, expandRoutine: false);

    await tester.tap(find.text('Technique'));
    await tester.pumpAndSettle();
    expect(find.text('Add Exercise'), findsOneWidget);
  }, skip: !kIsWeb);

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

  testWidgets('attaches and removes an existing repertoire PDF', (
    tester,
  ) async {
    final routineProvider = _EditableRoutineProvider([_routineWithExercises()]);
    final repertoireProvider = _MemoryRepertoireProvider([
      Piece(
        id: 'piece-pdf',
        title: 'Taffanel Study',
        composer: 'Taffanel',
        pdfPath: '/managed/taffanel.pdf',
        targetBpm: 90,
      ),
      Piece(
        id: 'piece-without-pdf',
        title: 'No score',
        composer: 'Composer',
        targetBpm: 80,
      ),
    ]);
    addTearDown(routineProvider.dispose);
    addTearDown(repertoireProvider.dispose);
    await _pumpRoutineScreen(
      tester,
      routineProvider,
      repertoireProvider: repertoireProvider,
    );

    await tester.tap(find.byKey(const ValueKey('edit_exercise_exercise-1')));
    await tester.pumpAndSettle();
    final chooseButton = find.widgetWithText(
      OutlinedButton,
      'Choose from repertoire',
    );
    await tester.ensureVisible(chooseButton);
    await tester.tap(chooseButton);
    await tester.pumpAndSettle();

    expect(find.text('Taffanel Study'), findsOneWidget);
    expect(find.text('No score'), findsNothing);
    await tester.tap(find.text('Taffanel Study'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      routineProvider.routines.single.exercises.first.musicSheetPieceId,
      'piece-pdf',
    );
    expect(find.text('Taffanel Study'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('edit_exercise_exercise-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove music sheet'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      routineProvider.routines.single.exercises.first.musicSheetPieceId,
      isNull,
    );
  });

  testWidgets('ignores repeated exercise save taps while saving', (
    tester,
  ) async {
    final provider = _DelayedRoutineProvider([_routineWithExercises()]);
    addTearDown(provider.dispose);
    await _pumpRoutineScreen(tester, provider);

    await tester.tap(find.byKey(const ValueKey('edit_exercise_exercise-1')));
    await tester.pumpAndSettle();
    final saveButton = find.widgetWithText(ElevatedButton, 'Save');

    await tester.tap(saveButton);
    await tester.tap(saveButton);
    await provider.saveStarted.future;
    await tester.pump();

    expect(provider.saveCalls, 1);
    expect(tester.widget<ElevatedButton>(saveButton).onPressed, isNull);

    provider.allowSave.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
