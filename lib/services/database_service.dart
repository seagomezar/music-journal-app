import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import '../models/user_profile.dart';
import '../models/routine.dart';
import '../models/exercise.dart';
import '../models/piece.dart';
import '../models/repertoire_folder.dart';
import '../models/session_record.dart';
import '../models/practice_appearance_preferences.dart';
import '../models/pdf_annotation.dart';
import '../models/score_view_preferences.dart';
import 'file_storage_service.dart';
import 'durable_batch_service.dart';
import 'seed_localization.dart';
import 'package:flutter/material.dart' show ThemeMode;

class DatabaseService {
  static const int _currentSeedVersion = 1;
  static const String _seedVersionKey = 'seed_version';
  static const String _keepScreenAwakeKey = 'keep_screen_awake';
  static const String _metronomeSoundKey = 'metronome_sound';
  static const String _metronomeVolumeKey = 'metronome_volume';
  static const String _tunerReferenceKey = 'tuner_reference_hz';
  static const String _tunerToleranceKey = 'tuner_tolerance_cents';
  static const String _practiceVisualModeKey = 'practice_visual_mode';
  static const String _themeModeKey = 'theme_mode';
  static const String _hapticsKey = 'practice_haptics';
  static const String _soundCuesKey = 'practice_sound_cues';
  static const String _reducedMotionKey = 'practice_reduced_motion';
  static const String _showCelebrationsKey = 'practice_show_celebrations';
  static const String _performanceBrightnessKey = 'performance_brightness';
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late Box _profileBox;
  late Box _routinesBox;
  late Box _repertoireBox;
  late Box _repertoireFoldersBox;
  late Box _pdfAnnotationsBox;
  late Box _scoreViewPreferencesBox;
  late Box _sessionsBox;
  late Box _recoveryBox;
  late DurableBatchService _batch;
  final FileStorageService _storage = FileStorageService();
  final ValueNotifier<Set<String>> damagedRecords = ValueNotifier({});
  final ValueNotifier<bool> needsRecovery = ValueNotifier(false);
  List<SessionRecord>? _sessionCache;

  Map<String, Box> get _boxes => {
    'profile': _profileBox,
    'routines': _routinesBox,
    'repertoire': _repertoireBox,
    'folders': _repertoireFoldersBox,
    'annotations': _pdfAnnotationsBox,
    'scorePreferences': _scoreViewPreferencesBox,
    'sessions': _sessionsBox,
  };

  bool get isInitialized => _isInitialized && _profileBox.isOpen;

  bool _isInitialized = false;
  String _generation = '';
  String? _recoveryGeneration;

  Future<void> initializeRecoveryDatabase() async {
    _isInitialized = false;
    final bootstrap = await Hive.openBox('flute_bootstrap');
    final retained = (bootstrap.get('retained_generations') as List? ?? [])
        .cast<String>();
    _recoveryGeneration = '_recovered_${DateTime.now().microsecondsSinceEpoch}';
    await bootstrap.put(
      'retained_generations',
      {...retained, _generation, _recoveryGeneration!}.toList(),
    );
    await bootstrap.flush();
    await init();
  }

  Future<void> activateRecoveryDatabase() async {
    final bootstrap = await Hive.openBox('flute_bootstrap');
    await bootstrap.put('generation', _generation);
    await bootstrap.flush();
    _recoveryGeneration = null;
  }

  void abandonRecoveryDatabase() {
    _recoveryGeneration = null;
    _isInitialized = false;
  }

  Future<void> scheduleMediaCleanup(Iterable<String> paths) async {
    final previous = (_recoveryBox.get('mediaCleanup') as List? ?? [])
        .cast<String>();
    await _recoveryBox.put(
      'mediaCleanup',
      {...previous, ...paths.map(_storage.portablePath)}.toList(),
    );
    await _recoveryBox.flush();
  }

  Future<void> retryMediaCleanup() async {
    final pending = (_recoveryBox.get('mediaCleanup') as List? ?? [])
        .cast<String>();
    if (pending.isEmpty) return;
    final referenced = <String>{
      for (final session in getSessions())
        for (final recording in session.recordings)
          _storage.portablePath(recording.storagePath),
      for (final piece in getPieces())
        if (piece.pdfPath != null) _storage.portablePath(piece.pdfPath!),
    };
    if (damagedRecords.value.isNotEmpty) return;
    final remaining = <String>[];
    for (final path in pending) {
      if (referenced.contains(path)) continue;
      try {
        await _storage.deleteManagedFile(path);
      } catch (_) {
        remaining.add(path);
      }
    }
    await _recoveryBox.put('mediaCleanup', remaining);
  }

