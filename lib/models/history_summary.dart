import 'session_record.dart';

/// Derived data, rebuilt only when the journal changes.
class HistorySummary {
  HistorySummary(List<SessionRecord> sessions) {
    for (final session in sessions) {
      final start = session.localStartTime;
      final day = DateTime(start.year, start.month, start.day);
      (byDay[day] ??= []).add(session);
      secondsByDay[day] =
          (secondsByDay[day] ?? 0) + session.totalDurationInSeconds;
      totalSeconds += session.totalDurationInSeconds;
      exerciseCount += session.completedExercises.length;
      for (final result in session.exerciseResults) {
        (exercises[result.exercise.id] ??= []).add(result);
      }
    }
  }
  final Map<DateTime, List<SessionRecord>> byDay = {};
  final Map<DateTime, int> secondsByDay = {};
  final Map<String, List<SessionExerciseRecord>> exercises = {};
  int totalSeconds = 0;
  int exerciseCount = 0;
}
