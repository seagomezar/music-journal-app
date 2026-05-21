import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                  hintText: locProv.isSpanish ? 'ej. Escalas Mañaneras' : 'e.g., Morning Scales & Tone',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _routineDescController,
                decoration: InputDecoration(
                  labelText: context.translate('routine_desc_label'),
                  hintText: locProv.isSpanish ? 'ej. Enfoque en la embocadura...' : 'Focus on embouchure and breath control...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.translate('cancel'), style: const TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (_routineTitleController.text.trim().isNotEmpty) {
                  final routine = Routine(
                    id: 'routine_${DateTime.now().millisecondsSinceEpoch}',
                    title: _routineTitleController.text.trim(),
                    description: _routineDescController.text.trim(),
                    exercises: [],
                  );
                  Provider.of<RoutineProvider>(context, listen: false).saveRoutine(routine);
                  Navigator.of(context).pop();
                }
              },
              child: Text(context.translate('create_btn')),
            ),
          ],
        );
      },
    );
  }

  void _showAddExerciseDialog(BuildContext context, Routine routine) {
    _exNameController.clear();
    _exBpmController.text = '80';
    _exArticulation = 'Staccato';
    final locProv = Provider.of<LocalizationProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.translate('add_exercise_to', [routine.title])),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _exNameController,
                      decoration: InputDecoration(
                        labelText: context.translate('exercise_name_label'),
                        hintText: locProv.isSpanish ? 'ej. Doble golpe en Sol Mayor' : 'e.g., T-K Staccato in G Major',
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
                      value: _exArticulation,
                      decoration: InputDecoration(labelText: context.translate('articulation_label')),
                      items: _articulations.map((String art) {
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
                  child: Text(context.translate('cancel'), style: const TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final bpm = int.tryParse(_exBpmController.text) ?? 80;
                    if (_exNameController.text.trim().isNotEmpty) {
                      final newExercise = Exercise(
                        id: 'ex_${DateTime.now().millisecondsSinceEpoch}',
                        name: _exNameController.text.trim(),
                        targetBpm: bpm,
                        articulation: _exArticulation,
                      );
                      final updatedExercises = List<Exercise>.from(routine.exercises)..add(newExercise);
                      final updatedRoutine = routine.copyWith(exercises: updatedExercises);
                      Provider.of<RoutineProvider>(context, listen: false).saveRoutine(updatedRoutine);
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(context.translate('add_btn')),
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
        title: Text(context.translate('routines_tab_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryAccent, size: 28),
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
                          Icon(Icons.playlist_add_circle_rounded, size: 72, color: AppTheme.border.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(
                            context.translate('no_routines_configured_empty'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.translate('click_add_routine'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: routineProv.routines.length,
                    itemBuilder: (context, index) {
                      final routine = routineProv.routines[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: AppTheme.glassCard(
                          padding: EdgeInsets.zero,
                          child: ExpansionTile(
                            shape: const RoundedRectangleBorder(side: BorderSide.none),
                            collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                            tilePadding: const EdgeInsets.all(16),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.my_library_music_rounded, color: AppTheme.primaryAccent),
                            ),
                            title: Text(
                              routine.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(
                              routine.description.isEmpty ? context.translate('technical_exercises_default') : routine.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              onPressed: () {
                                _showDeleteRoutineConfirm(context, routine);
                              },
                            ),
                            children: [
                              const Divider(height: 1, color: AppTheme.border),
                              Container(
                                padding: const EdgeInsets.all(16),
                                color: Colors.black12,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          context.translate('technical_checklist'),
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 13),
                                        ),
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppTheme.primaryAccent,
                                            padding: EdgeInsets.zero,
                                          ),
                                          icon: const Icon(Icons.add, size: 16),
                                          label: Text(context.translate('add_exercise'), style: const TextStyle(fontSize: 12)),
                                          onPressed: () => _showAddExerciseDialog(context, routine),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (routine.exercises.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        child: Center(
                                          child: Text(
                                            context.translate('no_exercises_added'),
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                          ),
                                        ),
                                      )
                                    else
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: routine.exercises.length,
                                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                                        itemBuilder: (context, idx) {
                                          final exercise = routine.exercises[idx];
                                          return Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: AppTheme.surface.withOpacity(0.4),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: AppTheme.border.withOpacity(0.3)),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  _getArticulationIcon(exercise.articulation),
                                                  color: AppTheme.primaryAccent.withOpacity(0.7),
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        exercise.name,
                                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        context.translate('exercise_detail_format', [exercise.articulation, exercise.targetBpm.toString()]),
                                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 16),
                                                  onPressed: () {
                                                    final updated = List<Exercise>.from(routine.exercises)..removeAt(idx);
                                                    routineProv.saveRoutine(routine.copyWith(exercises: updated));
                                                  },
                                                )
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  void _showDeleteRoutineConfirm(BuildContext context, Routine routine) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.translate('delete_routine_title')),
          content: Text(context.translate('delete_routine_confirm', [routine.title])),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.translate('cancel'), style: const TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Provider.of<RoutineProvider>(context, listen: false).deleteRoutine(routine.id);
                Navigator.of(context).pop();
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
