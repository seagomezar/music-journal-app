import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/routine.dart';
import '../models/exercise.dart';
import '../models/piece.dart';
import '../models/session_record.dart';
import '../services/analytics_service.dart';
import '../models/pitch_tracking.dart';
import '../models/practice_appearance_preferences.dart';
import '../services/audio_service.dart';
import '../services/metronome_audio_service.dart';
import '../services/pitch_tracking_service.dart';
import '../services/screen_awake_service.dart';

class PracticeProvider with ChangeNotifier, WidgetsBindingObserver {
  PracticeProvider({
    AudioService? audioService,
    PitchTrackingService? pitchTrackingService,
    MetronomeAudioController? metronomeAudioController,
    ScreenAwakeController? screenAwakeController,
    Stopwatch? activeStopwatch,
    bool keepScreenAwake = false,
    bool metronomeSoundEnabled = true,
    double metronomeVolume = 0.7,
    int tunerReferenceHz = 440,
    int tunerToleranceCents = 10,
    PracticeVisualMode visualMode = PracticeVisualMode.focused,
    ThemeMode themeMode = ThemeMode.system,
    bool hapticsEnabled = true,
    bool soundCuesEnabled = true,
    bool reducedMotion = false,
    bool showCelebrations = true,
    Future<void> Function(bool)? persistKeepScreenAwake,
    Future<void> Function(bool)? persistMetronomeSound,
    Future<void> Function(double)? persistMetronomeVolume,
    Future<void> Function(int)? persistTunerReference,
    Future<void> Function(int)? persistTunerTolerance,
    Future<void> Function(PracticeVisualMode)? persistVisualMode,
    Future<void> Function(ThemeMode)? persistThemeMode,
    Future<void> Function(bool)? persistHaptics,
    Future<void> Function(bool)? persistSoundCues,
    Future<void> Function(bool)? persistReducedMotion,
    Future<void> Function(bool)? persistShowCelebrations,
  }) : _audioService = audioService ?? AudioService(),
       _pitchTracking = pitchTrackingService ?? PitchTrackingService(),
       _metronomeAudio =
           metronomeAudioController ?? NoopMetronomeAudioController(),
       _screenAwake = screenAwakeController ?? NoopScreenAwakeController(),
       _activeStopwatch = activeStopwatch ?? Stopwatch(),
       _keepScreenAwake = keepScreenAwake,
       _metronomeSoundEnabled = metronomeSoundEnabled,
       _metronomeVolume = metronomeVolume.clamp(0.0, 1.0),
       _tunerReferenceHz = tunerReferenceHz.clamp(420, 460),
       _tunerToleranceCents = const {5, 10, 20}.contains(tunerToleranceCents)
           ? tunerToleranceCents
           : 10,
       _visualMode = visualMode,
       _themeMode = themeMode,
       _hapticsEnabled = hapticsEnabled,
       _soundCuesEnabled = soundCuesEnabled,
       _reducedMotion = reducedMotion,
       _showCelebrations = showCelebrations,
       _persistKeepScreenAwake = persistKeepScreenAwake,
       _persistMetronomeSound = persistMetronomeSound,
       _persistMetronomeVolume = persistMetronomeVolume,
       _persistTunerReference = persistTunerReference,
       _persistTunerTolerance = persistTunerTolerance,
       _persistVisualMode = persistVisualMode,
       _persistThemeMode = persistThemeMode,
       _persistHaptics = persistHaptics,
       _persistSoundCues = persistSoundCues,
       _persistReducedMotion = persistReducedMotion,
       _persistShowCelebrations = persistShowCelebrations {
    _audioService.onPlaybackChanged = (_) {
      if (_isDisposed) return;
      unawaited(_syncMetronomeAudioSuppression());
      notifyListeners();
    };
    _metronomeAudio.onExternalPlayingChanged = _handleExternalMetronomeState;
    _pitchTracking.onReading = (reading) {
      if (_isDisposed) return;
      _pitchReading = reading;
      notifyListeners();
    };
    WidgetsBinding.instance.addObserver(this);
  }

