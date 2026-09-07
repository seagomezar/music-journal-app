part of 'practice_provider.dart';

extension _PracticeSessionRecovery on PracticeProvider {
  Map<String, dynamic>? _draftSnapshot() {
    if (!_isActive) return null;
    _syncElapsed();
    return {
      'version': 1,
      'sessionId': _sessionId,
      'routine': _activeRoutine?.toJson(),
      'startTime': _startTime!.toIso8601String(),
      'elapsedMilliseconds': _elapsedMilliseconds,
      'completed': _completedExerciseIds.toList(),
      'exerciseDurations': {
        for (final id in {
          ..._exerciseDurationMilliseconds.keys,
          ?_activeExerciseId,
        })
          id: exerciseDurationInSeconds(id) * 1000,
      },
      'exerciseBpms': _exercisePracticedBpms,
      'pitchSummaries': {
        for (final entry in _exercisePitchSummaries.entries)
          entry.key: entry.value.toJson(),
      },
      'pieces': _rehearsedPiecesDuration,
      'measures': _rehearsedMeasures,
      'recordings': _recordings.map((r) => r.toJson()).toList(),
      'pendingRecordingPath': _audioService.pendingRecordingPath,
      'notes': notesController.text,
    };
  }

  void _restoreDraft(Map<String, dynamic> draft) {
    if (draft['version'] != 1) return;
    try {
      final routine = draft['routine'];
      _activeRoutine = routine == null
          ? null
          : Routine.fromJson(Map<String, dynamic>.from(routine as Map));
      _sessionId = draft['sessionId'] as String;
      _startTime = DateTime.parse(draft['startTime'] as String);
      _restoredElapsedMilliseconds = (draft['elapsedMilliseconds'] as int)
          .clamp(0, 86400000);
      _secondsElapsed = _restoredElapsedMilliseconds ~/ 1000;
      _completedExerciseIds.addAll((draft['completed'] as List).cast<String>());
      _exerciseDurationMilliseconds.addAll(
        Map<String, int>.from(draft['exerciseDurations'] as Map),
      );
      _exercisePracticedBpms.addAll(
        Map<String, int>.from(draft['exerciseBpms'] as Map),
      );
      for (final entry in (draft['pitchSummaries'] as Map).entries) {
        _exercisePitchSummaries[entry.key
            as String] = ExercisePitchSummary.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
      _rehearsedPiecesDuration.addAll(
        Map<String, int>.from(draft['pieces'] as Map),
      );
      _rehearsedMeasures.addAll(
        Map<String, int>.from(draft['measures'] as Map? ?? {}),
      );
      _recordings.addAll(
        (draft['recordings'] as List).map(
          (r) => SessionRecording.fromJson(Map<String, dynamic>.from(r as Map)),
        ),
      );
      final pending = draft['pendingRecordingPath'] as String?;
      if (pending != null &&
          !pending.startsWith('recording://') &&
          !_recordings.any((r) => r.storagePath == pending)) {
        _recordings.add(
          SessionRecording(
            id: 'recovered_$_sessionId',
            name: _recordingName(_recordings.length + 1),
            createdAt: _startTime!,
            storagePath: pending,
          ),
        );
      }
      _nextRecordingNumber = _recordings.length + 1;
      notesController.text = draft['notes'] as String;
      _isActive = true;
      _isPaused = true;
      _hasRecoveredSession = true;
    } catch (error) {
      debugPrint('Unable to recover session draft: $error');
      _resetSessionState();
    }
  }
}
