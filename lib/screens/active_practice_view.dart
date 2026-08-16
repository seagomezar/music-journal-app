import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/practice_provider.dart';
import '../providers/repertoire_provider.dart';
import '../providers/history_provider.dart';
import '../providers/localization_provider.dart';
import '../providers/routine_provider.dart';
import '../models/piece.dart';
import '../models/exercise.dart';
import '../models/routine.dart';
import '../models/practice_appearance_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/practice_tuner_card.dart';

class ActivePracticeView extends StatefulWidget {
  const ActivePracticeView({super.key});

  @override
  State<ActivePracticeView> createState() => _ActivePracticeViewState();
}

class _ActivePracticeViewState extends State<ActivePracticeView> {
  bool _isExitDialogVisible = false;
  int? _tempoBeforeAdjustment;
  bool _isSavingExerciseTempo = false;
  String? _focusedExerciseId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RepertoireProvider>(context, listen: false).loadPieces();
    });
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getLocalizedArticulation(BuildContext context, String articulation) {
    final isSpanish = Provider.of<LocalizationProvider>(
      context,
      listen: false,
    ).isSpanish;
    if (articulation.toLowerCase() == 'slurred') {
      return isSpanish ? 'Ligado' : 'Slurred';
    } else if (articulation.toLowerCase() == 'tongued') {
      return isSpanish ? 'Picado' : 'Tongued';
    }
    return articulation;
  }

  Future<void> _saveExerciseTempo({
    required BuildContext context,
    required PracticeProvider practiceProvider,
    required RoutineProvider routineProvider,
    required String exerciseId,
    required int previousBpm,
  }) async {
    final updatedRoutine = practiceProvider.activeRoutine;
    if (updatedRoutine == null || _isSavingExerciseTempo) return;
    setState(() => _isSavingExerciseTempo = true);
    try {
      await routineProvider.saveRoutine(updatedRoutine);
    } catch (error) {
      practiceProvider.setExerciseBpm(exerciseId, previousBpm);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.translate('exercise_tempo_save_error')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingExerciseTempo = false);
    }
  }

  Future<void> _adjustMetronomeTempo({
    required BuildContext context,
    required PracticeProvider practiceProvider,
    required RoutineProvider routineProvider,
    required int delta,
  }) async {
    final previousBpm = practiceProvider.metronomeBpm;
    final nextBpm = (previousBpm + delta).clamp(40, 240);
    if (nextBpm == previousBpm || _isSavingExerciseTempo) return;

    final exerciseId = practiceProvider.activeExerciseId;
    if (exerciseId == null) {
      practiceProvider.setMetronomeBpm(nextBpm);
      return;
    }

    practiceProvider.setExerciseBpm(exerciseId, nextBpm);
    await _saveExerciseTempo(
      context: context,
      practiceProvider: practiceProvider,
      routineProvider: routineProvider,
      exerciseId: exerciseId,
      previousBpm: previousBpm,
    );
  }

  String _buildExerciseNotesDraft(
    BuildContext context,
    PracticeProvider practiceProvider,
  ) {
    final routine = practiceProvider.activeRoutine;
    if (routine == null) return '';
    final lines = <String>[];
    for (final exercise in routine.exercises) {
      final bpm = practiceProvider.exercisePracticedBpms[exercise.id];
      if (bpm == null) continue;
      final pitch = practiceProvider.exercisePitchSummaries[exercise.id];
      lines.add(
        pitch != null && pitch.hasEnoughData
            ? context.translate('exercise_notes_draft_item_pitch', [
                exercise.name,
                bpm.toString(),
                pitch.onPitchPercentage.round().toString(),
                pitch.referenceHz.toString(),
                pitch.toleranceCents.toString(),
              ])
            : context.translate('exercise_notes_draft_item', [
                exercise.name,
                bpm.toString(),
              ]),
      );
    }
    if (lines.isEmpty) return '';
    return [
      context.translate('exercise_notes_draft_title'),
      ...lines,
    ].join('\n');
  }

  String _notesWithExerciseDraft(String existingNotes, String draft) {
    final existing = existingNotes.trim();
    if (draft.isEmpty) return existing;
    if (existing.isEmpty) return draft;
    return '$existing\n\n$draft';
  }

  Future<void> _confirmEndPractice(
    BuildContext context,
    PracticeProvider practiceProv,
    RepertoireProvider repProv,
  ) async {
    practiceProv.pauseSession();
    await practiceProv.stopPitchCapture();
    if (!mounted || !context.mounted) return;
    final locProv = Provider.of<LocalizationProvider>(context, listen: false);
    final historyProv = Provider.of<HistoryProvider>(context, listen: false);
    final originalNotes = practiceProv.notesController.text;
    final draft = _buildExerciseNotesDraft(context, practiceProv);
    final finishNotesController = TextEditingController(
      text: _notesWithExerciseDraft(originalNotes, draft),
    );
    var isSaving = false;
    var sessionSaved = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text(context.translate('finish_session_title')),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.translate(
                          kIsWeb
                              ? 'finish_session_subtitle_web'
                              : 'finish_session_subtitle',
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: finishNotesController,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: context.translate('practice_notes'),
                          hintText: locProv.isSpanish
                              ? 'ej. Se sintió bien. El pasaje de repertorio en el compás 15 necesita un golpe de lengua doble más limpio.'
                              : 'e.g., Felt good. Repertoire passage on measure 15 needs cleaner double tonguing.',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            await practiceProv.resumeSession();
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          },
                    child: Text(
                      dialogContext.translate('keep_practicing'),
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor(dialogContext),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor(dialogContext),
                      foregroundColor: Theme.of(
                        dialogContext,
                      ).colorScheme.onPrimary,
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            setDialogState(() => isSaving = true);
                            try {
                              practiceProv.notesController.text =
                                  finishNotesController.text;
                              final record = await practiceProv
                                  .prepareSessionRecord(repProv.pieces);
                              if (record == null) {
                                throw StateError('No active session to save.');
                              }
                              await historyProv.saveSession(record);
                              practiceProv.completeSession();
                              if (!mounted || !dialogContext.mounted) return;
                              sessionSaved = true;
                              Navigator.of(dialogContext).pop();
                            } catch (error) {
                              practiceProv.notesController.text = originalNotes;
                              if (!dialogContext.mounted) return;
                              setDialogState(() => isSaving = false);
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    dialogContext.translate(
                                      'session_save_error',
                                    ),
                                  ),
                                  backgroundColor: Theme.of(
                                    dialogContext,
                                  ).colorScheme.error,
                                ),
                              );
                            }
                          },
                    child: isSaving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(dialogContext.translate('save_finish')),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      // showDialog completes when pop is requested, before the reverse route
      // animation has necessarily detached the TextField from its controller.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      finishNotesController.dispose();
    }
    if (sessionSaved && mounted && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmExitPractice(
    BuildContext context,
    PracticeProvider practiceProvider,
  ) async {
    if (_isExitDialogVisible) return false;
    _isExitDialogVisible = true;
    practiceProvider.pauseSession();
    try {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.translate('exit_practice_title')),
          content: Text(dialogContext.translate('exit_practice_desc')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                dialogContext.translate('keep_practicing'),
                style: TextStyle(color: AppTheme.accentColor(dialogContext)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.translate('discard_session_btn')),
            ),
          ],
        ),
      );
      if (discard == true) {
        await practiceProvider.cancelSession();
        return true;
      }
      await practiceProvider.resumeSession();
      return false;
    } finally {
      _isExitDialogVisible = false;
    }
  }

  Widget _buildFocusedRecorder(
    BuildContext context,
    PracticeProvider practiceProv,
  ) {
    final hasRecording = practiceProv.recordedAudioPath != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: AppTheme.glassCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.translate('self_recorder'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 3),
            Text(
              context.translate('self_recorder_subtitle'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 8),
              Text(
                context.translate('recording_web_session_only'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.accentColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (!practiceProv.isAudioRecorderActive)
              OutlinedButton.icon(
                onPressed: practiceProv.activateAudioRecorder,
                icon: const Icon(Icons.mic_none_rounded),
                label: Text(context.translate('open_self_recorder')),
              )
            else ...[
              if (practiceProv.isRecording)
                Text(
                  context.translate('recording_audio'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else if (practiceProv.isPlayingPlayback)
                Text(
                  context.translate('playing_back_audio'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.accentColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                )
              else if (hasRecording)
                Text(
                  context.translate(
                    kIsWeb
                        ? 'recording_web_session_only'
                        : 'recording_saved_temp',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  if (!practiceProv.isRecording && !hasRecording)
                    IconButton.filled(
                      tooltip: context.translate('start_recording'),
                      onPressed: () async {
                        final success = await practiceProv.startRecording();
                        if (!success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.translate('mic_error')),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.fiber_manual_record),
                    ),
                  if (practiceProv.isRecording)
                    IconButton.filled(
                      tooltip: context.translate('stop_recording'),
                      onPressed: practiceProv.stopRecording,
                      icon: const Icon(Icons.stop_rounded),
                    ),
                  if (hasRecording && !practiceProv.isPlayingPlayback)
                    IconButton.filledTonal(
                      tooltip: context.translate('play_recording_btn'),
                      onPressed: practiceProv.startPlayback,
                      icon: const Icon(Icons.play_arrow_rounded),
                    ),
                  if (practiceProv.isPlayingPlayback)
                    IconButton.filledTonal(
                      tooltip: context.translate('stop_playback_btn'),
                      onPressed: practiceProv.stopPlayback,
                      icon: const Icon(Icons.stop_rounded),
                    ),
                  if (hasRecording)
                    IconButton(
                      tooltip: context.translate('delete_recording'),
                      onPressed: practiceProv.deleteRecording,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                ],
              ),
              TextButton(
                onPressed: practiceProv.closeAudioRecorder,
                child: Text(context.translate('close_recorder')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFocusedPracticeBody({
    required BuildContext context,
    required PracticeProvider practiceProv,
    required Routine? routine,
    required Exercise? suggestedExercise,
    required int defaultBpm,
    required RepertoireProvider repProv,
    required RoutineProvider routineProv,
  }) {
    final exercises = routine?.exercises ?? const <Exercise>[];
    final selectedId =
        practiceProv.activeExerciseId ??
        _focusedExerciseId ??
        suggestedExercise?.id;
    final selectedExercise = exercises.cast<Exercise?>().firstWhere(
      (exercise) => exercise?.id == selectedId,
      orElse: () => suggestedExercise,
    );
    final selectedBpm = selectedExercise == null
        ? defaultBpm
        : practiceProv.exercisePracticedBpms[selectedExercise.id] ??
              selectedExercise.targetBpm;
    final isSelectedActive =
        selectedExercise != null &&
        practiceProv.activeExerciseId == selectedExercise.id;

    return ListView(
      key: const ValueKey('focused_practice_mode'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Semantics(
          container: true,
          label: context.translate('active_practice_session'),
          child: AppTheme.glassCard(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            customColor: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                Text(
                  _formatTime(practiceProv.secondsElapsed),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w300,
                    letterSpacing: 2,
                  ),
                ),
                if (isSelectedActive)
                  Text(
                    context.translate('exercise_elapsed', [
                      _formatTime(
                        practiceProv.exerciseDurationInSeconds(
                          selectedExercise.id,
                        ),
                      ),
                    ]),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                const SizedBox(height: 4),
                Text(
                  practiceProv.isPaused
                      ? context.translate('study_clock_paused')
                      : context.translate('study_clock_running'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.4,
                    color: practiceProv.isPaused
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : AppTheme.accentColor(context),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  selectedExercise?.name ??
                      context.translate('free_repertoire_study'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (selectedExercise != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _getLocalizedArticulation(
                      context,
                      selectedExercise.articulation,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      key: const ValueKey('decrease_metronome_tempo'),
                      tooltip: context.translate('decrease_tempo'),
                      onPressed: practiceProv.metronomeBpm <= 40
                          ? null
                          : () => _adjustMetronomeTempo(
                              context: context,
                              practiceProvider: practiceProv,
                              routineProvider: routineProv,
                              delta: -1,
                            ),
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Text(
                            '${practiceProv.metronomeBpm}',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'BPM',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      key: const ValueKey('increase_metronome_tempo'),
                      tooltip: context.translate('increase_tempo'),
                      onPressed: practiceProv.metronomeBpm >= 240
                          ? null
                          : () => _adjustMetronomeTempo(
                              context: context,
                              practiceProvider: practiceProv,
                              routineProvider: routineProv,
                              delta: 1,
                            ),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('focused_pause'),
                      onPressed: practiceProv.isPaused
                          ? practiceProv.resumeSession
                          : practiceProv.pauseSession,
                      icon: Icon(
                        practiceProv.isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                      ),
                      label: Text(
                        context.translate(
                          practiceProv.isPaused ? 'resume' : 'pause',
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('focused_finish'),
                      onPressed: () =>
                          _confirmEndPractice(context, practiceProv, repProv),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(context.translate('finish')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (exercises.length > 1) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selectedId,
            decoration: InputDecoration(
              labelText: context.translate('exercise_label'),
              prefixIcon: const Icon(Icons.music_note_rounded),
            ),
            items: exercises
                .map(
                  (exercise) => DropdownMenuItem<String>(
                    value: exercise.id,
                    child: Text(exercise.name),
                  ),
                )
                .toList(),
            onChanged: practiceProv.activeExerciseId != null
                ? null
                : (id) {
                    final exercise = exercises.firstWhere(
                      (item) => item.id == id,
                    );
                    setState(() => _focusedExerciseId = id);
                    practiceProv.setMetronomeBpm(
                      practiceProv.exercisePracticedBpms[exercise.id] ??
                          exercise.targetBpm,
                    );
                  },
          ),
        ],
        const SizedBox(height: 16),
        AppTheme.glassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              practiceProv.metronomeOn
                  ? Icons.music_note_rounded
                  : Icons.music_note_outlined,
              color: practiceProv.metronomeOn
                  ? AppTheme.accentColor(context)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: Text(context.translate('visual_metronome')),
            subtitle: Text(
              context.translate('tempo', [selectedBpm.toString()]),
            ),
            trailing: Switch.adaptive(
              value: practiceProv.metronomeOn,
              onChanged: (_) =>
                  practiceProv.toggleMetronome(practiceProv.metronomeBpm),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: const ValueKey('focused_tools'),
            leading: const Icon(Icons.tune_rounded),
            title: Text(context.translate('tuner')),
            subtitle: Text(
              practiceProv.isTrackingPitch
                  ? context.translate('track_my_pitch')
                  : context.translate('tuner_subtitle'),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: PracticeTunerCard(practiceProvider: practiceProv),
              ),
              _buildFocusedRecorder(context, practiceProv),
            ],
          ),
        ),
        if (selectedExercise != null) ...[
          const SizedBox(height: 12),
          Center(
            child: practiceProv.activeExerciseId == selectedExercise.id
                ? OutlinedButton.icon(
                    key: ValueKey('stop_exercise_${selectedExercise.id}'),
                    onPressed: () =>
                        practiceProv.stopExercise(selectedExercise.id),
                    icon: const Icon(Icons.stop_rounded),
                    label: Text(context.translate('stop_exercise')),
                  )
                : FilledButton.icon(
                    key: ValueKey('start_exercise_${selectedExercise.id}'),
                    onPressed: practiceProv.isPaused
                        ? null
                        : () => practiceProv.startExercise(
                            selectedExercise.id,
                            selectedBpm,
                          ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      context.translate(
                        isSelectedActive ? 'resume_exercise' : 'start_exercise',
                      ),
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final practiceProv = Provider.of<PracticeProvider>(context);
    final repProv = Provider.of<RepertoireProvider>(context);
    final routineProv = Provider.of<RoutineProvider>(context, listen: false);
    final isSpanish = Provider.of<LocalizationProvider>(
      context,
      listen: false,
    ).isSpanish;

    final routine = practiceProv.activeRoutine;
    final suggestedExercise = routine != null && routine.exercises.isNotEmpty
        ? routine.exercises.firstWhere(
            (e) => !practiceProv.completedExerciseIds.contains(e.id),
            orElse: () => routine.exercises.last,
          )
        : null;

    final defaultBpm = practiceProv.activeExerciseId == null
        ? suggestedExercise?.targetBpm ?? 80
        : practiceProv.exercisePracticedBpms[practiceProv.activeExerciseId!] ??
              suggestedExercise?.targetBpm ??
              80;

    return PopScope(
      canPop: !practiceProv.isActive,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !practiceProv.isActive) return;
        final shouldPop = await _confirmExitPractice(context, practiceProv);
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            routine != null
                ? routine.title
                : context.translate('free_repertoire_study'),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: context.translate('exit_practice_title'),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: practiceProv.reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: practiceProv.visualMode == PracticeVisualMode.focused
                ? _buildFocusedPracticeBody(
                    context: context,
                    practiceProv: practiceProv,
                    routine: routine,
                    suggestedExercise: suggestedExercise,
                    defaultBpm: defaultBpm,
                    repProv: repProv,
                    routineProv: routineProv,
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10.0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Glowing Stopwatch Clock
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 24,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor(context),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: practiceProv.isPaused
                                        ? AppTheme.borderColor(context)
                                        : AppTheme.accentColor(
                                            context,
                                          ).withValues(alpha: 0.5),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    if (!practiceProv.isPaused)
                                      BoxShadow(
                                        color: AppTheme.accentColor(
                                          context,
                                        ).withValues(alpha: 0.15),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatTime(practiceProv.secondsElapsed),
                                      style: TextStyle(
                                        fontSize: 54,
                                        fontWeight: FontWeight.w300,
                                        color: AppTheme.textPrimaryColor(
                                          context,
                                        ),
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      practiceProv.isPaused
                                          ? context.translate(
                                              'study_clock_paused',
                                            )
                                          : context.translate(
                                              'study_clock_running',
                                            ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        color: practiceProv.isPaused
                                            ? AppTheme.textSecondaryColor(
                                                context,
                                              )
                                            : AppTheme.accentColor(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Clock Controllers
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Pause/Play Button
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: practiceProv.isPaused
                                        ? AppTheme.primaryColor(context)
                                        : AppTheme.cardColor(context),
                                    foregroundColor: practiceProv.isPaused
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : AppTheme.primaryColor(context),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: AppTheme.borderColor(context),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  icon: Icon(
                                    practiceProv.isPaused
                                        ? Icons.play_arrow_rounded
                                        : Icons.pause_rounded,
                                  ),
                                  label: Text(
                                    practiceProv.isPaused
                                        ? context.translate('resume')
                                        : context.translate('pause'),
                                  ),
                                  onPressed: () async {
                                    if (practiceProv.isPaused) {
                                      await practiceProv.resumeSession();
                                    } else {
                                      practiceProv.pauseSession();
                                    }
                                  },
                                ),
                                const SizedBox(width: 16),
                                // Stop Button
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.stop_rounded),
                                  label: Text(context.translate('finish')),
                                  onPressed: () => _confirmEndPractice(
                                    context,
                                    practiceProv,
                                    repProv,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 28),

                            // Repertoire Tracker Dropdown Selector
                            AppTheme.glassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.translate('repertoire_tracking'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    context.translate(
                                      'repertoire_tracking_subtitle',
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondaryColor(
                                        context,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: practiceProv.activePieceId,
                                    hint: Text(
                                      context.translate('select_active_sheet'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.library_music_rounded,
                                        color: AppTheme.textSecondaryColor(
                                          context,
                                        ),
                                      ),
                                    ),
                                    items: [
                                      DropdownMenuItem<String>(
                                        value: null,
                                        child: Text(
                                          context.translate(
                                            'none_technical_only',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      ...repProv.pieces.map((Piece piece) {
                                        return DropdownMenuItem<String>(
                                          value: piece.id,
                                          child: Text(
                                            '${piece.title} (${piece.composer == 'Unknown' ? (isSpanish ? 'Desconocido' : 'Unknown') : piece.composer})',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }),
                                    ],
                                    onChanged: (String? val) {
                                      if (val == null) {
                                        practiceProv.selectActivePiece(null);
                                      } else {
                                        final selected = repProv.pieces
                                            .firstWhere((p) => p.id == val);
                                        practiceProv.selectActivePiece(
                                          selected,
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Technical Exercises Checklist (if routine active)
                            if (routine != null) ...[
                              AppTheme.glassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.translate(
                                        'exercises_for_routine',
                                        [routine.title],
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: routine.exercises.length,
                                      separatorBuilder: (_, _) => Divider(
                                        height: 1,
                                        color: AppTheme.borderColor(context),
                                      ),
                                      itemBuilder: (context, idx) {
                                        final exercise = routine.exercises[idx];
                                        final isCompleted = practiceProv
                                            .completedExerciseIds
                                            .contains(exercise.id);
                                        final isActive =
                                            practiceProv.activeExerciseId ==
                                            exercise.id;
                                        final duration = practiceProv
                                            .exerciseDurationInSeconds(
                                              exercise.id,
                                            );
                                        final practicedBpm =
                                            practiceProv
                                                .exercisePracticedBpms[exercise
                                                .id] ??
                                            exercise.targetBpm;
                                        return AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? AppTheme.accentColor(
                                                    context,
                                                  ).withValues(alpha: 0.08)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: isActive
                                                ? Border.all(
                                                    color: AppTheme
                                                        .primaryAccent
                                                        .withValues(
                                                          alpha: 0.45,
                                                        ),
                                                  )
                                                : null,
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  Checkbox(
                                                    value: isCompleted,
                                                    activeColor:
                                                        AppTheme.accentColor(
                                                          context,
                                                        ),
                                                    onChanged: (_) => practiceProv
                                                        .toggleExerciseCompleted(
                                                          exercise.id,
                                                        ),
                                                  ),
                                                  Expanded(
                                                    child: InkWell(
                                                      onTap: () => practiceProv
                                                          .toggleExerciseCompleted(
                                                            exercise.id,
                                                          ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            exercise.name,
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 14,
                                                              decoration:
                                                                  isCompleted
                                                                  ? TextDecoration
                                                                        .lineThrough
                                                                  : null,
                                                              color: isCompleted
                                                                  ? AppTheme
                                                                        .textSecondary
                                                                  : AppTheme
                                                                        .textPrimary,
                                                            ),
                                                          ),
                                                          Text(
                                                            '${_getLocalizedArticulation(context, exercise.articulation)} • ${isSpanish ? 'Objetivo' : 'Target'}: ${exercise.targetBpm} BPM',
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              color: AppTheme
                                                                  .textSecondary,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  if (isActive)
                                                    ElevatedButton.icon(
                                                      key: ValueKey(
                                                        'stop_exercise_${exercise.id}',
                                                      ),
                                                      onPressed: () =>
                                                          practiceProv
                                                              .stopExercise(
                                                                exercise.id,
                                                              ),
                                                      icon: const Icon(
                                                        Icons.stop_rounded,
                                                        size: 18,
                                                      ),
                                                      label: Text(
                                                        context.translate(
                                                          'stop_exercise',
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    OutlinedButton.icon(
                                                      key: ValueKey(
                                                        'start_exercise_${exercise.id}',
                                                      ),
                                                      onPressed:
                                                          practiceProv.isPaused
                                                          ? null
                                                          : () => practiceProv
                                                                .startExercise(
                                                                  exercise.id,
                                                                  exercise
                                                                      .targetBpm,
                                                                ),
                                                      icon: const Icon(
                                                        Icons
                                                            .play_arrow_rounded,
                                                        size: 18,
                                                      ),
                                                      label: Text(
                                                        duration > 0
                                                            ? context.translate(
                                                                'resume_exercise',
                                                              )
                                                            : context.translate(
                                                                'start_exercise',
                                                              ),
                                                      ),
                                                    ),
                                                  const SizedBox(width: 8),
                                                ],
                                              ),
                                              if (duration > 0 || isActive)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        48,
                                                        4,
                                                        12,
                                                        0,
                                                      ),
                                                  child: Wrap(
                                                    spacing: 12,
                                                    runSpacing: 4,
                                                    alignment: WrapAlignment
                                                        .spaceBetween,
                                                    children: [
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons
                                                                .timer_outlined,
                                                            size: 16,
                                                            color: AppTheme
                                                                .textSecondary,
                                                          ),
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                          Text(
                                                            context.translate(
                                                              'exercise_elapsed',
                                                              [
                                                                _formatTime(
                                                                  duration,
                                                                ),
                                                              ],
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      Text(
                                                        context.translate(
                                                          'practiced_tempo',
                                                          [
                                                            practicedBpm
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
                                              if (isActive)
                                                Slider(
                                                  key: ValueKey(
                                                    'exercise_tempo_${exercise.id}',
                                                  ),
                                                  min: 40,
                                                  max: 240,
                                                  activeColor:
                                                      AppTheme.accentColor(
                                                        context,
                                                      ),
                                                  inactiveColor:
                                                      AppTheme.borderColor(
                                                        context,
                                                      ),
                                                  value: practicedBpm
                                                      .toDouble(),
                                                  onChangeStart: (value) {
                                                    _tempoBeforeAdjustment =
                                                        value.round();
                                                  },
                                                  onChanged:
                                                      _isSavingExerciseTempo
                                                      ? null
                                                      : (value) => practiceProv
                                                            .setExerciseBpm(
                                                              exercise.id,
                                                              value.round(),
                                                            ),
                                                  onChangeEnd: (value) async {
                                                    final previous =
                                                        _tempoBeforeAdjustment ??
                                                        practicedBpm;
                                                    _tempoBeforeAdjustment =
                                                        null;
                                                    if (previous ==
                                                        value.round()) {
                                                      return;
                                                    }
                                                    await _saveExerciseTempo(
                                                      context: context,
                                                      practiceProvider:
                                                          practiceProv,
                                                      routineProvider:
                                                          routineProv,
                                                      exerciseId: exercise.id,
                                                      previousBpm: previous,
                                                    );
                                                  },
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Visual Metronome Panel
                            AppTheme.glassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              context.translate(
                                                'visual_metronome',
                                              ),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              context.translate('tempo', [
                                                practiceProv.metronomeBpm
                                                    .toString(),
                                              ]),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppTheme.textSecondaryColor(
                                                      context,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          // Pulsing beat dot indicator
                                          if (practiceProv.metronomeOn)
                                            Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color:
                                                    practiceProv.metronomePulse
                                                    ? AppTheme.accentColor(
                                                        context,
                                                      )
                                                    : Colors.transparent,
                                                border: Border.all(
                                                  color: AppTheme.accentColor(
                                                    context,
                                                  ),
                                                  width: 2,
                                                ),
                                                boxShadow: [
                                                  if (practiceProv
                                                      .metronomePulse)
                                                    BoxShadow(
                                                      color: AppTheme
                                                          .primaryAccent
                                                          .withValues(
                                                            alpha: 0.8,
                                                          ),
                                                      blurRadius: 10,
                                                      spreadRadius: 2,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(width: 14),
                                          Semantics(
                                            label: context.translate(
                                              'visual_metronome',
                                            ),
                                            child: Switch(
                                              activeThumbColor:
                                                  AppTheme.accentColor(context),
                                              value: practiceProv.metronomeOn,
                                              onChanged: practiceProv.isPaused
                                                  ? null
                                                  : (value) {
                                                      practiceProv
                                                          .toggleMetronome(
                                                            defaultBpm,
                                                          );
                                                    },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (practiceProv.metronomeOn) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        IconButton.filledTonal(
                                          key: const ValueKey(
                                            'decrease_metronome_tempo',
                                          ),
                                          tooltip: context.translate(
                                            'decrease_tempo',
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          onPressed:
                                              _isSavingExerciseTempo ||
                                                  practiceProv.metronomeBpm <=
                                                      40
                                              ? null
                                              : () => _adjustMetronomeTempo(
                                                  context: context,
                                                  practiceProvider:
                                                      practiceProv,
                                                  routineProvider: routineProv,
                                                  delta: -1,
                                                ),
                                          icon: const Icon(
                                            Icons.remove_rounded,
                                          ),
                                        ),
                                        Expanded(
                                          child: Slider(
                                            min: 40,
                                            max: 240,
                                            activeColor: AppTheme.accentColor(
                                              context,
                                            ),
                                            inactiveColor: AppTheme.borderColor(
                                              context,
                                            ),
                                            value: practiceProv.metronomeBpm
                                                .toDouble(),
                                            onChangeStart:
                                                practiceProv.activeExerciseId ==
                                                    null
                                                ? null
                                                : (value) {
                                                    _tempoBeforeAdjustment =
                                                        value.round();
                                                  },
                                            onChanged: _isSavingExerciseTempo
                                                ? null
                                                : (double val) {
                                                    final exerciseId =
                                                        practiceProv
                                                            .activeExerciseId;
                                                    if (exerciseId == null) {
                                                      practiceProv
                                                          .setMetronomeBpm(
                                                            val.round(),
                                                          );
                                                    } else {
                                                      practiceProv
                                                          .setExerciseBpm(
                                                            exerciseId,
                                                            val.round(),
                                                          );
                                                    }
                                                  },
                                            onChangeEnd:
                                                practiceProv.activeExerciseId ==
                                                    null
                                                ? null
                                                : (value) async {
                                                    final exerciseId =
                                                        practiceProv
                                                            .activeExerciseId;
                                                    if (exerciseId == null) {
                                                      return;
                                                    }
                                                    final previous =
                                                        _tempoBeforeAdjustment ??
                                                        value.round();
                                                    _tempoBeforeAdjustment =
                                                        null;
                                                    if (previous ==
                                                        value.round()) {
                                                      return;
                                                    }
                                                    await _saveExerciseTempo(
                                                      context: context,
                                                      practiceProvider:
                                                          practiceProv,
                                                      routineProvider:
                                                          routineProv,
                                                      exerciseId: exerciseId,
                                                      previousBpm: previous,
                                                    );
                                                  },
                                          ),
                                        ),
                                        IconButton.filledTonal(
                                          key: const ValueKey(
                                            'increase_metronome_tempo',
                                          ),
                                          tooltip: context.translate(
                                            'increase_tempo',
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          onPressed:
                                              _isSavingExerciseTempo ||
                                                  practiceProv.metronomeBpm >=
                                                      240
                                              ? null
                                              : () => _adjustMetronomeTempo(
                                                  context: context,
                                                  practiceProvider:
                                                      practiceProv,
                                                  routineProvider: routineProv,
                                                  delta: 1,
                                                ),
                                          icon: const Icon(Icons.add_rounded),
                                        ),
                                      ],
                                    ),
                                    Divider(
                                      height: 16,
                                      color: AppTheme.borderColor(context),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            context.translate(
                                              'metronome_sound',
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: context.translate(
                                            practiceProv.metronomeSoundEnabled
                                                ? 'mute_metronome'
                                                : 'enable_metronome_sound',
                                          ),
                                          onPressed: () async {
                                            try {
                                              await practiceProv
                                                  .setMetronomeSoundEnabled(
                                                    !practiceProv
                                                        .metronomeSoundEnabled,
                                                  );
                                            } catch (error) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      context.translate(
                                                        'preference_save_error',
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          icon: Icon(
                                            practiceProv.metronomeSoundEnabled
                                                ? Icons.volume_up_rounded
                                                : Icons.volume_off_rounded,
                                            color:
                                                practiceProv
                                                    .metronomeSoundEnabled
                                                ? AppTheme.accentColor(context)
                                                : AppTheme.textSecondaryColor(
                                                    context,
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (practiceProv.metronomeSoundEnabled)
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.volume_down_rounded,
                                            size: 18,
                                            color: AppTheme.textSecondaryColor(
                                              context,
                                            ),
                                          ),
                                          Expanded(
                                            child: Slider(
                                              min: 0,
                                              max: 1,
                                              activeColor: AppTheme.accentColor(
                                                context,
                                              ),
                                              inactiveColor:
                                                  AppTheme.borderColor(context),
                                              value:
                                                  practiceProv.metronomeVolume,
                                              onChanged: (value) async {
                                                try {
                                                  await practiceProv
                                                      .setMetronomeVolume(
                                                        value,
                                                      );
                                                } catch (error) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          context.translate(
                                                            'preference_save_error',
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                            ),
                                          ),
                                          Icon(
                                            Icons.volume_up_rounded,
                                            size: 18,
                                            color: AppTheme.textSecondaryColor(
                                              context,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (practiceProv.isMetronomeSoundSuppressed)
                                      Text(
                                        context.translate(
                                          'metronome_sound_suppressed',
                                        ),
                                        style: TextStyle(
                                          color: AppTheme.textSecondaryColor(
                                            context,
                                          ),
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            PracticeTunerCard(practiceProvider: practiceProv),

                            const SizedBox(height: 20),

                            // Self-Evaluation Audio Recorder Panel
                            AppTheme.glassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    context.translate('self_recorder'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    context.translate('self_recorder_subtitle'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondaryColor(
                                        context,
                                      ),
                                    ),
                                  ),
                                  if (kIsWeb) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      context.translate(
                                        'recording_web_session_only',
                                      ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.accentColor(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),

                                  if (!practiceProv.isAudioRecorderActive)
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: AppTheme.accentColor(context),
                                        ),
                                        foregroundColor: AppTheme.accentColor(
                                          context,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.mic_none_rounded,
                                        size: 20,
                                      ),
                                      label: Text(
                                        context.translate('open_self_recorder'),
                                      ),
                                      onPressed: () {
                                        practiceProv.activateAudioRecorder();
                                      },
                                    )
                                  else ...[
                                    // Dynamic Wave visualizer
                                    if (practiceProv.isRecording) ...[
                                      Center(
                                        child: Column(
                                          children: [
                                            const SpinKitWave(
                                              color: Colors.redAccent,
                                              size: 32.0,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              context.translate(
                                                'recording_audio',
                                              ),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    Colors.redAccent.shade100,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                    ] else if (practiceProv
                                        .isPlayingPlayback) ...[
                                      Center(
                                        child: Column(
                                          children: [
                                            SpinKitWave(
                                              color: AppTheme.accentColor(
                                                context,
                                              ),
                                              size: 32.0,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              context.translate(
                                                'playing_back_audio',
                                              ),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.accentColor(
                                                  context,
                                                ),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                    ] else if (practiceProv.recordedAudioPath !=
                                        null) ...[
                                      SizedBox(
                                        height: 57,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.audiotrack_rounded,
                                              color: AppTheme.accentColor(
                                                context,
                                              ),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                context.translate(
                                                  kIsWeb
                                                      ? 'recording_web_session_only'
                                                      : 'recording_saved_temp',
                                                ),
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.accentColor(
                                                    context,
                                                  ),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                    ] else ...[
                                      SizedBox(
                                        height: 57,
                                        child: Center(
                                          child: Text(
                                            context.translate('mic_ready'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppTheme.textSecondaryColor(
                                                    context,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                    ],

                                    // Controls
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // Record button (Mic)
                                        if (!practiceProv.isRecording &&
                                            practiceProv.recordedAudioPath ==
                                                null)
                                          IconButton.filled(
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.redAccent,
                                              minimumSize: const Size(56, 56),
                                            ),
                                            icon: const Icon(
                                              Icons.fiber_manual_record,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                            tooltip: context.translate(
                                              'start_recording',
                                            ),
                                            onPressed: () async {
                                              final success = await practiceProv
                                                  .startRecording();
                                              if (!success && context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      context.translate(
                                                        'mic_error',
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                          ),

                                        // Stop Recording button
                                        if (practiceProv.isRecording)
                                          IconButton.filled(
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.redAccent,
                                              minimumSize: const Size(56, 56),
                                            ),
                                            icon: const Icon(
                                              Icons.stop_rounded,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                            tooltip: context.translate(
                                              'stop_recording',
                                            ),
                                            onPressed:
                                                practiceProv.stopRecording,
                                          ),

                                        // Play snippet button
                                        if (practiceProv.recordedAudioPath !=
                                                null &&
                                            !practiceProv.isPlayingPlayback)
                                          IconButton.filled(
                                            style: IconButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.primaryColor(
                                                    context,
                                                  ),
                                              minimumSize: const Size(50, 50),
                                            ),
                                            icon: Icon(
                                              Icons.play_arrow_rounded,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                              size: 24,
                                            ),
                                            tooltip: context.translate(
                                              'play_recording_btn',
                                            ),
                                            onPressed:
                                                practiceProv.startPlayback,
                                          ),

                                        // Pause snippet playback button
                                        if (practiceProv.isPlayingPlayback)
                                          IconButton.filled(
                                            style: IconButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.surfaceColor(
                                                    context,
                                                  ),
                                              minimumSize: const Size(50, 50),
                                              side: BorderSide(
                                                color: AppTheme.borderColor(
                                                  context,
                                                ),
                                              ),
                                            ),
                                            icon: Icon(
                                              Icons.stop_rounded,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                              size: 24,
                                            ),
                                            tooltip: context.translate(
                                              'stop_playback_btn',
                                            ),
                                            onPressed:
                                                practiceProv.stopPlayback,
                                          ),

                                        if (practiceProv.recordedAudioPath !=
                                            null) ...[
                                          const SizedBox(width: 20),
                                          // Delete snippet button
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.redAccent,
                                              size: 24,
                                            ),
                                            tooltip: context.translate(
                                              'delete_recording',
                                            ),
                                            onPressed:
                                                practiceProv.deleteRecording,
                                          ),
                                        ],
                                      ],
                                    ),

                                    const SizedBox(height: 10),

                                    // Closing the recorder does not change session time.
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            AppTheme.textSecondaryColor(
                                              context,
                                            ),
                                      ),
                                      onPressed: () async {
                                        await practiceProv.closeAudioRecorder();
                                      },
                                      child: Text(
                                        context.translate('close_recorder'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
