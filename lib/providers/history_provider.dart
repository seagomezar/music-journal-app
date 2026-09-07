import 'package:flutter/material.dart';
import '../models/session_record.dart';
import '../models/session_recording.dart';
import '../services/database_service.dart';
import '../models/history_summary.dart';

class HistoryProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  List<SessionRecord> _sessions = [];
  bool _isLoading = false;
  HistorySummary? _summary;
  HistorySummary get summary => _summary ??= HistorySummary(_sessions);

  List<SessionRecord> get sessions => _sessions;
  bool get isLoading => _isLoading;

  Future<void> loadSessions() async {
    _isLoading = true;
    notifyListeners();
    try {
      _sessions = _db.getSessions();
      _summary = null;
    } catch (e) {
      debugPrint('Error loading sessions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveSession(SessionRecord session) async {
    try {
      await _db.saveSession(session);
      await loadSessions();
    } catch (e) {
      debugPrint('Error saving session: $e');
      rethrow;
    }
  }

  Future<void> deleteSession(String id) async {
    try {
      SessionRecord? session;
      for (final item in _sessions) {
        if (item.id == id) {
          session = item;
          break;
        }
      }
      await _db.scheduleMediaCleanup(
        (session?.recordings ?? const <SessionRecording>[]).map(
          (r) => r.storagePath,
        ),
      );
      await _db.deleteSession(id);
      await loadSessions();
      await _db.retryMediaCleanup();
    } catch (e) {
      debugPrint('Error deleting session: $e');
      rethrow;
    }
  }

  Future<void> renameRecording(
    String sessionId,
    SessionRecording recording,
    String name,
  ) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(name, 'name', 'A recording name is required.');
    }
    final session = _sessionById(sessionId);
    if (session == null) return;
    final updatedRecordings = session.recordings
        .map(
          (item) =>
              item.id == recording.id ? item.copyWith(name: normalized) : item,
        )
        .toList();
    await saveSession(session.copyWith(recordings: updatedRecordings));
  }

  Future<void> deleteRecording(
    String sessionId,
    SessionRecording recording,
  ) async {
    final session = _sessionById(sessionId);
    if (session == null) return;
    final updatedRecordings = session.recordings
        .where((item) => item.id != recording.id)
        .toList();
    await _db.scheduleMediaCleanup([recording.storagePath]);
    await saveSession(session.copyWith(recordings: updatedRecordings));
    await _db.retryMediaCleanup();
  }

  SessionRecord? _sessionById(String id) {
    for (final session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  // Group sessions by day
  Map<DateTime, List<SessionRecord>> get sessionsByDay {
    return summary.byDay;
  }

  List<SessionRecord> getSessionsForDay(DateTime day) {
    final dateOnly = DateTime(day.year, day.month, day.day);
    return sessionsByDay[dateOnly] ?? [];
  }

  // --- STATISTICS ---
  int get totalSessionsCount => _sessions.length;

  int get totalMinutesPracticed {
    return summary.totalSeconds ~/ 60;
  }

  int get totalExercisesCompleted {
    return summary.exerciseCount;
  }

  int get thisWeekMinutesPracticed {
    final now = DateTime.now();
    // Find start of week (Monday)
    final startOfWeekDate = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    );
    var totalSeconds = 0;
    for (var offset = 0; offset < 7; offset++) {
      final day = DateTime(
        startOfWeekDate.year,
        startOfWeekDate.month,
        startOfWeekDate.day + offset,
      );
      totalSeconds += summary.secondsByDay[day] ?? 0;
    }
    return totalSeconds ~/ 60;
  }

  int get currentStreak {
    final today = DateTime.now();
    var day = DateTime(today.year, today.month, today.day);
    if (!summary.byDay.containsKey(day)) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    var streak = 0;
    while (summary.byDay.containsKey(day)) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }
}
