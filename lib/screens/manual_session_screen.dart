import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/exercise.dart';
import '../models/session_record.dart';
import '../providers/history_provider.dart';
import '../providers/localization_provider.dart';
import '../providers/routine_provider.dart';
import '../theme/app_theme.dart';

class ManualSessionScreen extends StatefulWidget {
  const ManualSessionScreen({super.key, required this.initialDate});

  final DateTime initialDate;

  @override
  State<ManualSessionScreen> createState() => _ManualSessionScreenState();
}

class _ManualSessionScreenState extends State<ManualSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _durationController = TextEditingController(text: '30');
  final _notesController = TextEditingController();
  final Set<String> _selectedExerciseKeys = {};

  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  bool _isSaving = false;
  String? _timeError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final initial = widget.initialDate.isAfter(now) ? now : widget.initialDate;
    _selectedDate = DateTime(initial.year, initial.month, initial.day);
    final defaultStart = _isToday(_selectedDate, now)
        ? now.subtract(const Duration(minutes: 30))
        : DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            18,
          );
    _startTime = TimeOfDay.fromDateTime(defaultStart);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RoutineProvider>().loadRoutines();
    });
  }

  @override
  void dispose() {
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  static bool _isToday(DateTime date, DateTime now) =>
      date.year == now.year && date.month == now.month && date.day == now.day;

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedDate = selected;
      _timeError = null;
      if (_isToday(selected, now)) {
        _startTime = TimeOfDay.fromDateTime(
          now.subtract(const Duration(minutes: 30)),
        );
      }
    });
  }

  Future<void> _selectTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _startTime = selected;
      _timeError = null;
    });
  }

  String _exerciseKey(String routineId, String exerciseId) =>
      '$routineId::$exerciseId';

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    final durationMinutes = int.parse(_durationController.text.trim());
    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final end = start.add(Duration(minutes: durationMinutes));
    final now = DateTime.now();
    if (start.isAfter(now) || end.isAfter(now)) {
      setState(() => _timeError = context.translate('manual_session_future'));
      return;
    }

    setState(() {
      _isSaving = true;
      _timeError = null;
    });

    final selectedExercises = <Exercise>[];
    for (final routine in context.read<RoutineProvider>().routines) {
      for (final exercise in routine.exercises) {
        if (_selectedExerciseKeys.contains(
          _exerciseKey(routine.id, exercise.id),
        )) {
          selectedExercises.add(exercise);
        }
      }
    }

    final session = SessionRecord(
      id: 'session_${const Uuid().v7()}',
      startTime: start,
      endTime: end,
      totalDurationInSeconds: durationMinutes * 60,
      completedExercises: selectedExercises,
      rehearsedPieces: const [],
      notes: _notesController.text.trim(),
    );

    try {
      await context.read<HistoryProvider>().saveSession(session);
      if (!mounted) return;
      Navigator.of(context).pop(session.localStartTime);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('manual_session_save_error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeCode = context.watch<LocalizationProvider>().localeCode;
    final routines = context.watch<RoutineProvider>().routines;
    return Scaffold(
      appBar: AppBar(title: Text(context.translate('log_past_session'))),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(context.translate('save_manual_session')),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                context.translate('manual_session_description'),
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              AppTheme.glassCard(
                child: Column(
                  children: [
                    Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_month_rounded),
                        title: Text(context.translate('session_date')),
                        subtitle: Text(
                          DateFormat.yMMMMd(localeCode).format(_selectedDate),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _isSaving ? null : _selectDate,
                      ),
                    ),
                    const Divider(color: AppTheme.border),
                    Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule_rounded),
                        title: Text(context.translate('session_start_time')),
                        subtitle: Text(_startTime.format(context)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _isSaving ? null : _selectTime,
                      ),
                    ),
                  ],
                ),
              ),
              if (_timeError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _timeError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationController,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.translate('duration_minutes'),
                  prefixIcon: const Icon(Icons.timer_outlined),
                  suffixText: context.translate('minutes_short'),
                ),
                validator: (value) {
                  final duration = int.tryParse(value?.trim() ?? '');
                  if (duration == null || duration < 1 || duration > 1440) {
                    return context.translate('invalid_manual_duration');
                  }
                  return null;
                },
                onChanged: (_) {
                  if (_timeError != null) setState(() => _timeError = null);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                enabled: !_isSaving,
                maxLines: 4,
                maxLength: 5000,
                decoration: InputDecoration(
                  labelText: context.translate('practice_notes'),
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
              ),
              if (routines.any((routine) => routine.exercises.isNotEmpty)) ...[
                const SizedBox(height: 8),
                Text(
                  context.translate('completed_exercises_optional'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...routines
                    .where((routine) => routine.exercises.isNotEmpty)
                    .map(
                      (routine) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppTheme.glassCard(
                          padding: EdgeInsets.zero,
                          child: Material(
                            type: MaterialType.transparency,
                            child: ExpansionTile(
                              title: Text(routine.title),
                              children: routine.exercises.map((exercise) {
                                final key = _exerciseKey(
                                  routine.id,
                                  exercise.id,
                                );
                                return CheckboxListTile(
                                  value: _selectedExerciseKeys.contains(key),
                                  title: Text(exercise.name),
                                  subtitle: Text('${exercise.targetBpm} BPM'),
                                  onChanged: _isSaving
                                      ? null
                                      : (selected) {
                                          setState(() {
                                            if (selected == true) {
                                              _selectedExerciseKeys.add(key);
                                            } else {
                                              _selectedExerciseKeys.remove(key);
                                            }
                                          });
                                        },
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
