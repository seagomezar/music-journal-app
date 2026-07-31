import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/routine.dart';
import '../models/exercise.dart';
import '../models/piece.dart';
import '../models/session_record.dart';
import '../services/audio_service.dart';
import '../services/metronome_audio_service.dart';
import '../services/screen_awake_service.dart';

class PracticeProvider with ChangeNotifier, WidgetsBindingObserver {
  PracticeProvider({
    AudioService? audioService,
    MetronomeAudioController? metronomeAudioController,
    ScreenAwakeController? screenAwakeController,
    Stopwatch? activeStopwatch,
    bool keepScreenAwake = false,
    bool metronomeSoundEnabled = true,
    double metronomeVolume = 0.7,
    Future<void> Function(bool)? persistKeepScreenAwake,
    Future<void> Function(bool)? persistMetronomeSound,
    Future<void> Function(double)? persistMetronomeVolume,
  }) : _audioService = audioService ?? AudioService(),
       _metronomeAudio =
           metronomeAudioController ?? NoopMetronomeAudioController(),
       _screenAwake = screenAwakeController ?? NoopScreenAwakeController(),
       _activeStopwatch = activeStopwatch ?? Stopwatch(),
       _keepScreenAwake = keepScreenAwake,
       _metronomeSoundEnabled = metronomeSoundEnabled,
       _metronomeVolume = metronomeVolume.clamp(0.0, 1.0),
       _persistKeepScreenAwake = persistKeepScreenAwake,
       _persistMetronomeSound = persistMetronomeSound,
       _persistMetronomeVolume = persistMetronomeVolume {
    _audioService.onPlaybackChanged = (_) {
      if (_isDisposed) return;
      unawaited(_syncMetronomeAudioSuppression());
      notifyListeners();
    };
    _metronomeAudio.onExternalPlayingChanged = _handleExternalMetronomeState;
    WidgetsBinding.instance.addObserver(this);
  }

  final AudioService _audioService;
  final MetronomeAudioController _metronomeAudio;
  final ScreenAwakeController _screenAwake;
  final Future<void> Function(bool)? _persistKeepScreenAwake;
  final Future<void> Function(bool)? _persistMetronomeSound;
  final Future<void> Function(double)? _persistMetronomeVolume;
  bool _isDisposed = false;
  bool _isInForeground = true;

  // Active session variables
  Routine? _activeRoutine;
  DateTime? _startTime;
  bool _isActive = false;
  bool _isPaused = false;
  int _secondsElapsed = 0;
  Timer? _timer;
  final Stopwatch _activeStopwatch;
  bool _keepScreenAwake;

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
  Timer? _metronomeBeatTimer;
  Timer? _metronomePulseTimer;
  Timer? _metronomeTempoTimer;
  final Stopwatch _metronomeStopwatch = Stopwatch();
  int _nextMetronomeBeat = 0;
  bool _metronomePulse = false;
  bool _metronomeSoundEnabled;
  double _metronomeVolume;
  bool _metronomeSoundSuppressed = false;

  // Notes
  final TextEditingController notesController = TextEditingController();

  // Getters
  Routine? get activeRoutine => _activeRoutine;
  bool get isActive => _isActive;
  bool get isPaused => _isPaused;
  int get secondsElapsed => _secondsElapsed;
  bool get keepScreenAwake => _keepScreenAwake;
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
  bool get metronomeSoundEnabled => _metronomeSoundEnabled;
  double get metronomeVolume => _metronomeVolume;
  bool get isMetronomeSoundSuppressed => _metronomeSoundSuppressed;

