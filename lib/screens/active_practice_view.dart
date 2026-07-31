import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/practice_provider.dart';
import '../providers/repertoire_provider.dart';
import '../providers/history_provider.dart';
import '../providers/localization_provider.dart';
import '../models/piece.dart';
import '../theme/app_theme.dart';

class ActivePracticeView extends StatefulWidget {
  const ActivePracticeView({super.key});

  @override
  State<ActivePracticeView> createState() => _ActivePracticeViewState();
}

class _ActivePracticeViewState extends State<ActivePracticeView> {
  bool _isExitDialogVisible = false;

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

  void _confirmEndPractice(
    BuildContext context,
    PracticeProvider practiceProv,
    RepertoireProvider repProv,
  ) {
    practiceProv.pauseSession();
    final locProv = Provider.of<LocalizationProvider>(context, listen: false);
    final historyProv = Provider.of<HistoryProvider>(context, listen: false);
    var isSaving = false;

    showDialog(
      context: context,
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
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: practiceProv.notesController,
                      maxLines: 3,
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
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          try {
                            final record = await practiceProv
                                .prepareSessionRecord(repProv.pieces);
                            if (record == null) {
                              throw StateError('No active session to save.');
                            }
                            await historyProv.saveSession(record);
                            practiceProv.completeSession();
                            if (!mounted || !dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            Navigator.of(context).pop();
                          } catch (error) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  dialogContext.translate('session_save_error'),
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
                style: const TextStyle(color: AppTheme.primaryAccent),
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

  @override
  Widget build(BuildContext context) {
    final practiceProv = Provider.of<PracticeProvider>(context);
    final repProv = Provider.of<RepertoireProvider>(context);
    final isSpanish = Provider.of<LocalizationProvider>(
      context,
      listen: false,
    ).isSpanish;

    final routine = practiceProv.activeRoutine;
    final activeExercise = routine != null && routine.exercises.isNotEmpty
        ? routine.exercises.firstWhere(
            (e) => !practiceProv.completedExerciseIds.contains(e.id),
            orElse: () => routine.exercises.last,
          )
        : null;

    final defaultBpm = activeExercise?.targetBpm ?? 80;

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
          child: SingleChildScrollView(
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
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: practiceProv.isPaused
                                ? AppTheme.border
                                : AppTheme.primaryAccent.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            if (!practiceProv.isPaused)
                              BoxShadow(
                                color: AppTheme.primaryAccent.withValues(
                                  alpha: 0.15,
                                ),
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
                              style: const TextStyle(
                                fontSize: 54,
                                fontWeight: FontWeight.w300,
                                color: AppTheme.textPrimary,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              practiceProv.isPaused
                                  ? context.translate('study_clock_paused')
                                  : context.translate('study_clock_running'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: practiceProv.isPaused
                                    ? AppTheme.textSecondary
                                    : AppTheme.primaryAccent,
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
                                ? AppTheme.primary
                                : AppTheme.cardBg,
                            foregroundColor: practiceProv.isPaused
                                ? Colors.white
                                : AppTheme.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: AppTheme.border,
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.translate('repertoire_tracking_subtitle'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
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
                            decoration: const InputDecoration(
                              prefixIcon: Icon(
                                Icons.library_music_rounded,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text(
                                  context.translate('none_technical_only'),
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
                                final selected = repProv.pieces.firstWhere(
                                  (p) => p.id == val,
                                );
                                practiceProv.selectActivePiece(selected);
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
                              context.translate('exercises_for_routine', [
                                routine.title,
                              ]),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: routine.exercises.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                color: AppTheme.border,
                              ),
                              itemBuilder: (context, idx) {
                                final exercise = routine.exercises[idx];
                                final isCompleted = practiceProv
                                    .completedExerciseIds
                                    .contains(exercise.id);
                                return Material(
                                  type: MaterialType.transparency,
                                  child: CheckboxListTile(
                                    activeColor: AppTheme.primaryAccent,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      exercise.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        decoration: isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: isCompleted
                                            ? AppTheme.textSecondary
                                            : AppTheme.textPrimary,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${_getLocalizedArticulation(context, exercise.articulation)} • ${isSpanish ? 'Objetivo' : 'Target'}: ${exercise.targetBpm} BPM',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    value: isCompleted,
                                    onChanged: (bool? checked) {
                                      practiceProv.toggleExerciseCompleted(
                                        exercise.id,
                                      );
                                    },
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.translate('visual_metronome'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      context.translate('tempo', [
                                        practiceProv.metronomeBpm.toString(),
                                      ]),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
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
                                        color: practiceProv.metronomePulse
                                            ? AppTheme.primaryAccent
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: AppTheme.primaryAccent,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          if (practiceProv.metronomePulse)
                                            BoxShadow(
                                              color: AppTheme.primaryAccent
                                                  .withValues(alpha: 0.8),
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
                                      activeThumbColor: AppTheme.primaryAccent,
                                      value: practiceProv.metronomeOn,
                                      onChanged: (value) {
                                        practiceProv.toggleMetronome(
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
                            Slider(
                              min: 40,
                              max: 240,
                              activeColor: AppTheme.primaryAccent,
                              inactiveColor: AppTheme.border,
                              value: practiceProv.metronomeBpm.toDouble(),
                              onChanged: (double val) {
                                practiceProv.setMetronomeBpm(val.round());
                              },
                            ),
                            const Divider(height: 16, color: AppTheme.border),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    context.translate('metronome_sound'),
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
                                            !practiceProv.metronomeSoundEnabled,
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
                                    color: practiceProv.metronomeSoundEnabled
                                        ? AppTheme.primaryAccent
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            if (practiceProv.metronomeSoundEnabled)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.volume_down_rounded,
                                    size: 18,
                                    color: AppTheme.textSecondary,
                                  ),
                                  Expanded(
                                    child: Slider(
                                      min: 0,
                                      max: 1,
                                      activeColor: AppTheme.primaryAccent,
                                      inactiveColor: AppTheme.border,
                                      value: practiceProv.metronomeVolume,
                                      onChanged: (value) async {
                                        try {
                                          await practiceProv.setMetronomeVolume(
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
                                  const Icon(
                                    Icons.volume_up_rounded,
                                    size: 18,
                                    color: AppTheme.textSecondary,
                                  ),
                                ],
                              ),
                            if (practiceProv.isMetronomeSoundSuppressed)
                              Text(
                                context.translate('metronome_sound_suppressed'),
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),

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
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (kIsWeb) ...[
                            const SizedBox(height: 6),
                            Text(
                              context.translate('recording_web_session_only'),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.primaryAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),

                          if (!practiceProv.isAudioRecorderActive)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppTheme.primaryAccent,
                                ),
                                foregroundColor: AppTheme.primaryAccent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
                                      context.translate('recording_audio'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.redAccent.shade100,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ] else if (practiceProv.isPlayingPlayback) ...[
                              Center(
                                child: Column(
                                  children: [
                                    const SpinKitWave(
                                      color: AppTheme.primaryAccent,
                                      size: 32.0,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      context.translate('playing_back_audio'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.primaryAccent,
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
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.audiotrack_rounded,
                                      color: AppTheme.primaryAccent,
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
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.primaryAccent,
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
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Controls
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Record button (Mic)
                                if (!practiceProv.isRecording &&
                                    practiceProv.recordedAudioPath == null)
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
                                              context.translate('mic_error'),
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
                                    onPressed: practiceProv.stopRecording,
                                  ),

                                // Play snippet button
                                if (practiceProv.recordedAudioPath != null &&
                                    !practiceProv.isPlayingPlayback)
                                  IconButton.filled(
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      minimumSize: const Size(50, 50),
                                    ),
                                    icon: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    tooltip: context.translate(
                                      'play_recording_btn',
                                    ),
                                    onPressed: practiceProv.startPlayback,
                                  ),

                                // Pause snippet playback button
                                if (practiceProv.isPlayingPlayback)
                                  IconButton.filled(
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppTheme.surface,
                                      minimumSize: const Size(50, 50),
                                      side: const BorderSide(
                                        color: AppTheme.border,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.stop_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    tooltip: context.translate(
                                      'stop_playback_btn',
                                    ),
                                    onPressed: practiceProv.stopPlayback,
                                  ),

                                if (practiceProv.recordedAudioPath != null) ...[
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
                                    onPressed: practiceProv.deleteRecording,
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Closing the recorder does not change session time.
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.textSecondary,
                              ),
                              onPressed: () async {
                                await practiceProv.closeAudioRecorder();
                              },
                              child: Text(context.translate('close_recorder')),
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
    );
  }
}