  final AudioService _audioService;
  final PitchTrackingService _pitchTracking;
  final MetronomeAudioController _metronomeAudio;
  final ScreenAwakeController _screenAwake;
  final Future<void> Function(bool)? _persistKeepScreenAwake;
  final Future<void> Function(bool)? _persistMetronomeSound;
  final Future<void> Function(double)? _persistMetronomeVolume;
  final Future<void> Function(int)? _persistTunerReference;
  final Future<void> Function(int)? _persistTunerTolerance;
  final Future<void> Function(PracticeVisualMode)? _persistVisualMode;
  final Future<void> Function(ThemeMode)? _persistThemeMode;
  final Future<void> Function(bool)? _persistHaptics;
  final Future<void> Function(bool)? _persistSoundCues;
  final Future<void> Function(bool)? _persistReducedMotion;
  final Future<void> Function(bool)? _persistShowCelebrations;
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
  PracticeVisualMode _visualMode;
  ThemeMode _themeMode;
  bool _hapticsEnabled;
  bool _soundCuesEnabled;
  bool _reducedMotion;
  bool _showCelebrations;

  // Active exercises completion
  final Set<String> _completedExerciseIds = {};
  final Map<String, int> _exerciseDurationMilliseconds = {};
  final Map<String, int> _exercisePracticedBpms = {};
  String? _activeExerciseId;
  int? _activeExerciseStartedAtMilliseconds;
  bool _resumeMetronomeAfterSessionPause = false;

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
  Timer? _metronomeVisualTimer;
  Timer? _metronomeTempoTimer;
  bool _metronomePulse = false;
  bool _metronomeSoundEnabled;
  double _metronomeVolume;
  bool _metronomeSoundSuppressed = false;

  // Tuner and per-exercise intonation tracking
  bool _isTunerVisible = true;
  int _tunerReferenceHz;
  int _tunerToleranceCents;
  PitchReading? _pitchReading;
  final Map<String, ExercisePitchSummary> _exercisePitchSummaries = {};
  Future<void>? _pendingPitchStop;

  // Notes
  final TextEditingController notesController = TextEditingController();

  // Getters
  Routine? get activeRoutine => _activeRoutine;
  bool get isActive => _isActive;
  bool get isPaused => _isPaused;
  int get secondsElapsed => _secondsElapsed;
  bool get keepScreenAwake => _keepScreenAwake;
  PracticeVisualMode get visualMode => _visualMode;
  ThemeMode get themeMode => _themeMode;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get soundCuesEnabled => _soundCuesEnabled;
  bool get reducedMotion => _reducedMotion;
  bool get showCelebrations => _showCelebrations;
  Set<String> get completedExerciseIds => _completedExerciseIds;
  String? get activeExerciseId => _activeExerciseId;
  Map<String, int> get exercisePracticedBpms => _exercisePracticedBpms;
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
  bool get isTunerVisible => _isTunerVisible;
  int get tunerReferenceHz => _tunerReferenceHz;
  int get tunerToleranceCents => _tunerToleranceCents;
  PitchReading? get pitchReading => _pitchReading;
  bool get isPitchListening => _pitchTracking.isListening;
  bool get isTrackingPitch =>
      _pitchTracking.isListening &&
      _pitchTracking.mode == PitchCaptureMode.tracking;
  Map<String, ExercisePitchSummary> get exercisePitchSummaries =>
      Map.unmodifiable(_exercisePitchSummaries);
  ExercisePitchSummary? get livePitchSummary => _pitchTracking.currentSummary();

