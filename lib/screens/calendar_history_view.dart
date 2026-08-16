import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/history_provider.dart';
import '../providers/localization_provider.dart';
import '../services/audio_service.dart';
import '../services/local_file_availability.dart';
import '../theme/app_theme.dart';
import 'manual_session_screen.dart';

class CalendarHistoryView extends StatefulWidget {
  const CalendarHistoryView({super.key});

  @override
  State<CalendarHistoryView> createState() => _CalendarHistoryViewState();
}

class _CalendarHistoryViewState extends State<CalendarHistoryView> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late final AudioService _playbackService;
  String? _currentlyPlayingPath;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _playbackService = AudioService(
      onPlaybackChanged: (isPlaying) {
        if (!mounted) return;
        setState(() {
          _isPlaying = isPlaying;
          if (!isPlaying) _currentlyPlayingPath = null;
        });
      },
    );
    _selectedDay = _focusedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HistoryProvider>(context, listen: false).loadSessions();
    });
  }

  @override
  void dispose() {
    unawaited(_playbackService.dispose());
    super.dispose();
  }

  String _formatDuration(BuildContext context, int seconds) {
    if (seconds < 60) {
      return context.translate('secs_format', [seconds.toString()]);
    }
    final minutes = seconds ~/ 60;
    return context.translate('mins_format', [minutes.toString()]);
  }

  String _formatTimeOfDay(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  Future<void> _handleAudioPlayback(String path) async {
    try {
      if (!await localFileExists(path)) {
        throw StateError('Recording file not found.');
      }
      if (!mounted) return;
      if (_currentlyPlayingPath == path && _isPlaying) {
        await _playbackService.stopPlayback();
      } else {
        await _playbackService.stopPlayback();
        if (!mounted) return;
        setState(() {
          _currentlyPlayingPath = path;
        });
        await _playbackService.startPlayback(path);
      }
    } catch (e) {
      debugPrint('Playback error: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentlyPlayingPath = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('audio_playback_error'))),
        );
      }
    }
  }

  Future<void> _deleteSession(
    BuildContext context,
    HistoryProvider provider,
    String id,
    String? audioPath,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.translate('delete_session_title')),
        content: Text(dialogContext.translate('delete_session_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.translate('delete_btn')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (_currentlyPlayingPath == audioPath) {
        await _playbackService.stopPlayback();
      }
      await provider.deleteSession(id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('session_delete_error'))),
        );
      }
    }
  }

  Future<void> _openManualSession() async {
    final loggedDate = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(
        builder: (_) =>
            ManualSessionScreen(initialDate: _selectedDay ?? _focusedDay),
      ),
    );
    if (loggedDate == null || !mounted) return;
    setState(() {
      _selectedDay = DateTime(
        loggedDate.year,
        loggedDate.month,
        loggedDate.day,
      );
      _focusedDay = _selectedDay!;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.translate('manual_session_saved'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyProv = Provider.of<HistoryProvider>(context);
    final locProv = Provider.of<LocalizationProvider>(context);
    final localeCode = locProv.localeCode;
    final selectedDaySessions = historyProv.getSessionsForDay(
      _selectedDay ?? _focusedDay,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.translate('practice_history_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'log-past-session',
        onPressed: _openManualSession,
        icon: const Icon(Icons.add_rounded),
        label: Text(context.translate('log_past_session')),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Calendar Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: AppTheme.glassCard(
                padding: const EdgeInsets.all(8.0),
                child: TableCalendar(
                  locale: localeCode,
                  firstDay: DateTime.utc(2000, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },

                  // Dot Marker builders
                  eventLoader: (day) {
                    return historyProv.getSessionsForDay(day);
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isNotEmpty) {
                        return Positioned(
                          bottom: 4,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: events.map((event) {
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.accentColor(context),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }
                      return null;
                    },
                  ),

                  // Calendar Styling
                  headerStyle: HeaderStyle(
                    formatButtonVisible: true,
                    formatButtonDecoration: BoxDecoration(
                      color: AppTheme.primaryColor(
                        context,
                      ).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryColor(context),
                        width: 0.5,
                      ),
                    ),
                    formatButtonTextStyle: TextStyle(
                      color: AppTheme.accentColor(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    titleCentered: true,
                    titleTextStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppTheme.primaryColor(
                        context,
                      ).withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryColor(context),
                        width: 1,
                      ),
                    ),
                    selectedDecoration: BoxDecoration(
                      color: AppTheme.secondaryColor(context),
                      shape: BoxShape.circle,
                    ),
                    weekendTextStyle: const TextStyle(color: Colors.redAccent),
                    outsideDaysVisible: false,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Sessions Section Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Icon(
                    Icons.history_edu_rounded,
                    color: AppTheme.accentColor(context),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.translate('sessions_on_date', [
                        DateFormat(
                          'MMMM d, yyyy',
                          localeCode,
                        ).format(_selectedDay ?? _focusedDay),
                      ]),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.translate('recorded_count_format', [
                      selectedDaySessions.length.toString(),
                    ]),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Intraday Multi-Session List
            Expanded(
              child: selectedDaySessions.isEmpty
                  ? Center(
                      child: Text(
                        context.translate('no_sessions_on_day'),
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor(
                            context,
                          ).withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: selectedDaySessions.length,
                      itemBuilder: (context, index) {
                        final session = selectedDaySessions[index];
                        final isSessionPlaying =
                            _currentlyPlayingPath == session.audioFilePath &&
                            _isPlaying;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          color: AppTheme.surfaceColor(context),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Time & Duration Header
                                Row(
                                  children: [
                                    Icon(
                                      Icons.watch_later_outlined,
                                      size: 16,
                                      color: AppTheme.textSecondaryColor(
                                        context,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${_formatTimeOfDay(session.localStartTime)} - ${_formatTimeOfDay(session.localEndTime)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor(
                                          context,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _formatDuration(
                                          context,
                                          session.totalDurationInSeconds,
                                        ),
                                        style: TextStyle(
                                          color: AppTheme.accentColor(context),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: context.translate(
                                        'delete_session_title',
                                      ),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                      onPressed: () => _deleteSession(
                                        context,
                                        historyProv,
                                        session.id,
                                        session.audioFilePath,
                                      ),
                                    ),
                                  ],
                                ),

                                Divider(
                                  height: 20,
                                  color: AppTheme.borderColor(context),
                                ),

                                // Exercises Done
                                if (session.completedExercises.isNotEmpty ||
                                    session.exerciseResults.isNotEmpty) ...[
                                  Text(
                                    context.translate(
                                      'technical_exercises_completed_title',
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppTheme.accentColor(context),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      ...session.exerciseResults.map((result) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentColor(
                                              context,
                                            ).withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.accentColor(
                                                context,
                                              ).withValues(alpha: 0.25),
                                            ),
                                          ),
                                          child: Text(
                                            context.translate(
                                              result.pitchSummary != null &&
                                                      result
                                                          .pitchSummary!
                                                          .hasEnoughData
                                                  ? 'exercise_result_with_pitch_format'
                                                  : 'exercise_result_format',
                                              result.pitchSummary != null &&
                                                      result
                                                          .pitchSummary!
                                                          .hasEnoughData
                                                  ? [
                                                      result.exercise.name,
                                                      _formatDuration(
                                                        context,
                                                        result
                                                            .durationInSeconds,
                                                      ),
                                                      result.practicedBpm
                                                          .toString(),
                                                      result
                                                          .pitchSummary!
                                                          .onPitchPercentage
                                                          .round()
                                                          .toString(),
                                                      _formatDuration(
                                                        context,
                                                        result
                                                                .pitchSummary!
                                                                .analyzedMilliseconds ~/
                                                            1000,
                                                      ),
                                                      result
                                                          .pitchSummary!
                                                          .referenceHz
                                                          .toString(),
                                                      result
                                                          .pitchSummary!
                                                          .toleranceCents
                                                          .toString(),
                                                    ]
                                                  : [
                                                      result.exercise.name,
                                                      _formatDuration(
                                                        context,
                                                        result
                                                            .durationInSeconds,
                                                      ),
                                                      result.practicedBpm
                                                          .toString(),
                                                    ],
                                            ),
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        );
                                      }),
                                      ...session.completedExercises
                                          .where(
                                            (exercise) =>
                                                !session.exerciseResults.any(
                                                  (result) =>
                                                      result.exercise.id ==
                                                      exercise.id,
                                                ),
                                          )
                                          .map((ex) {
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.borderColor(
                                                  context,
                                                ).withValues(alpha: 0.4),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: AppTheme.borderColor(
                                                    context,
                                                  ).withValues(alpha: 0.5),
                                                ),
                                              ),
                                              child: Text(
                                                '${ex.name} (${ex.targetBpm} BPM ${ex.articulation})',
                                                style: TextStyle(fontSize: 11),
                                              ),
                                            );
                                          }),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Pieces Rehearsed
                                if (session.rehearsedPieces.isNotEmpty) ...[
                                  Text(
                                    context.translate(
                                      'repertoire_rehearsed_title',
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppTheme.secondaryColor(context),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Column(
                                    children: session.rehearsedPieces.map((
                                      piece,
                                    ) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2.0,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.music_note_rounded,
                                              size: 14,
                                              color:
                                                  AppTheme.textSecondaryColor(
                                                    context,
                                                  ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                piece.pieceTitle,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              context
                                                  .translate('spent_duration', [
                                                    _formatDuration(
                                                      context,
                                                      piece.durationInSeconds,
                                                    ),
                                                  ]),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    AppTheme.textSecondaryColor(
                                                      context,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Session Notes
                                if (session.notes.isNotEmpty) ...[
                                  Text(
                                    context.translate(
                                      'practice_session_notes_title',
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppTheme.textPrimaryColor(context),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    session.notes,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondaryColor(
                                        context,
                                      ),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Audio Playback
                                if (session.audioFilePath != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.borderColor(
                                        context,
                                      ).withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppTheme.borderColor(
                                          context,
                                        ).withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          tooltip: context.translate(
                                            isSessionPlaying
                                                ? 'stop_playback_btn'
                                                : 'play_recording_btn',
                                          ),
                                          style: IconButton.styleFrom(
                                            backgroundColor: isSessionPlaying
                                                ? AppTheme.primaryColor(context)
                                                : AppTheme.accentColor(context),
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(36, 36),
                                          ),
                                          icon: Icon(
                                            isSessionPlaying
                                                ? Icons.stop_rounded
                                                : Icons.play_arrow_rounded,
                                            size: 20,
                                          ),
                                          onPressed: () => _handleAudioPlayback(
                                            session.audioFilePath!,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                context.translate(
                                                  'recorded_self_evaluation_title',
                                                ),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                isSessionPlaying
                                                    ? context.translate(
                                                        'playing_back_audio',
                                                      )
                                                    : context.translate(
                                                        'audio_attached',
                                                      ),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color:
                                                      AppTheme.textSecondaryColor(
                                                        context,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 72),
          ],
        ),
      ),
    );
  }
}
