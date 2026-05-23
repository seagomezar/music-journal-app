import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/history_provider.dart';
import '../providers/localization_provider.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';

class CalendarHistoryView extends StatefulWidget {
  const CalendarHistoryView({super.key});

  @override
  State<CalendarHistoryView> createState() => _CalendarHistoryViewState();
}

class _CalendarHistoryViewState extends State<CalendarHistoryView> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final AudioService _playbackService = AudioService();
  String? _currentlyPlayingPath;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HistoryProvider>(context, listen: false).loadSessions();
    });
  }

  @override
  void dispose() {
    _playbackService.dispose();
    super.dispose();
  }

  String _formatDuration(BuildContext context, int seconds) {
    if (seconds < 60) return context.translate('secs_format', [seconds.toString()]);
    final minutes = seconds ~/ 60;
    return context.translate('mins_format', [minutes.toString()]);
  }

  String _formatTimeOfDay(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  Future<void> _handleAudioPlayback(String path) async {
    try {
      if (_currentlyPlayingPath == path && _isPlaying) {
        await _playbackService.stopPlayback();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _playbackService.stopPlayback();
        setState(() {
          _currentlyPlayingPath = path;
          _isPlaying = true;
        });
        await _playbackService.startPlayback(path);
      }
    } catch (e) {
      debugPrint('Playback error: $e');
      setState(() {
        _isPlaying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyProv = Provider.of<HistoryProvider>(context);
    final locProv = Provider.of<LocalizationProvider>(context);
    final localeCode = locProv.localeCode;
    final selectedDaySessions = historyProv.getSessionsForDay(_selectedDay ?? _focusedDay);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.translate('practice_history_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                  firstDay: DateTime.utc(2025, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
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
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primaryAccent,
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
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primary, width: 0.5),
                    ),
                    formatButtonTextStyle: const TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold, fontSize: 12),
                    titleCentered: true,
                    titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primary, width: 1),
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppTheme.secondary,
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
                  const Icon(Icons.history_edu_rounded, color: AppTheme.primaryAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.translate('sessions_on_date', [
                        DateFormat('MMMM d, yyyy', localeCode).format(_selectedDay ?? _focusedDay)
                      ]),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.translate('recorded_count_format', [selectedDaySessions.length.toString()]),
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                        style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.7), fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: selectedDaySessions.length,
                      itemBuilder: (context, index) {
                        final session = selectedDaySessions[index];
                        final isSessionPlaying = _currentlyPlayingPath == session.audioFilePath && _isPlaying;
 
                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          color: AppTheme.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Time & Duration Header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.watch_later_outlined, size: 16, color: AppTheme.textSecondary),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${_formatTimeOfDay(session.startTime)} - ${_formatTimeOfDay(session.endTime)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _formatDuration(context, session.totalDurationInSeconds),
                                        style: const TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    )
                                  ],
                                ),
                                
                                const Divider(height: 20, color: AppTheme.border),
 
                                // Exercises Done
                                if (session.completedExercises.isNotEmpty) ...[
                                  Text(
                                    context.translate('technical_exercises_completed_title'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryAccent),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: session.completedExercises.map((ex) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.border.withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppTheme.border.withOpacity(0.5)),
                                        ),
                                        child: Text(
                                          '${ex.name} (${ex.targetBpm} BPM ${ex.articulation})',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 12),
                                ],
 
                                // Pieces Rehearsed
                                if (session.rehearsedPieces.isNotEmpty) ...[
                                  Text(
                                    context.translate('repertoire_rehearsed_title'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.secondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Column(
                                    children: session.rehearsedPieces.map((piece) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.music_note_rounded, size: 14, color: AppTheme.textSecondary),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                piece.pieceTitle,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                            Text(
                                              context.translate('spent_duration', [_formatDuration(context, piece.durationInSeconds)]),
                                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                            )
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
                                    context.translate('practice_session_notes_title'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    session.notes,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                                  ),
                                  const SizedBox(height: 12),
                                ],
 
                                // Audio Playback
                                if (session.audioFilePath != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.border.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.border.withOpacity(0.5)),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          style: IconButton.styleFrom(
                                            backgroundColor: isSessionPlaying ? AppTheme.primary : AppTheme.primaryAccent,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(36, 36),
                                          ),
                                          icon: Icon(isSessionPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 20),
                                          onPressed: () => _handleAudioPlayback(session.audioFilePath!),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                context.translate('recorded_self_evaluation_title'),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                isSessionPlaying
                                                    ? context.translate('playing_back_audio')
                                                    : context.translate('audio_attached'),
                                                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                              )
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  )
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
