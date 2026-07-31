import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/routine.dart';
import '../models/exercise.dart';
import '../models/piece.dart';
import '../models/session_record.dart';
import '../services/audio_service.dart';

class PracticeProvider with ChangeNotifier, WidgetsBindingObserver {
  PracticeProvider({AudioService? audioService})
    : _audioService = audioService ?? AudioService() {
    _audioService.onPlaybackChanged = (_) {
      if (!_isDisposed) notifyListeners();
    };
    WidgetsBinding.instance.addObserver(this);
  }

  final AudioService _audioService;
  bool _isDisposed = false;

  // Active session variables
  Routine? _activeRoutine;
  DateTime? _startTime;
  bool _isActive = false;
  bool _isPaused = false;
  int _secondsElapsed = 0;
  Timer? _timer;
  final Stopwatch _activeStopwatch = Stopwatch();

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
    if (_isActive) return;
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

    _activeStopwatch
      ..reset()
      ..start();
    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!_isPaused && _syncElapsed()) {
        notifyListeners();
      }
    });
  }

  bool _syncElapsed() {
    final elapsed = _activeStopwatch.elapsed.inSeconds;
    final delta = elapsed - _secondsElapsed;
    if (delta <= 0) return false;
    _secondsElapsed = elapsed;
    if (_activePieceId != null) {
      _rehearsedPiecesDuration[_activePieceId!] =
          (_rehearsedPiecesDuration[_activePieceId!] ?? 0) + delta;
    }
    return true;
  }

  void pauseSession() {
    if (!_isActive || _isPaused) return;
    _syncElapsed();
    _isPaused = true;
    _activeStopwatch.stop();
    _timer?.cancel();
    _stopMetronome();
    notifyListeners();
  }

  Future<void> resumeSession() async {
    if (!_isActive) return;
    await stopRecording();
    await stopPlayback();
    _isPaused = false;
    _isAudioRecorderActive = false;
    _activeStopwatch.start();
    _startTimer();
    notifyListeners();
  }

  void selectActivePiece(Piece? piece) {
    _syncElapsed();
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

  Future<bool> startRecording() async {
    try {
      await _audioService.startRecording();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error starting recording in provider: $e');
      notifyListeners();
      return false;
    }
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

  Future<void> deleteRecording() async {
    await _audioService.deleteRecording(_recordedAudioPath);
    _recordedAudioPath = null;
    notifyListeners();
  }

  // --- METRONOME ---
  void toggleMetronome(int defaultBpm) {
    if (_metronomeOn) {
      _stopMetronome();
    } else {
      _metronomeBpm = defaultBpm.clamp(40, 240).toInt();
      _startMetronome();
    }
  }

  void setMetronomeBpm(int bpm) {
    _metronomeBpm = bpm.clamp(40, 240).toInt();
    if (_metronomeOn) {
      _startMetronome(); // Restart timer with new tempo
    }
    notifyListeners();
  }

  void _startMetronome() {
    _metronomeTimer?.cancel();
    _metronomeOn = true;
    final intervalMs = (60000 / _metronomeBpm).round();
    _metronomeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (
      timer,
    ) {
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
  Future<SessionRecord?> prepareSessionRecord(List<Piece> allPieces) async {
    if (!_isActive) return null;

    pauseSession();
    await stopRecording();
    await stopPlayback();
    _timer?.cancel();
    _stopMetronome();

    final endTime = DateTime.now();
    final startTime =
        _startTime ?? endTime.subtract(Duration(seconds: _secondsElapsed));

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
      final piece = allPieces.firstWhere(
        (p) => p.id == id,
        orElse: () => Piece(
          id: id,
          title: _activePieceTitle ?? 'Untitled',
          composer: '',
          targetBpm: 80,
        ),
      );
      rehearsedList.add(
        SessionPieceRecord(
          pieceId: id,
          pieceTitle: piece.title,
          durationInSeconds: duration,
          measuresWorked: 0,
        ),
      );
    });

    final record = SessionRecord(
      id: 'session_${const Uuid().v7()}',
      startTime: startTime,
      endTime: endTime,
      totalDurationInSeconds: _secondsElapsed,
      completedExercises: completedList,
      rehearsedPieces: rehearsedList,
      notes: notesController.text,
      // Browser recorder URLs are tied to the current page and cannot be
      // restored after a reload, so they must not be persisted to history.
      audioFilePath: kIsWeb ? null : _recordedAudioPath,
    );

    return record;
  }

  void completeSession() {
    _resetSessionState();
    notifyListeners();
  }

  Future<void> cancelSession() async {
    _timer?.cancel();
    _activeStopwatch.stop();
    _stopMetronome();
    await _audioService.deleteRecording(_recordedAudioPath);
    _resetSessionState();
    notifyListeners();
  }

  void _resetSessionState() {
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
    _activeStopwatch.reset();
    _startTime = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isActive) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      pauseSession();
      unawaited(stopRecording());
      unawaited(stopPlayback());
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _metronomeTimer?.cancel();
    _activeStopwatch.stop();
    if (_isActive) {
      unawaited(
        _audioService
            .deleteRecording(_recordedAudioPath)
            .whenComplete(_audioService.dispose),
      );
    } else {
      unawaited(_audioService.dispose());
    }
    notesController.dispose();
    super.dispose();
  }
}