  Future<void> init() async {
    if (isInitialized) return;
    await Hive.initFlutter();
    await _storage.initialize();
    final bootstrap = await Hive.openBox('flute_bootstrap');
    _generation =
        _recoveryGeneration ??
        bootstrap.get('generation', defaultValue: '') as String;

    _profileBox = await Hive.openBox('flute_profile$_generation');
    _routinesBox = await Hive.openBox('flute_routines$_generation');
    _repertoireBox = await Hive.openBox('flute_repertoire$_generation');
    _repertoireFoldersBox = await Hive.openBox(
      'flute_repertoire_folders$_generation',
    );
    _pdfAnnotationsBox = await Hive.openBox(
      'flute_pdf_annotations$_generation',
    );
    _scoreViewPreferencesBox = await Hive.openBox(
      'flute_score_view_preferences$_generation',
    );
    _sessionsBox = await Hive.openBox('flute_sessions$_generation');

    _recoveryBox = await Hive.openBox('flute_recovery$_generation');
    _batch = DurableBatchService(_recoveryBox, {
      ..._boxes,
      'recovery': _recoveryBox,
    });
    await _batch.recover();
    _sessionCache = null;

    final seedVersion = _profileBox.get(_seedVersionKey) as int? ?? 0;
    if (seedVersion < _currentSeedVersion) {
      if (_routinesBox.isEmpty && _repertoireBox.isEmpty) {
        await _seedInitialData();
      }
      await _profileBox.put(_seedVersionKey, _currentSeedVersion);
    }
    _isInitialized = true;
    // Keep the recovery screen mounted while a fresh generation is restored.
    // main clears the signal after activation and recreates its providers.
    if (_recoveryGeneration == null) needsRecovery.value = false;
    try {
      await retryMediaCleanup();
    } catch (error) {
      debugPrint('Media cleanup deferred: $error');
    }
  }

  void _reportDamage(String type, Object error) {
    damagedRecords.value = {...damagedRecords.value, type};
    debugPrint('Unable to load $type: $error');
  }

