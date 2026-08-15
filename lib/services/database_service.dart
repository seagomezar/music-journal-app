import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_profile.dart';
import '../models/routine.dart';
import '../models/exercise.dart';
import '../models/piece.dart';
import '../models/session_record.dart';
import 'file_storage_service.dart';

class DatabaseService {
  static const int _currentSeedVersion = 1;
  static const String _seedVersionKey = 'seed_version';
  static const String _keepScreenAwakeKey = 'keep_screen_awake';
  static const String _metronomeSoundKey = 'metronome_sound';
  static const String _metronomeVolumeKey = 'metronome_volume';
  static const String _tunerReferenceKey = 'tuner_reference_hz';
  static const String _tunerToleranceKey = 'tuner_tolerance_cents';
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late Box _profileBox;
  late Box _routinesBox;
  late Box _repertoireBox;
  late Box _sessionsBox;

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    await Hive.initFlutter();

    _profileBox = await Hive.openBox('flute_profile');
    _routinesBox = await Hive.openBox('flute_routines');
    _repertoireBox = await Hive.openBox('flute_repertoire');
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
    await _repertoireBox.delete(id);
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

  Future<void> clearAllUserData() async {
    final preferredLocale = getPreferredLocale();
    await Future.wait([
      _profileBox.clear(),
      _routinesBox.clear(),
      _repertoireBox.clear(),
      _sessionsBox.clear(),
      FileStorageService().deleteAllManagedFiles(),
    ]);
    await _profileBox.put(_seedVersionKey, _currentSeedVersion);
    await _profileBox.put('preferred_locale', preferredLocale);
  }
}
