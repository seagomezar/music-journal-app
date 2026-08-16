import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/routine.dart';
import '../models/exercise.dart';
import '../providers/routine_provider.dart';
import '../providers/localization_provider.dart';
import '../theme/app_theme.dart';

class RoutineConfigView extends StatefulWidget {
  const RoutineConfigView({super.key});

  @override
  State<RoutineConfigView> createState() => _RoutineConfigViewState();
}

class _RoutineConfigViewState extends State<RoutineConfigView> {
  final TextEditingController _routineTitleController = TextEditingController();
  final TextEditingController _routineDescController = TextEditingController();

  final TextEditingController _exNameController = TextEditingController();
  final TextEditingController _exBpmController = TextEditingController();
  String _exArticulation = 'Staccato';

  final List<String> _articulations = [
    'Staccato',
    'Legato',
    'Double Tonguing',
    'Triple Tonguing',
    'Flutter Tonguing',
    'Tenuto',
    'Accents',
  ];

  @override
  void dispose() {
    _routineTitleController.dispose();
    _routineDescController.dispose();
    _exNameController.dispose();
    _exBpmController.dispose();
    super.dispose();
  }

  void _showAddRoutineDialog(BuildContext context) {
    _routineTitleController.clear();
    _routineDescController.clear();
    final locProv = Provider.of<LocalizationProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.translate('new_routine_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _routineTitleController,
                decoration: InputDecoration(
                  labelText: context.translate('routine_title_label'),
                  hintText: locProv.isSpanish
                      ? 'ej. Escalas Mañaneras'
                      : 'e.g., Morning Scales & Tone',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _routineDescController,
                decoration: InputDecoration(
                  labelText: context.translate('routine_desc_label'),
                  hintText: locProv.isSpanish
                      ? 'ej. Enfoque en la embocadura...'
                      : 'Focus on embouchure and breath control...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                context.translate('cancel'),
                style: TextStyle(color: AppTheme.textSecondaryColor(context)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor(context),
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: () async {
                final title = _routineTitleController.text.trim();
                final description = _routineDescController.text.trim();
                if (title.isNotEmpty &&
                    title.length <= 100 &&
                    description.length <= 500) {
                  final routine = Routine(
                    id: 'routine_${const Uuid().v7()}',
                    title: title,
                    description: description,
                    exercises: [],
                  );
                  try {
                    await Provider.of<RoutineProvider>(
                      context,
                      listen: false,
                    ).saveRoutine(routine);
                    if (context.mounted) Navigator.of(context).pop();
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.translate('routine_save_error'),
                          ),
                        ),
                      );
                    }
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.translate('invalid_routine_values'),
                      ),
                    ),
                  );
                }
              },
              child: Text(context.translate('create_btn')),
            ),
          ],
        );
      },
    );
  }

  void _showExerciseDialog(
    BuildContext context,
    Routine routine, {
    Exercise? exercise,
  }) {
    final isEditing = exercise != null;
    _exNameController.text = exercise?.name ?? '';
    _exBpmController.text = (exercise?.targetBpm ?? 80).toString();
    _exArticulation = exercise?.articulation ?? 'Staccato';
    final articulationOptions = List<String>.from(_articulations);
    if (!articulationOptions.contains(_exArticulation)) {
      articulationOptions.add(_exArticulation);
    }
    final locProv = Provider.of<LocalizationProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                context.translate(
                  isEditing ? 'edit_exercise_title' : 'add_exercise_to',
                  [routine.title],
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _exNameController,
                      decoration: InputDecoration(
                        labelText: context.translate('exercise_name_label'),
                        hintText: locProv.isSpanish
                            ? 'ej. Doble golpe en Sol Mayor'
                            : 'e.g., T-K Staccato in G Major',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _exBpmController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.translate('target_bpm_tempo'),
                        suffixText: 'BPM',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _exArticulation,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.translate('articulation_label'),
                      ),
                      items: articulationOptions.map((String art) {
                        return DropdownMenuItem<String>(
                          value: art,
                          child: Text(art),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            _exArticulation = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    context.translate('cancel'),
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor(context),
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: () async {
                    final bpm = int.tryParse(_exBpmController.text);
                    final name = _exNameController.text.trim();
                    if (name.isNotEmpty &&
                        name.length <= 100 &&
                        bpm != null &&
                        bpm >= 40 &&
                        bpm <= 240) {
                      final updatedExercise = exercise != null
                          ? exercise.copyWith(
                              name: name,
                              targetBpm: bpm,
                              articulation: _exArticulation,
                            )
                          : Exercise(
                              id: 'ex_${const Uuid().v7()}',
                              name: name,
                              targetBpm: bpm,
                              articulation: _exArticulation,
                            );
                      final updatedExercises = List<Exercise>.from(
                        routine.exercises,
                      );
                      if (exercise != null) {
                        final exerciseIndex = updatedExercises.indexWhere(
                          (candidate) => candidate.id == exercise.id,
                        );
                        if (exerciseIndex == -1) {
                          if (context.mounted) Navigator.of(context).pop();
                          return;
                        }
                        updatedExercises[exerciseIndex] = updatedExercise;
                      } else {
                        updatedExercises.add(updatedExercise);
                      }
                      final updatedRoutine = routine.copyWith(
                        exercises: updatedExercises,
                      );
                      try {
                        await Provider.of<RoutineProvider>(
                          context,
                          listen: false,
                        ).saveRoutine(updatedRoutine);
                        if (context.mounted) Navigator.of(context).pop();
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.translate('routine_save_error'),
                              ),
                            ),
                          );
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.translate('invalid_exercise_values'),
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    context.translate(isEditing ? 'save' : 'add_btn'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final routineProv = Provider.of<RoutineProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.translate('routines_tab_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color: AppTheme.accentColor(context),
              size: 28,
            ),
            tooltip: context.translate('add_routine'),
            onPressed: () => _showAddRoutineDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: routineProv.isLoading
            ? const Center(child: CircularProgressIndicator())
            : routineProv.routines.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.playlist_add_circle_rounded,
                        size: 72,
                        color: AppTheme.borderColor(
                          context,
                        ).withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.translate('no_routines_configured_empty'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.translate('click_add_routine'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: routineProv.routines.length,
                itemBuilder: (context, index) {
                  final routine = routineProv.routines[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: AppTheme.glassCard(
                      padding: EdgeInsets.zero,
                      child: Material(
                        type: MaterialType.transparency,
                        child: ExpansionTile(
                          shape: const RoundedRectangleBorder(
                            side: BorderSide.none,
                          ),
                          collapsedShape: const RoundedRectangleBorder(
                            side: BorderSide.none,
                          ),
                          tilePadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor(
                                context,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.my_library_music_rounded,
                              color: AppTheme.accentColor(context),
                            ),
                          ),
                          title: Text(
                            routine.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            routine.description.isEmpty
                                ? context.translate(
                                    'technical_exercises_default',
                                  )
                                : routine.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor(context),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            tooltip: context.translate('delete_btn'),
                            onPressed: () {
                              _showDeleteRoutineConfirm(context, routine);
                            },
                          ),
                          children: [
                            Divider(
                              height: 1,
                              color: AppTheme.borderColor(context),
                            ),
                            Container(
                              padding: const EdgeInsets.all(16),
                              color: Colors.black12,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          context.translate(
                                            'technical_checklist',
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(fontSize: 13),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppTheme.accentColor(
                                            context,
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                        icon: const Icon(Icons.add, size: 16),
                                        label: Text(
                                          context.translate('add_exercise'),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        onPressed: () => _showExerciseDialog(
                                          context,
                                          routine,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (routine.exercises.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Center(
                                        child: Text(
                                          context.translate(
                                            'no_exercises_added',
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondaryColor(
                                              context,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  else ...[
                                    if (routine.exercises.length > 1)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          context.translate(
                                            'reorder_exercises_hint',
                                          ),
                                          style: TextStyle(
                                            color: AppTheme.textSecondaryColor(
                                              context,
                                            ),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ReorderableListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      buildDefaultDragHandles: false,
                                      itemCount: routine.exercises.length,
                                      onReorderItem:
                                          (oldIndex, newIndex) async {
                                            await _reorderExercises(
                                              context,
                                              routine,
                                              oldIndex,
                                              newIndex,
                                            );
                                          },
                                      itemBuilder: (context, idx) {
                                        final exercise = routine.exercises[idx];
                                        return Container(
                                          key: ValueKey(
                                            'exercise_${routine.id}_${exercise.id}',
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceColor(
                                              context,
                                            ).withValues(alpha: 0.4),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.borderColor(
                                                context,
                                              ).withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                _getArticulationIcon(
                                                  exercise.articulation,
                                                ),
                                                color: AppTheme.accentColor(
                                                  context,
                                                ).withValues(alpha: 0.7),
                                                size: 18,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      exercise.name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      context.translate(
                                                        'exercise_detail_format',
                                                        [
                                                          exercise.articulation,
                                                          exercise.targetBpm
                                                              .toString(),
                                                        ],
                                                      ),
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: AppTheme
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                key: ValueKey(
                                                  'edit_exercise_${exercise.id}',
                                                ),
                                                constraints:
                                                    const BoxConstraints.tightFor(
                                                      width: 36,
                                                      height: 36,
                                                    ),
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                icon: Icon(
                                                  Icons.edit_outlined,
                                                  color: AppTheme.accentColor(
                                                    context,
                                                  ),
                                                  size: 18,
                                                ),
                                                tooltip: context.translate(
                                                  'edit_exercise',
                                                ),
                                                onPressed: () =>
                                                    _showExerciseDialog(
                                                      context,
                                                      routine,
                                                      exercise: exercise,
                                                    ),
                                              ),
                                              IconButton(
                                                constraints:
                                                    const BoxConstraints.tightFor(
                                                      width: 36,
                                                      height: 36,
                                                    ),
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                icon: const Icon(
                                                  Icons
                                                      .remove_circle_outline_rounded,
                                                  color: Colors.redAccent,
                                                  size: 16,
                                                ),
                                                tooltip: context.translate(
                                                  'delete_btn',
                                                ),
                                                onPressed: () async {
                                                  final updated =
                                                      List<Exercise>.from(
                                                        routine.exercises,
                                                      )..removeAt(idx);
                                                  try {
                                                    await routineProv
                                                        .saveRoutine(
                                                          routine.copyWith(
                                                            exercises: updated,
                                                          ),
                                                        );
                                                  } catch (error) {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            context.translate(
                                                              'routine_save_error',
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                              ),
                                              ReorderableDragStartListener(
                                                key: ValueKey(
                                                  'exercise_drag_${exercise.id}',
                                                ),
                                                index: idx,
                                                child: Tooltip(
                                                  message: context.translate(
                                                    'reorder_exercise',
                                                  ),
                                                  child: Semantics(
                                                    button: true,
                                                    label: context.translate(
                                                      'reorder_exercise',
                                                    ),
                                                    child: const SizedBox(
                                                      width: 36,
                                                      height: 36,
                                                      child: Icon(
                                                        Icons
                                                            .drag_handle_rounded,
                                                        color: AppTheme
                                                            .textSecondary,
                                                        size: 22,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _reorderExercises(
    BuildContext context,
    Routine routine,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex == oldIndex) return;

    final updatedExercises = List<Exercise>.from(routine.exercises);
    final movedExercise = updatedExercises.removeAt(oldIndex);
    updatedExercises.insert(newIndex, movedExercise);

    try {
      await Provider.of<RoutineProvider>(
        context,
        listen: false,
      ).saveRoutine(routine.copyWith(exercises: updatedExercises));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('routine_save_error'))),
        );
      }
    }
  }

  void _showDeleteRoutineConfirm(BuildContext context, Routine routine) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.translate('delete_routine_title')),
          content: Text(
            context.translate('delete_routine_confirm', [routine.title]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                context.translate('cancel'),
                style: TextStyle(color: AppTheme.textSecondaryColor(context)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  await Provider.of<RoutineProvider>(
                    context,
                    listen: false,
                  ).deleteRoutine(routine.id);
                  if (context.mounted) Navigator.of(context).pop();
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.translate('routine_delete_error'),
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text(context.translate('delete_btn')),
            ),
          ],
        );
      },
    );
  }

  IconData _getArticulationIcon(String art) {
    switch (art.toLowerCase()) {
      case 'legato':
        return Icons.gesture_rounded;
      case 'staccato':
        return Icons.blur_on_rounded;
      case 'double tonguing':
        return Icons.repeat_rounded;
      case 'triple tonguing':
        return Icons.repeat_on_rounded;
      case 'flutter tonguing':
        return Icons.waves_rounded;
      default:
        return Icons.music_note_rounded;
    }
  }
}