  // Action methods
  Future<void> setVisualMode(PracticeVisualMode mode) async {
    if (_visualMode == mode) return;
    final previous = _visualMode;
    _visualMode = mode;
    notifyListeners();
    try {
      await _persistVisualMode?.call(mode);
    } catch (_) {
      _visualMode = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    final previous = _themeMode;
    _themeMode = mode;
    notifyListeners();
    try {
      await _persistThemeMode?.call(mode);
    } catch (_) {
      _themeMode = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    await _setBooleanPreference(
      value: enabled,
      get: () => _hapticsEnabled,
      set: (value) => _hapticsEnabled = value,
      persist: _persistHaptics,
    );
  }

  Future<void> setSoundCuesEnabled(bool enabled) async {
    await _setBooleanPreference(
      value: enabled,
      get: () => _soundCuesEnabled,
      set: (value) => _soundCuesEnabled = value,
      persist: _persistSoundCues,
    );
  }

  Future<void> setReducedMotion(bool enabled) async {
    await _setBooleanPreference(
      value: enabled,
      get: () => _reducedMotion,
      set: (value) => _reducedMotion = value,
      persist: _persistReducedMotion,
    );
  }

  Future<void> setShowCelebrations(bool enabled) async {
    await _setBooleanPreference(
      value: enabled,
      get: () => _showCelebrations,
      set: (value) => _showCelebrations = value,
      persist: _persistShowCelebrations,
    );
  }

  Future<void> _setBooleanPreference({
    required bool value,
    required bool Function() get,
    required void Function(bool) set,
    required Future<void> Function(bool)? persist,
  }) async {
    if (get() == value) return;
    final previous = get();
    set(value);
    notifyListeners();
    try {
      await persist?.call(value);
    } catch (_) {
      set(previous);
      notifyListeners();
      rethrow;
    }
  }

  void _providePracticeCue({bool strong = false}) {
    if (_hapticsEnabled) {
      unawaited(
        (strong
                ? HapticFeedback.mediumImpact()
                : HapticFeedback.selectionClick())
            .catchError((_) {}),
      );
    }
    if (_soundCuesEnabled) {
      unawaited(SystemSound.play(SystemSoundType.click).catchError((_) {}));
    }
  }

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
    AnalyticsService.track(
      'practice_session_started',
      properties: {'routine': routine == null ? 'quick_start' : 'routine'},
    );
    _activeRoutine = routine;
    _startTime = DateTime.now();
    _isActive = true;
    _isPaused = false;
    _secondsElapsed = 0;
    _completedExerciseIds.clear();
    _exerciseDurationMilliseconds.clear();
    _exercisePracticedBpms.clear();
    _exercisePitchSummaries.clear();
    _activeExerciseId = null;
    _activeExerciseStartedAtMilliseconds = null;
    _resumeMetronomeAfterSessionPause = false;
    _rehearsedPiecesDuration.clear();
    _activePieceId = null;
    _activePieceTitle = null;
    _isAudioRecorderActive = false;
    _recordedAudioPath = null;
    _isTunerVisible = true;
    _pitchReading = null;
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
    _resumeMetronomeAfterSessionPause = _metronomeOn;
    _stopMetronome();
    unawaited(stopPitchCapture());
    unawaited(_applyScreenAwakePreferenceSafely());
    notifyListeners();
  }

  Future<void> resumeSession() async {
    if (!_isActive || !_isPaused) return;
    _isPaused = false;
    _activeStopwatch.start();
    _startTimer();
    if (_resumeMetronomeAfterSessionPause) {
      if (_activeExerciseId != null) {
        _metronomeBpm =
            _exercisePracticedBpms[_activeExerciseId!] ?? _metronomeBpm;
      }
      _startMetronome();
    }
    _resumeMetronomeAfterSessionPause = false;
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

  int exerciseDurationInSeconds(String id) {
    var milliseconds = _exerciseDurationMilliseconds[id] ?? 0;
    if (_activeExerciseId == id &&
        _activeExerciseStartedAtMilliseconds != null) {
      milliseconds +=
          _activeStopwatch.elapsedMilliseconds -
          _activeExerciseStartedAtMilliseconds!;
    }
    return (milliseconds ~/ Duration.millisecondsPerSecond).clamp(0, 86400);
  }

  void startExercise(String id, int targetBpm) {
    if (!_isActive || _isPaused || _activeExerciseId == id) return;
    if (_activeExerciseId != null) {
      _finalizeActiveExercise(markCompleted: true);
    }

    final bpm = targetBpm.clamp(40, 240).toInt();
    _activeExerciseId = id;
    _activeExerciseStartedAtMilliseconds = _activeStopwatch.elapsedMilliseconds;
    _exerciseDurationMilliseconds.putIfAbsent(id, () => 0);
    _exercisePracticedBpms[id] = bpm;
    _completedExerciseIds.remove(id);
    _metronomeBpm = bpm;
    if (_metronomeOn) {
      unawaited(_setMetronomeTempoSafely());
      notifyListeners();
    } else {
      _startMetronome();
    }
    _providePracticeCue();
  }

  void stopExercise(String id) {
    if (_activeExerciseId != id) return;
    _finalizeActiveExercise(markCompleted: true);
    _stopMetronome();
  }

  void setExerciseBpm(String id, int bpm) {
    final nextBpm = bpm.clamp(40, 240).toInt();
    _exercisePracticedBpms[id] = nextBpm;
    final routine = _activeRoutine;
    if (routine != null) {
      _activeRoutine = routine.copyWith(
        exercises: routine.exercises
            .map(
              (exercise) => exercise.id == id
                  ? exercise.copyWith(targetBpm: nextBpm)
                  : exercise,
            )
            .toList(),
      );
    }
    if (_activeExerciseId == id) {
      setMetronomeBpm(nextBpm);
    } else {
      notifyListeners();
    }
  }

  void _finalizeActiveExercise({required bool markCompleted}) {
    final id = _activeExerciseId;
    final startedAt = _activeExerciseStartedAtMilliseconds;
    if (id == null || startedAt == null) return;
    final elapsed = _activeStopwatch.elapsedMilliseconds - startedAt;
    _exerciseDurationMilliseconds[id] =
        (_exerciseDurationMilliseconds[id] ?? 0) + elapsed.clamp(0, 86400000);
    if (markCompleted) _completedExerciseIds.add(id);
    if (markCompleted && _showCelebrations) _providePracticeCue();
    if (isTrackingPitch) unawaited(stopPitchCapture(exerciseId: id));
    _activeExerciseId = null;
    _activeExerciseStartedAtMilliseconds = null;
    _resumeMetronomeAfterSessionPause = false;
    notifyListeners();
  }

  // --- AUDIO SELF EVALUATION RECORDER ---
  void activateAudioRecorder() {
    _isAudioRecorderActive = true;
    notifyListeners();
  }

  Future<bool> startRecording() async {
    await stopPitchCapture();
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

  // --- TUNER AND PITCH TRACKING ---
  Future<void> setTunerVisible(bool visible) async {
    if (_isTunerVisible == visible) return;
    if (!visible) await stopPitchCapture();
    _isTunerVisible = visible;
    notifyListeners();
  }

  Future<void> setTunerReferenceHz(int value) async {
    if (isPitchListening) return;
    final next = value.clamp(420, 460);
    if (next == _tunerReferenceHz) return;
    final previous = _tunerReferenceHz;
    _tunerReferenceHz = next;
    notifyListeners();
    try {
      await _persistTunerReference?.call(next);
    } catch (_) {
      _tunerReferenceHz = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setTunerToleranceCents(int value) async {
    if (isPitchListening || !const {5, 10, 20}.contains(value)) return;
    if (value == _tunerToleranceCents) return;
    final previous = _tunerToleranceCents;
    _tunerToleranceCents = value;
    notifyListeners();
    try {
      await _persistTunerTolerance?.call(value);
    } catch (_) {
      _tunerToleranceCents = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> startPitchCapture({required bool trackExercise}) async {
    if (!_isActive || _isPaused || isRecording || isPlayingPlayback) {
      return false;
    }
    if (trackExercise && _activeExerciseId == null) return false;
    await stopPitchCapture();
    try {
      await _pitchTracking.start(
        mode: trackExercise
            ? PitchCaptureMode.tracking
            : PitchCaptureMode.tuning,
        referenceHz: _tunerReferenceHz,
        toleranceCents: _tunerToleranceCents,
        excludeFrame: _isMetronomeClickWindow,
      );
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('Unable to start pitch tracking: $error');
      notifyListeners();
      return false;
    }
  }

  bool _isMetronomeClickWindow() {
    if (!_metronomeOn ||
        !_metronomeSoundEnabled ||
        _metronomeSoundSuppressed ||
        _metronomeVolume == 0) {
      return false;
    }
    final snapshot = _metronomeAudio.clockSnapshot;
    return snapshot != null &&
        snapshot.phase < const Duration(milliseconds: 80);
  }

  Future<void> stopPitchCapture({String? exerciseId}) async {
    final pending = _pendingPitchStop;
    if (pending != null) {
      await pending;
      return;
    }
    final stop = _stopPitchCaptureInternal(exerciseId: exerciseId);
    _pendingPitchStop = stop;
    try {
      await stop;
    } finally {
      _pendingPitchStop = null;
    }
  }

  Future<void> _stopPitchCaptureInternal({String? exerciseId}) async {
    if (!_pitchTracking.isListening && _pitchTracking.mode == null) return;
    final trackedId =
        exerciseId ??
        (_pitchTracking.mode == PitchCaptureMode.tracking
            ? _activeExerciseId
            : null);
    final summary = await _pitchTracking.stop();
    if (trackedId != null && summary != null) {
      _exercisePitchSummaries[trackedId] = summary;
    }
    _pitchReading = null;
    if (!_isDisposed) notifyListeners();
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
    if (_metronomeOn) {
      try {
        await _metronomeAudio.setVolume(
          suppressed || !_metronomeSoundEnabled ? 0 : _metronomeVolume,
        );
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
      _metronomeTempoTimer?.cancel();
      _metronomeTempoTimer = Timer(
        const Duration(milliseconds: 120),
        () => unawaited(_setMetronomeTempoSafely()),
      );
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
        await _metronomeAudio.setVolume(
          enabled && !_metronomeSoundSuppressed ? _metronomeVolume : 0,
        );
      }
      await _persistMetronomeSound?.call(enabled);
    } catch (error) {
      _metronomeSoundEnabled = previous;
      if (_metronomeOn) {
        await _metronomeAudio.setVolume(
          previous && !_metronomeSoundSuppressed ? _metronomeVolume : 0,
        );
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
      if (_metronomeOn) {
        await _metronomeAudio.setVolume(
          _metronomeSoundSuppressed || !_metronomeSoundEnabled ? 0 : nextVolume,
        );
      }
      await _persistMetronomeVolume?.call(nextVolume);
    } catch (error) {
      _metronomeVolume = previous;
      if (_metronomeOn) {
        await _metronomeAudio.setVolume(
          _metronomeSoundSuppressed || !_metronomeSoundEnabled ? 0 : previous,
        );
      }
      notifyListeners();
      rethrow;
    }
  }

  void _startMetronome() {
    _metronomeOn = true;
    _restartMetronomeVisual();
    unawaited(_startMetronomeAudioSafely());
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
    _refreshMetronomeVisual();
    _metronomeVisualTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _refreshMetronomeVisual(),
    );
  }

  void _refreshMetronomeVisual() {
    if (!_metronomeOn || !_isInForeground || _isDisposed) return;
    final snapshot = _metronomeAudio.clockSnapshot;
    final nextPulse =
        snapshot != null && snapshot.phase < const Duration(milliseconds: 90);
    if (_metronomePulse == nextPulse) return;
    _metronomePulse = nextPulse;
    notifyListeners();
  }

  void _stopMetronomeVisual() {
    _metronomeVisualTimer?.cancel();
    _metronomeTempoTimer?.cancel();
    _metronomePulse = false;
  }

  Future<void> _startMetronomeAudio() {
    return _metronomeAudio.start(
      bpm: _metronomeBpm,
      volume: _metronomeSoundSuppressed || !_metronomeSoundEnabled
          ? 0
          : _metronomeVolume,
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

  Future<void> resetPreferences() async {
    if (_isDisposed) return;
    _keepScreenAwake = false;
    _metronomeSoundEnabled = true;
    _metronomeVolume = 0.7;
    _tunerReferenceHz = 440;
    _tunerToleranceCents = 10;
    _visualMode = PracticeVisualMode.focused;
    _themeMode = ThemeMode.system;
    _hapticsEnabled = true;
    _soundCuesEnabled = true;
    _reducedMotion = false;
    _showCelebrations = true;
    _metronomeSoundSuppressed = false;
    _metronomeTempoTimer?.cancel();
    _stopMetronomeVisual();
    try {
      await _screenAwake.setEnabled(false);
    } catch (error) {
      debugPrint('Unable to reset the screen-awake preference: $error');
    }
    notifyListeners();
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
    _finalizeActiveExercise(markCompleted: true);
    await stopPitchCapture();
    await stopRecording();
    await stopPlayback();
    _timer?.cancel();
    _stopMetronome();

    final endTime = DateTime.now();
    final startTime =
        _startTime ?? endTime.subtract(Duration(seconds: _secondsElapsed));

    // Resolve completed exercises
    final completedList = <Exercise>[];
    final exerciseResults = <SessionExerciseRecord>[];
    if (_activeRoutine != null) {
      for (final ex in _activeRoutine!.exercises) {
        if (_completedExerciseIds.contains(ex.id)) {
          completedList.add(ex);
        }
        if (_exerciseDurationMilliseconds.containsKey(ex.id)) {
          exerciseResults.add(
            SessionExerciseRecord(
              exercise: ex,
              durationInSeconds: exerciseDurationInSeconds(ex.id),
              practicedBpm: _exercisePracticedBpms[ex.id] ?? ex.targetBpm,
              pitchSummary: _exercisePitchSummaries[ex.id],
            ),
          );
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
      exerciseResults: exerciseResults,
      rehearsedPieces: rehearsedList,
      notes: notesController.text,
      // Browser recorder URLs are tied to the current page and cannot be
      // restored after a reload, so they must not be persisted to history.
      audioFilePath: kIsWeb ? null : _recordedAudioPath,
    );

    return record;
  }

  void completeSession() {
    if (_showCelebrations) _providePracticeCue(strong: true);
    _resetSessionState();
    unawaited(_applyScreenAwakePreferenceSafely());
    notifyListeners();
  }

  Future<void> cancelSession() async {
    _timer?.cancel();
    _activeStopwatch.stop();
    _stopMetronome();
    await stopPitchCapture();
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
    _exerciseDurationMilliseconds.clear();
    _exercisePracticedBpms.clear();
    _exercisePitchSummaries.clear();
    _activeExerciseId = null;
    _activeExerciseStartedAtMilliseconds = null;
    _resumeMetronomeAfterSessionPause = false;
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
      unawaited(stopPitchCapture());
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
      unawaited(stopPitchCapture());
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _metronomeVisualTimer?.cancel();
    _metronomeTempoTimer?.cancel();
    _activeStopwatch.stop();
    _metronomeAudio.onExternalPlayingChanged = null;
    _pitchTracking.onReading = null;
    unawaited(_stopMetronomeAudioSafely());
    unawaited(_disableScreenAwakeSafely());
    unawaited(_pitchTracking.dispose());
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
