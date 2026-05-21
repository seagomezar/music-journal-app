import 'dart:async';
import 'package:flutter/material.dart';
import '../models/routine.dart';
import '../models/exercise.dart';
import '../models/piece.dart';
import '../models/session_record.dart';
import '../services/audio_service.dart';

class PracticeProvider with ChangeNotifier {
  final AudioService _audioService = AudioService();
  
  // Active session variables
  Routine? _activeRoutine;
  DateTime? _startTime;
  bool _isActive = false;
  bool _isPaused = false;
  int _secondsElapsed = 0;
  Timer? _timer;

  // Active exercises completion
  final Set<String> _completedExerciseIds = {};
  
  // Rehearsed pieces tracker (pieceId -> seconds)
  final Map<String, int> _rehearsedPiecesDuration = {};
  String? _activePieceId;
  String? _activePieceTitle;

  // Audio recording
  bool _isAudioRecorderActive = false;
  String? _recordedAudioPath;

  // Metronome variables
  bool _metronomeOn = false;
  int _metronomeBpm = 80;
  Timer? _metronomeTimer;
  bool _metronomePulse = false;

  // Notes
  final TextEditingController notesController = TextEditingController();

  // Getters
  Routine? get activeRoutine => _activeRoutine;
  bool get isActive => _isActive;
  bool get isPaused => _isPaused;
  int get secondsElapsed => _secondsElapsed;
  Set<String> get completedExerciseIds => _completedExerciseIds;
  Map<String, int> get rehearsedPiecesDuration => _rehearsedPiecesDuration;
  String? get activePieceId => _activePieceId;
  bool get isAudioRecorderActive => _isAudioRecorderActive;
  String? get recordedAudioPath => _recordedAudioPath;
  
  bool get isRecording => _audioService.isRecording;
  bool get isPlayingPlayback => _audioService.isPlaying;
  
  bool get metronomeOn => _metronomeOn;
  int get metronomeBpm => _metronomeBpm;
  bool get metronomePulse => _metronomePulse;