  // Action methods
  Future<void> setKeepScreenAwake(bool enabled) async {
    if (_keepScreenAwake == enabled) return;
    final previous = _keepScreenAwake;
    _keepScreenAwake = enabled;
    notifyListeners();
    try {
      await _applyScreenAwakePreference();
      await _persistKeepScreenAwake?.call(enabled);
    } catch (error) {
      _keepScreenAwake = previous;
      await _applyScreenAwakePreference();
      notifyListeners();
      rethrow;
    }
  }

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
    unawaited(_applyScreenAwakePreferenceSafely());
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    if (!_isInForeground || _isPaused || !_isActive) return;
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
    unawaited(_applyScreenAwakePreferenceSafely());
    notifyListeners();
  }

  Future<void> resumeSession() async {
    if (!_isActive || !_isPaused) return;
    _isPaused = false;
    _activeStopwatch.start();
    _startTimer();
    await _applyScreenAwakePreferenceSafely();
    notifyListeners();
  }

  Future<void> _applyScreenAwakePreference() {
    return _screenAwake.setEnabled(
      _keepScreenAwake && _isActive && _isInForeground,
    );
  }

  Future<void> _applyScreenAwakePreferenceSafely() async {
    try {
      await _applyScreenAwakePreference();
    } catch (error) {
      debugPrint('Unable to update the screen-awake preference: $error');
    }
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
    _isAudioRecorderActive = true;
    notifyListeners();
  }

  Future<bool> startRecording() async {
    await _setMetronomeSoundSuppressed(true);
    try {
      await _audioService.startRecording();
      notifyListeners();
      return true;
    } catch (e) {
      await _syncMetronomeAudioSuppression();
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
    await _syncMetronomeAudioSuppression();
    notifyListeners();
  }

  Future<void> startPlayback() async {
    if (_recordedAudioPath != null) {
      await _setMetronomeSoundSuppressed(true);
      try {
        await _audioService.startPlayback(_recordedAudioPath!);
      } catch (e) {
        await _syncMetronomeAudioSuppression();
        debugPrint('Playback error: $e');
      }
      notifyListeners();
    }
  }

  Future<void> stopPlayback() async {
    await _audioService.stopPlayback();
    await _syncMetronomeAudioSuppression();
    notifyListeners();
  }

  Future<void> deleteRecording() async {
    await _audioService.deleteRecording(_recordedAudioPath);
    _recordedAudioPath = null;
    await _syncMetronomeAudioSuppression();
    notifyListeners();
  }

  Future<void> closeAudioRecorder() async {
    await stopRecording();
    await stopPlayback();
    _isAudioRecorderActive = false;
    notifyListeners();
  }

  Future<void> _syncMetronomeAudioSuppression() {
    return _setMetronomeSoundSuppressed(
      _audioService.isRecording || _audioService.isPlaying,
    );
  }

  Future<void> _setMetronomeSoundSuppressed(bool suppressed) async {
    if (_metronomeSoundSuppressed == suppressed) return;
    _metronomeSoundSuppressed = suppressed;
    if (_metronomeOn && _metronomeSoundEnabled) {
      try {
        await _metronomeAudio.setVolume(suppressed ? 0 : _metronomeVolume);
      } catch (error) {
        debugPrint('Unable to update metronome audio suppression: $error');
      }
    }
    if (!_isDisposed) notifyListeners();
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
      _restartMetronomeVisual();
      if (_metronomeSoundEnabled && !_metronomeSoundSuppressed) {
        _metronomeTempoTimer?.cancel();
        _metronomeTempoTimer = Timer(
          const Duration(milliseconds: 120),
          () => unawaited(_setMetronomeTempoSafely()),
        );
      }
    }
    notifyListeners();
  }

  Future<void> setMetronomeSoundEnabled(bool enabled) async {
    if (_metronomeSoundEnabled == enabled) return;
    final previous = _metronomeSoundEnabled;
    _metronomeSoundEnabled = enabled;
    notifyListeners();
    try {
      if (_metronomeOn) {
        if (enabled) {
          await _startMetronomeAudio();
        } else {
          await _metronomeAudio.stop();
        }
      }
      await _persistMetronomeSound?.call(enabled);
    } catch (error) {
      _metronomeSoundEnabled = previous;
      if (_metronomeOn && previous) {
        await _startMetronomeAudio();
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setMetronomeVolume(double volume) async {
    final nextVolume = volume.clamp(0.0, 1.0);
    if (_metronomeVolume == nextVolume) return;
    final previous = _metronomeVolume;
    _metronomeVolume = nextVolume;
    notifyListeners();
    try {
      if (_metronomeOn && _metronomeSoundEnabled) {
        await _metronomeAudio.setVolume(
          _metronomeSoundSuppressed ? 0 : nextVolume,
        );
      }
      await _persistMetronomeVolume?.call(nextVolume);
    } catch (error) {
      _metronomeVolume = previous;
      if (_metronomeOn && _metronomeSoundEnabled) {
        await _metronomeAudio.setVolume(
          _metronomeSoundSuppressed ? 0 : previous,
        );
      }
      notifyListeners();
      rethrow;
    }
  }

  void _startMetronome() {
    _metronomeOn = true;
    _restartMetronomeVisual();
    if (_metronomeSoundEnabled && !_metronomeSoundSuppressed) {
      unawaited(_startMetronomeAudioSafely());
    }
    notifyListeners();
  }

  void _stopMetronome() {
    _metronomeOn = false;
    _metronomeTempoTimer?.cancel();
    _stopMetronomeVisual();
    unawaited(_stopMetronomeAudioSafely());
    notifyListeners();
  }

  void _restartMetronomeVisual() {
    _stopMetronomeVisual();
    if (!_metronomeOn || !_isInForeground) return;
    _nextMetronomeBeat = 0;
    _metronomeStopwatch
      ..reset()
      ..start();
    _emitMetronomeBeat();
  }

  void _emitMetronomeBeat() {
    if (!_metronomeOn || !_isInForeground || _isDisposed) return;
    _metronomePulse = false;
    _metronomePulseTimer?.cancel();
    _metronomePulse = true;
    notifyListeners();
    _metronomePulseTimer = Timer(const Duration(milliseconds: 90), () {
      if (_isDisposed) return;
      _metronomePulse = false;
      notifyListeners();
    });

    _nextMetronomeBeat += 1;
    final targetMicros =
        (_nextMetronomeBeat * Duration.microsecondsPerMinute / _metronomeBpm)
            .round();
    final delayMicros = targetMicros - _metronomeStopwatch.elapsedMicroseconds;
    _metronomeBeatTimer = Timer(
      Duration(microseconds: delayMicros.clamp(0, targetMicros)),
      _emitMetronomeBeat,
    );
  }

  void _stopMetronomeVisual() {
    _metronomeBeatTimer?.cancel();
    _metronomePulseTimer?.cancel();
    _metronomeTempoTimer?.cancel();
    _metronomeStopwatch
      ..stop()
      ..reset();
    _nextMetronomeBeat = 0;
    _metronomePulse = false;
  }

  Future<void> _startMetronomeAudio() {
    return _metronomeAudio.start(
      bpm: _metronomeBpm,
      volume: _metronomeSoundSuppressed ? 0 : _metronomeVolume,
    );
  }

  Future<void> _startMetronomeAudioSafely() async {
    try {
      await _startMetronomeAudio();
    } catch (error) {
      debugPrint('Unable to start metronome audio: $error');
    }
  }

  Future<void> _setMetronomeTempoSafely() async {
    try {
      await _metronomeAudio.setTempo(_metronomeBpm);
    } catch (error) {
      debugPrint('Unable to update metronome tempo: $error');
    }
  }

  Future<void> _stopMetronomeAudioSafely() async {
    try {
      await _metronomeAudio.stop();
    } catch (error) {
      debugPrint('Unable to stop metronome audio: $error');
    }
  }

  void _handleExternalMetronomeState(bool playing) {
    if (_isDisposed || !_isActive || _metronomeOn == playing) return;
    _metronomeOn = playing;
    if (playing) {
      _restartMetronomeVisual();
    } else {
      _stopMetronomeVisual();
    }
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
    unawaited(_applyScreenAwakePreferenceSafely());
    notifyListeners();
  }

  Future<void> cancelSession() async {
    _timer?.cancel();
    _activeStopwatch.stop();
    _stopMetronome();
    await _audioService.deleteRecording(_recordedAudioPath);
    _resetSessionState();
    await _applyScreenAwakePreferenceSafely();
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
    _metronomeOn = false;
    _metronomeSoundSuppressed = false;
    _stopMetronomeVisual();
    notesController.clear();
    _activeStopwatch.reset();
    _startTime = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isInForeground = true;
      if (!_isActive) return;
      if (!_isPaused) {
        _syncElapsed();
        _startTimer();
      }
      if (_metronomeOn) {
        _restartMetronomeVisual();
        if (_metronomeSoundEnabled && !_metronomeSoundSuppressed) {
          unawaited(_startMetronomeAudioSafely());
        }
      }
      unawaited(_applyScreenAwakePreferenceSafely());
      notifyListeners();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _isInForeground = false;
      if (!_isActive) return;
      if (!_isPaused) _syncElapsed();
      _timer?.cancel();
      _stopMetronomeVisual();
      unawaited(_applyScreenAwakePreferenceSafely());
      unawaited(stopRecording());
      unawaited(stopPlayback());
      notifyListeners();
      return;
    }

    if (state == AppLifecycleState.detached) {
      _isInForeground = false;
      if (!_isActive) return;
      _syncElapsed();
      _timer?.cancel();
      _activeStopwatch.stop();
      _stopMetronome();
      unawaited(_applyScreenAwakePreferenceSafely());
      unawaited(stopRecording());
      unawaited(stopPlayback());
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _metronomeBeatTimer?.cancel();
    _metronomePulseTimer?.cancel();
    _activeStopwatch.stop();
    _metronomeStopwatch.stop();
    _metronomeAudio.onExternalPlayingChanged = null;
    unawaited(_stopMetronomeAudioSafely());
    unawaited(_disableScreenAwakeSafely());
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

  Future<void> _disableScreenAwakeSafely() async {
    try {
      await _screenAwake.setEnabled(false);
    } catch (error) {
      debugPrint('Unable to disable the screen-awake preference: $error');
    }
  }
}
