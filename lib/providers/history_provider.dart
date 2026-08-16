import 'package:flutter/material.dart';
import '../models/session_record.dart';
import '../models/session_recording.dart';
import '../services/database_service.dart';
import '../services/file_storage_service.dart';

class HistoryProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final FileStorageService _storage = FileStorageService();
  List<SessionRecord> _sessions = [];
  bool _isLoading = false;

  List<SessionRecord> get sessions => _sessions;
  bool get isLoading => _isLoading;

  Future<void> loadSessions() async {
    _isLoading = true;
    notifyListeners();
    try {
      _sessions = _db.getSessions();
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
      for (final recording
          in session?.recordings ?? const <SessionRecording>[]) {
        await _storage.deleteManagedFile(recording.storagePath);
      }
      await _db.deleteSession(id);
      await loadSessions();
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
    await _storage.deleteManagedFile(recording.storagePath);
    final updatedRecordings = session.recordings
        .where((item) => item.id != recording.id)
        .toList();
    await saveSession(session.copyWith(recordings: updatedRecordings));
  }

  SessionRecord? _sessionById(String id) {
    for (final session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  // Group sessions by day
  Map<DateTime, List<SessionRecord>> get sessionsByDay {
    final Map<DateTime, List<SessionRecord>> data = {};
    for (final session in _sessions) {
      final localStartTime = session.localStartTime;
      final dateOnly = DateTime(
        localStartTime.year,
        localStartTime.month,
        localStartTime.day,
      );
      if (!data.containsKey(dateOnly)) {
        data[dateOnly] = [];
      }
      data[dateOnly]!.add(session);
    }
    return data;
  }

  List<SessionRecord> getSessionsForDay(DateTime day) {
    final dateOnly = DateTime(day.year, day.month, day.day);
    return sessionsByDay[dateOnly] ?? [];
  }

  // --- STATISTICS ---
  int get totalSessionsCount => _sessions.length;

  int get totalMinutesPracticed {
    final totalSeconds = _sessions.fold<int>(
      0,
      (sum, item) => sum + item.totalDurationInSeconds,
    );
    return totalSeconds ~/ 60;
  }

  int get totalExercisesCompleted {
    return _sessions.fold<int>(
      0,
      (sum, item) => sum + item.completedExercises.length,
    );
  }

  int get thisWeekMinutesPracticed {
    final now = DateTime.now();
    // Find start of week (Monday)
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDate = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );

    final weeklySessions = _sessions.where(
      (s) => !s.localStartTime.isBefore(startOfWeekDate),
    );
    final totalSeconds = weeklySessions.fold<int>(
      0,
      (sum, item) => sum + item.totalDurationInSeconds,
    );
    return totalSeconds ~/ 60;
  }

  int get currentStreak {
    if (_sessions.isEmpty) return 0;

    final sortedDates = _sessions
        .map((s) {
          final localStartTime = s.localStartTime;
          return DateTime.utc(
            localStartTime.year,
            localStartTime.month,
            localStartTime.day,
          );
        })
        .toSet()
        .toList();
    sortedDates.sort(
      (a, b) => b.compareTo(a),
    ); // Descending order (today first)

    final today = DateTime.now();
    final todayDate = DateTime.utc(today.year, today.month, today.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    // If the most recent practice was not today or yesterday, streak is broken (0)
    if (sortedDates.first != todayDate && sortedDates.first != yesterdayDate) {
      return 0;
    }

    int streak = 1;
    for (int i = 0; i < sortedDates.length - 1; i++) {
      final diff = sortedDates[i].difference(sortedDates[i + 1]).inDays;
      if (diff == 1) {
        streak++;
      } else if (diff > 1) {
        break; // Streak broken
      }
    }
    return streak;
  }
}
