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

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    await Hive.initFlutter();

    _profileBox = await Hive.openBox('flute_profile');
    _routinesBox = await Hive.openBox('flute_routines');
    _repertoireBox = await Hive.openBox('flute_repertoire');
    _repertoireFoldersBox = await Hive.openBox('flute_repertoire_folders');
    _pdfAnnotationsBox = await Hive.openBox('flute_pdf_annotations');
    _scoreViewPreferencesBox = await Hive.openBox(
      'flute_score_view_preferences',
    );
    _sessionsBox = await Hive.openBox('flute_sessions');

    _isInitialized = true;

    final seedVersion = _profileBox.get(_seedVersionKey) as int? ?? 0;
    if (seedVersion < _currentSeedVersion) {
      if (_routinesBox.isEmpty && _repertoireBox.isEmpty) {
        await _seedInitialData();
      }
      await _profileBox.put(_seedVersionKey, _currentSeedVersion);
    }
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
      debugPrint('Error decoding user profile: $e');
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
        routines.add(Routine.fromJson(decoded as Map<String, dynamic>));
      } catch (error) {
        debugPrint('Skipping invalid routine record: $error');
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
        pieces.add(Piece.fromJson(decoded as Map<String, dynamic>));
      } catch (error) {
        debugPrint('Skipping invalid repertoire record: $error');
      }
    }
    return pieces;
  }

  Future<void> savePiece(Piece piece) async {
    final raw = jsonEncode(piece.toJson());
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
        Map<String, dynamic>.from(decoded as Map),
      );
    } catch (error) {
      debugPrint('Skipping invalid PDF annotation record: $error');
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
      jsonEncode(document.toJson()),
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
        Map<String, dynamic>.from(jsonDecode(raw as String) as Map),
      );
    } catch (error) {
      debugPrint('Skipping invalid score view preference record: $error');
      return null;
    }
  }

  Future<void> saveScoreViewPreferences(
    ScoreViewPreferences preferences,
  ) async {
    await _scoreViewPreferencesBox.put(
      preferences.pieceId,
      jsonEncode(preferences.toJson()),
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
        debugPrint('Skipping invalid repertoire folder record: $error');
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
    final sessions = <SessionRecord>[];
    for (final raw in _sessionsBox.values) {
      try {
        final decoded = jsonDecode(raw as String);
        sessions.add(SessionRecord.fromJson(decoded as Map<String, dynamic>));
      } catch (error) {
        debugPrint('Skipping invalid session record: $error');
      }
    }
    // Sort by startTime descending (most recent first)
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  Future<void> saveSession(SessionRecord session) async {
    final raw = jsonEncode(session.toJson());
    await _sessionsBox.put(session.id, raw);
  }

  Future<void> deleteSession(String id) async {
    await _sessionsBox.delete(id);
  }

  Future<void> mergeJournalData({
    required List<Routine> routines,
    required List<SessionRecord> sessions,
  }) async {
    final previousRoutines = Map<dynamic, dynamic>.from(_routinesBox.toMap());
    final previousSessions = Map<dynamic, dynamic>.from(_sessionsBox.toMap());
    final routineWrites = <dynamic, dynamic>{
      for (final routine in routines) routine.id: jsonEncode(routine.toJson()),
    };
    final sessionWrites = <dynamic, dynamic>{
      for (final session in sessions) session.id: jsonEncode(session.toJson()),
    };

    try {
      await _routinesBox.putAll(routineWrites);
      await _sessionsBox.putAll(sessionWrites);
    } catch (error) {
      try {
        await _routinesBox.clear();
        await _routinesBox.putAll(previousRoutines);
        await _sessionsBox.clear();
        await _sessionsBox.putAll(previousSessions);
      } catch (rollbackError) {
        debugPrint('Journal import rollback failed: $rollbackError');
      }
      rethrow;
    }
  }

  // --- LOCALIZATION ---
  String getPreferredLocale() {
    return _profileBox.get('preferred_locale', defaultValue: 'en') as String;
  }

  Future<void> setPreferredLocale(String locale) async {
    await _profileBox.put('preferred_locale', locale);
  }

  bool getKeepScreenAwake() {
    return _profileBox.get(_keepScreenAwakeKey, defaultValue: false) as bool;
  }

  Future<void> setKeepScreenAwake(bool enabled) async {
    await _profileBox.put(_keepScreenAwakeKey, enabled);
  }

  bool getMetronomeSoundEnabled() {
    return _profileBox.get(_metronomeSoundKey, defaultValue: true) as bool;
  }

  Future<void> setMetronomeSoundEnabled(bool enabled) async {
    await _profileBox.put(_metronomeSoundKey, enabled);
  }

  double getMetronomeVolume() {
    final value = _profileBox.get(_metronomeVolumeKey, defaultValue: 0.7);
    return (value as num).toDouble().clamp(0.0, 1.0);
  }

  Future<void> setMetronomeVolume(double volume) async {
    await _profileBox.put(_metronomeVolumeKey, volume.clamp(0.0, 1.0));
  }

  int getTunerReferenceHz() {
    final value = _profileBox.get(_tunerReferenceKey, defaultValue: 440);
    return (value as num).toInt().clamp(420, 460);
  }

  Future<void> setTunerReferenceHz(int referenceHz) async {
    await _profileBox.put(_tunerReferenceKey, referenceHz.clamp(420, 460));
  }

  int getTunerToleranceCents() {
    final value = _profileBox.get(_tunerToleranceKey, defaultValue: 10);
    final tolerance = (value as num).toInt();
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

  bool getHapticsEnabled() =>
      _profileBox.get(_hapticsKey, defaultValue: true) as bool;

  Future<void> setHapticsEnabled(bool enabled) async {
    await _profileBox.put(_hapticsKey, enabled);
  }

  bool getSoundCuesEnabled() =>
      _profileBox.get(_soundCuesKey, defaultValue: true) as bool;

  Future<void> setSoundCuesEnabled(bool enabled) async {
    await _profileBox.put(_soundCuesKey, enabled);
  }

  bool getReducedMotion() =>
      _profileBox.get(_reducedMotionKey, defaultValue: false) as bool;

  Future<void> setReducedMotion(bool enabled) async {
    await _profileBox.put(_reducedMotionKey, enabled);
  }

  bool getShowCelebrations() =>
      _profileBox.get(_showCelebrationsKey, defaultValue: true) as bool;

  Future<void> setShowCelebrations(bool enabled) async {
    await _profileBox.put(_showCelebrationsKey, enabled);
  }

  double getPerformanceBrightness() {
    final value = _profileBox.get(_performanceBrightnessKey, defaultValue: 1.0);
    return (value as num).toDouble().clamp(0.1, 1.0);
  }

  Future<void> setPerformanceBrightness(double brightness) async {
    await _profileBox.put(
      _performanceBrightnessKey,
      brightness.clamp(0.1, 1.0),
    );
  }

  Future<void> clearAllUserData() async {
    final preferredLocale = getPreferredLocale();
    await Future.wait([
      _profileBox.clear(),
      _routinesBox.clear(),
      _repertoireBox.clear(),
      _repertoireFoldersBox.clear(),
      _pdfAnnotationsBox.clear(),
      _scoreViewPreferencesBox.clear(),
      _sessionsBox.clear(),
      FileStorageService().deleteAllManagedFiles(),
    ]);
    await _profileBox.put(_seedVersionKey, _currentSeedVersion);
    await _profileBox.put('preferred_locale', preferredLocale);
  }
}