  // Action methods
  void startSession(Routine? routine) {
    _activeRoutine = routine;
    _startTime = DateTime.now();
    _isActive = true;
    _isPaused = false;
    _secondsElapsed = 0;
    _completedExerciseIds.clear();
    _rehearsedPiecesDuration.clear();
    _activePieceId = null;
    _activePieceTitle = null;
    _isAudioRecorderActive = false;
    _recordedAudioPath = null;
    notesController.clear();
    
    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        _secondsElapsed++;
        
        // Accumulate duration for the active piece if one is selected
        if (_activePieceId != null) {
          _rehearsedPiecesDuration[_activePieceId!] = (_rehearsedPiecesDuration[_activePieceId!] ?? 0) + 1;
        }
        
        notifyListeners();
      }
    });
  }

  void pauseSession() {
    _isPaused = true;
    _timer?.cancel();
    _stopMetronome();
    notifyListeners();
  }

  void resumeSession() {
    _isPaused = false;
    _isAudioRecorderActive = false; // Stop audio record panel when resuming session
    _startTimer();
    notifyListeners();
  }

  void selectActivePiece(Piece? piece) {
    if (piece == null) {
      _activePieceId = null;
      _activePieceTitle = null;
    } else {
      _activePieceId = piece.id;
      _activePieceTitle = piece.title;
      if (!_rehearsedPiecesDuration.containsKey(piece.id)) {
        _rehearsedPiecesDuration[piece.id] = 0;
      }
    }
    notifyListeners();
  }

  void toggleExerciseCompleted(String id) {
    if (_completedExerciseIds.contains(id)) {
      _completedExerciseIds.remove(id);
    } else {
      _completedExerciseIds.add(id);
    }
    notifyListeners();
  }

  // --- AUDIO SELF EVALUATION RECORDER ---
  void activateAudioRecorder() {
    pauseSession();
    _isAudioRecorderActive = true;
    notifyListeners();
  }

  Future<void> startRecording() async {
    try {
      await _audioService.startRecording();
    } catch (e) {
      debugPrint('Error starting recording in provider: $e');
    }
    notifyListeners();
  }

  Future<void> stopRecording() async {
    final path = await _audioService.stopRecording();
    if (path != null) {
      _recordedAudioPath = path;
    }
    notifyListeners();
  }

  Future<void> startPlayback() async {
    if (_recordedAudioPath != null) {
      try {
        await _audioService.startPlayback(_recordedAudioPath!);
      } catch (e) {
        debugPrint('Playback error: $e');
      }
      notifyListeners();
    }
  }

  Future<void> stopPlayback() async {
    await _audioService.stopPlayback();
    notifyListeners();
  }

  void deleteRecording() {
    _recordedAudioPath = null;
    notifyListeners();
  }

  // --- METRONOME ---
  void toggleMetronome(int defaultBpm) {
    if (_metronomeOn) {
      _stopMetronome();
    } else {
      _metronomeBpm = defaultBpm > 0 ? defaultBpm : 80;
      _startMetronome();
    }
  }

  void setMetronomeBpm(int bpm) {
    _metronomeBpm = bpm;
    if (_metronomeOn) {
      _startMetronome(); // Restart timer with new tempo
    }
    notifyListeners();
  }

  void _startMetronome() {
    _metronomeTimer?.cancel();
    _metronomeOn = true;
    final intervalMs = (60000 / _metronomeBpm).round();
    _metronomeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      _metronomePulse = !_metronomePulse;
      notifyListeners();
    });
    notifyListeners();
  }

  void _stopMetronome() {
    _metronomeOn = false;
    _metronomeTimer?.cancel();
    _metronomePulse = false;
    notifyListeners();
  }

  // --- SAVE SESSION ---
  SessionRecord? endAndSaveSession(List<Piece> allPieces) {
    if (!_isActive) return null;
    
    _timer?.cancel();
    _stopMetronome();
    _audioService.stopPlayback();
    
    final endTime = DateTime.now();
    final startTime = _startTime ?? endTime.subtract(Duration(seconds: _secondsElapsed));
    
    // Resolve completed exercises
    final completedList = <Exercise>[];
    if (_activeRoutine != null) {
      for (final ex in _activeRoutine!.exercises) {
        if (_completedExerciseIds.contains(ex.id)) {
          completedList.add(ex);
        }
      }
    }

    // Resolve rehearsed pieces
    final rehearsedList = <SessionPieceRecord>[];
    _rehearsedPiecesDuration.forEach((id, duration) {
      final piece = allPieces.firstWhere((p) => p.id == id, 
        orElse: () => Piece(id: id, title: _activePieceTitle ?? 'Untitled', composer: '', targetBpm: 80)
      );
      rehearsedList.add(SessionPieceRecord(
        pieceId: id,
        pieceTitle: piece.title,
        durationInSeconds: duration,
        measuresWorked: piece.measuresCompleted,
      ));
    });

    final record = SessionRecord(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      startTime: startTime,
      endTime: endTime,
      totalDurationInSeconds: _secondsElapsed,
      completedExercises: completedList,
      rehearsedPieces: rehearsedList,
      notes: notesController.text,
      audioFilePath: _recordedAudioPath,
    );

    // Reset state
    _isActive = false;
    _isPaused = false;
    _activeRoutine = null;
    _secondsElapsed = 0;
    _completedExerciseIds.clear();
    _rehearsedPiecesDuration.clear();
    _activePieceId = null;
    _activePieceTitle = null;
    _isAudioRecorderActive = false;
    _recordedAudioPath = null;
    notesController.clear();

    return record;
  }

  void cancelSession() {
    _timer?.cancel();
    _stopMetronome();
    _audioService.stopPlayback();
    
    _isActive = false;
    _isPaused = false;
    _activeRoutine = null;
    _secondsElapsed = 0;
    _completedExerciseIds.clear();
    _rehearsedPiecesDuration.clear();
    _activePieceId = null;
    _isAudioRecorderActive = false;
    _recordedAudioPath = null;
    notesController.clear();
    
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _metronomeTimer?.cancel();
    _audioService.dispose();
    notesController.dispose();
    super.dispose();
  }
}