  dynamic _mapMedia(dynamic value, {required bool portable}) {
    if (value is List) {
      return value.map((v) => _mapMedia(v, portable: portable)).toList();
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(
          key.toString(),
          const {
                    'pdfPath',
                    'sourcePath',
                    'storagePath',
                    'audioFilePath',
                    'pendingRecordingPath',
                  }.contains(key) &&
                  item is String
              ? (portable
                    ? _storage.portablePath(item)
                    : _storage.resolveStoredPath(item))
              : _mapMedia(item, portable: portable),
        ),
      );
    }
    return value;
  }

  Map<String, Map<String, dynamic>> exportSnapshot() => {
    for (final entry in _boxes.entries)
      entry.key: Map<String, dynamic>.from(entry.value.toMap()),
  };

  Future<void> restoreSnapshot(
    Map<String, Map<String, dynamic>> snapshot,
  ) async {
    await _applyBatch(
      snapshot,
      deletions: {
        'recovery': ['sessionDraft'],
        for (final entry in _boxes.entries)
          entry.key: entry.value.keys
              .cast<String>()
              .where((key) => !snapshot[entry.key]!.containsKey(key))
              .toList(),
      },
    );
    _sessionCache = null;
    damagedRecords.value = {};
  }

  Future<void> _applyBatch(
    Map<String, Map<String, dynamic>> writes, {
    Map<String, List<String>> deletions = const {},
  }) async {
    try {
      await _batch.apply(writes, deletions: deletions);
    } catch (_) {
      _sessionCache = null;
      if (_recoveryBox.containsKey('pending')) {
        _isInitialized = false;
        needsRecovery.value = true;
      }
      rethrow;
    }
  }

  Map<String, dynamic>? readSessionDraft() {
    final raw = _recoveryBox.get('sessionDraft');
    if (raw == null) return null;
    try {
      final draft = Map<String, dynamic>.from(
        _mapMedia(jsonDecode(raw as String), portable: false) as Map,
      );
      if (_sessionsBox.containsKey(draft['sessionId'])) return null;
      return draft;
    } catch (error) {
      _reportDamage('session draft', error);
      return null;
    }
  }

  Future<void> writeSessionDraft(Map<String, dynamic>? draft) async {
    if (draft == null) {
      await _recoveryBox.delete('sessionDraft');
    } else {
      await _recoveryBox.put(
        'sessionDraft',
        jsonEncode(_mapMedia(draft, portable: true)),
      );
    }
    await _recoveryBox.flush();
  }

  Future<void> _seedInitialData() async {
    // Seed initial routines
    final dailyWarmup = Routine(
      id: 'warmup_default',
      title: 'Daily Warmup',
      description: 'Breathing exercises, long tones, and basic scales.',
      exercises: [
        Exercise(
          id: 'w1',
          name: 'Long Tones (Low Register)',
          targetBpm: 60,
          articulation: 'Legato',
        ),
        Exercise(
          id: 'w2',
          name: 'Chromatic Scale (Full Range)',
          targetBpm: 80,
          articulation: 'Legato',
        ),
        Exercise(
          id: 'w3',
          name: 'Major Scales (C, G, D, F)',
          targetBpm: 90,
          articulation: 'Staccato',
        ),
      ],
    );
    await saveRoutine(dailyWarmup);

    final advancedTonguing = Routine(
      id: 'tonguing_default',
      title: 'Articulation drills',
      description:
          'Focused routine on double and triple tonguing speed and clarity.',
      exercises: [
        Exercise(
          id: 't1',
          name: 'Double Tonguing T-K Drill',
          targetBpm: 120,
          articulation: 'Double Tonguing',
        ),
        Exercise(
          id: 't2',
          name: 'Triple Tonguing T-T-K Arpeggios',
          targetBpm: 100,
          articulation: 'Triple Tonguing',
        ),
      ],
    );
    await saveRoutine(advancedTonguing);

    // Seed a sample piece
    final samplePiece = Piece(
      id: 'piece_default',
      title: 'Syrinx',
      composer: 'Claude Debussy',
      targetBpm: 50,
      measuresTotal: 35,
      measuresCompleted: 12,
      notes:
          'Focus on the breath marks and key fluidity in the opening theme. Maintain deep tone quality on the low C/C# notes.',
    );
    await savePiece(samplePiece);
  }

  // --- USER PROFILE ---
  UserProfile? getUserProfile() {
    final raw = _profileBox.get('active_user');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw as String);
      return UserProfile.fromJson(decoded as Map<String, dynamic>);
    } catch (e) {
      _reportDamage('profile', e);
      return null;
    }
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final raw = jsonEncode(profile.toJson());
    await _profileBox.put('active_user', raw);
  }

  Future<void> deleteUserProfile() async {
    await _profileBox.delete('active_user');
  }

  // --- ROUTINES ---
  List<Routine> getRoutines() {
    final routines = <Routine>[];
    for (final raw in _routinesBox.values) {
      try {
        final decoded = jsonDecode(raw as String);
        routines.add(
          localizeSeedRoutine(
            Routine.fromJson(decoded as Map<String, dynamic>),
            getPreferredLocale(),
          ),
        );
      } catch (error) {
        _reportDamage('routines', error);
      }
    }
    return routines;
  }

  Future<void> saveRoutine(Routine routine) async {
    final raw = jsonEncode(routine.toJson());
    await _routinesBox.put(routine.id, raw);
  }

  Future<void> deleteRoutine(String id) async {
    await _routinesBox.delete(id);
  }

  // --- REPERTOIRE ---
  List<Piece> getPieces() {
    final pieces = <Piece>[];
    for (final raw in _repertoireBox.values) {
      try {
        final decoded = jsonDecode(raw as String);
        pieces.add(
          Piece.fromJson(
            Map<String, dynamic>.from(
              _mapMedia(decoded, portable: false) as Map,
            ),
          ),
        );
      } catch (error) {
        _reportDamage('repertoire', error);
      }
    }
    return pieces;
  }

  Future<void> savePiece(Piece piece) async {
    final raw = jsonEncode(_mapMedia(piece.toJson(), portable: true));
    await _repertoireBox.put(piece.id, raw);
  }

  Future<void> deletePiece(String id) async {
    final affectedRoutines = getRoutines().where(
      (routine) =>
          routine.exercises.any((exercise) => exercise.musicSheetPieceId == id),
    );
    for (final routine in affectedRoutines) {
      await saveRoutine(
        routine.copyWith(
          exercises: routine.exercises
              .map(
                (exercise) => exercise.musicSheetPieceId == id
                    ? exercise.copyWith(musicSheetPieceId: null)
                    : exercise,
              )
              .toList(),
        ),
      );
    }
    await Future.wait([
      _repertoireBox.delete(id),
      _pdfAnnotationsBox.delete(id),
      _scoreViewPreferencesBox.delete(id),
    ]);
  }

  // --- PDF ANNOTATIONS ---
  PdfAnnotationDocument? getPdfAnnotations(String pieceId) {
    final raw = _pdfAnnotationsBox.get(pieceId);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw as String);
      return PdfAnnotationDocument.fromJson(
        Map<String, dynamic>.from(_mapMedia(decoded, portable: false) as Map),
      );
    } catch (error) {
      _reportDamage('PDF annotations', error);
      return null;
    }
  }

  Future<void> savePdfAnnotations(PdfAnnotationDocument document) async {
    if (!document.hasAnnotations) {
      await deletePdfAnnotations(document.pieceId);
      return;
    }
    await _pdfAnnotationsBox.put(
      document.pieceId,
      jsonEncode(_mapMedia(document.toJson(), portable: true)),
    );
  }

  Future<void> deletePdfAnnotations(String pieceId) async {
    await _pdfAnnotationsBox.delete(pieceId);
  }

  // --- SCORE VIEW PREFERENCES ---
  ScoreViewPreferences? getScoreViewPreferences(String pieceId) {
    final raw = _scoreViewPreferencesBox.get(pieceId);
    if (raw == null) return null;
    try {
      return ScoreViewPreferences.fromJson(
        Map<String, dynamic>.from(
          _mapMedia(jsonDecode(raw as String), portable: false) as Map,
        ),
      );
    } catch (error) {
      _reportDamage('score display preferences', error);
      return null;
    }
  }

  Future<void> saveScoreViewPreferences(
    ScoreViewPreferences preferences,
  ) async {
    await _scoreViewPreferencesBox.put(
      preferences.pieceId,
      jsonEncode(_mapMedia(preferences.toJson(), portable: true)),
    );
  }

  Future<void> deleteScoreViewPreferences(String pieceId) async {
    await _scoreViewPreferencesBox.delete(pieceId);
  }

  List<RepertoireFolder> getRepertoireFolders() {
    final folders = <RepertoireFolder>[];
    for (final raw in _repertoireFoldersBox.values) {
      try {
        final decoded = jsonDecode(raw as String);
        folders.add(RepertoireFolder.fromJson(decoded as Map<String, dynamic>));
      } catch (error) {
        _reportDamage('repertoire folders', error);
      }
    }
    return folders;
  }

  Future<void> saveRepertoireFolder(RepertoireFolder folder) async {
    await _repertoireFoldersBox.put(folder.id, jsonEncode(folder.toJson()));
  }

  Future<void> deleteRepertoireFolder(String id) async {
    await _repertoireFoldersBox.delete(id);
  }

  // --- SESSIONS ---
  List<SessionRecord> getSessions() {
    if (_sessionCache != null) return _sessionCache!;
    final sessions = <SessionRecord>[];
    for (final raw in _sessionsBox.values) {
      try {
        final decoded = jsonDecode(raw as String);
        sessions.add(
          SessionRecord.fromJson(
            Map<String, dynamic>.from(
              _mapMedia(decoded, portable: false) as Map,
            ),
          ),
        );
      } catch (error) {
        _reportDamage('sessions', error);
      }
    }
    // Sort by startTime descending (most recent first)
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return _sessionCache = List.unmodifiable(sessions);
  }

  Future<void> saveSession(SessionRecord session) async {
    final raw = jsonEncode(_mapMedia(session.toJson(), portable: true));
    await _sessionsBox.put(session.id, raw);
    _sessionCache = null;
  }

  Future<void> deleteSession(String id) async {
    await _sessionsBox.delete(id);
    _sessionCache = null;
  }

  Future<void> mergeJournalData({
    required List<Routine> routines,
    required List<SessionRecord> sessions,
  }) async {
    final routineWrites = <String, dynamic>{
      for (final routine in routines) routine.id: jsonEncode(routine.toJson()),
    };
    final sessionWrites = <String, dynamic>{
      for (final session in sessions) session.id: jsonEncode(session.toJson()),
    };

    await _applyBatch({'routines': routineWrites, 'sessions': sessionWrites});
    _sessionCache = null;
  }

  // --- LOCALIZATION ---
  T _preference<T>(String key, T fallback) {
    final value = _profileBox.get(key, defaultValue: fallback);
    if (value is T && (value is! num || value.isFinite)) return value;
    _reportDamage('preferences', FormatException('Invalid $key'));
    return fallback;
  }

  String getPreferredLocale() {
    final locale = _preference('preferred_locale', 'en');
    return const {'en', 'es'}.contains(locale) ? locale : 'en';
  }

  Future<void> setPreferredLocale(String locale) async {
    await _profileBox.put('preferred_locale', locale);
  }

  bool getKeepScreenAwake() {
    return _preference(_keepScreenAwakeKey, false);
  }

  Future<void> setKeepScreenAwake(bool enabled) async {
    await _profileBox.put(_keepScreenAwakeKey, enabled);
  }

  bool getMetronomeSoundEnabled() {
    return _preference(_metronomeSoundKey, true);
  }

  Future<void> setMetronomeSoundEnabled(bool enabled) async {
    await _profileBox.put(_metronomeSoundKey, enabled);
  }

  double getMetronomeVolume() {
    return _preference<num>(
      _metronomeVolumeKey,
      0.7,
    ).toDouble().clamp(0.0, 1.0);
  }

  Future<void> setMetronomeVolume(double volume) async {
    await _profileBox.put(_metronomeVolumeKey, volume.clamp(0.0, 1.0));
  }

  int getTunerReferenceHz() {
    return _preference<num>(_tunerReferenceKey, 440).toInt().clamp(420, 460);
  }

  Future<void> setTunerReferenceHz(int referenceHz) async {
    await _profileBox.put(_tunerReferenceKey, referenceHz.clamp(420, 460));
  }

  int getTunerToleranceCents() {
    final tolerance = _preference<num>(_tunerToleranceKey, 10).toInt();
    return const {5, 10, 20}.contains(tolerance) ? tolerance : 10;
  }

  Future<void> setTunerToleranceCents(int toleranceCents) async {
    final value = const {5, 10, 20}.contains(toleranceCents)
        ? toleranceCents
        : 10;
    await _profileBox.put(_tunerToleranceKey, value);
  }

  PracticeVisualMode getPracticeVisualMode() {
    final value = _profileBox.get(
      _practiceVisualModeKey,
      defaultValue: PracticeVisualMode.focused.name,
    );
    return PracticeVisualMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => PracticeVisualMode.focused,
    );
  }

  Future<void> setPracticeVisualMode(PracticeVisualMode mode) async {
    await _profileBox.put(_practiceVisualModeKey, mode.name);
  }

  ThemeMode getThemeMode() {
    final value = _profileBox.get(
      _themeModeKey,
      defaultValue: ThemeMode.system.name,
    );
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _profileBox.put(_themeModeKey, mode.name);
  }

  bool getHapticsEnabled() => _preference(_hapticsKey, true);

  Future<void> setHapticsEnabled(bool enabled) async {
    await _profileBox.put(_hapticsKey, enabled);
  }

  bool getSoundCuesEnabled() => _preference(_soundCuesKey, true);

  Future<void> setSoundCuesEnabled(bool enabled) async {
    await _profileBox.put(_soundCuesKey, enabled);
  }

  bool getReducedMotion() => _preference(_reducedMotionKey, false);

  Future<void> setReducedMotion(bool enabled) async {
    await _profileBox.put(_reducedMotionKey, enabled);
  }

  bool getShowCelebrations() => _preference(_showCelebrationsKey, true);

  Future<void> setShowCelebrations(bool enabled) async {
    await _profileBox.put(_showCelebrationsKey, enabled);
  }

  double getPerformanceBrightness() {
    return _preference<num>(
      _performanceBrightnessKey,
      1.0,
    ).toDouble().clamp(0.1, 1.0);
  }

  Future<void> setPerformanceBrightness(double brightness) async {
    await _profileBox.put(
      _performanceBrightnessKey,
      brightness.clamp(0.1, 1.0),
    );
  }

  Future<void> clearAllUserData() async {
    final bootstrap = await Hive.openBox('flute_bootstrap');
    final retained = (bootstrap.get('retained_generations') as List? ?? [])
        .cast<String>();
    for (final generation in retained) {
      if (generation == _generation ||
          (generation.isNotEmpty &&
              !RegExp(r'^_recovered_[0-9]+$').hasMatch(generation))) {
        continue;
      }
      for (final prefix in const [
        'flute_profile',
        'flute_routines',
        'flute_repertoire',
        'flute_repertoire_folders',
        'flute_pdf_annotations',
        'flute_score_view_preferences',
        'flute_sessions',
        'flute_recovery',
      ]) {
        await Hive.deleteBoxFromDisk('$prefix$generation');
      }
    }
    await bootstrap.delete('retained_generations');
    _sessionCache = null;
    damagedRecords.value = {};
    final preferredLocale = getPreferredLocale();
    await Future.wait([
      _profileBox.clear(),
      _routinesBox.clear(),
      _repertoireBox.clear(),
      _repertoireFoldersBox.clear(),
      _pdfAnnotationsBox.clear(),
      _scoreViewPreferencesBox.clear(),
      _sessionsBox.clear(),
      _recoveryBox.clear(),
      FileStorageService().deleteAllManagedFiles(),
    ]);
    await _profileBox.put(_seedVersionKey, _currentSeedVersion);
    await _profileBox.put('preferred_locale', preferredLocale);
  }
}
