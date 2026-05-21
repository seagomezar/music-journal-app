import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_profile.dart';
import '../models/routine.dart';
import '../models/exercise.dart';
import '../models/piece.dart';
import '../models/session_record.dart';

class DatabaseService {
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
    
    // Seed database if empty
    if (_routinesBox.isEmpty) {
      _seedInitialData();
    }
  }

  void _seedInitialData() {
    // Seed initial routines
    final dailyWarmup = Routine(
      id: 'warmup_default',
      title: 'Daily Warmup',
      description: 'Breathing exercises, long tones, and basic scales.',
      exercises: [
        Exercise(id: 'w1', name: 'Long Tones (Low Register)', targetBpm: 60, articulation: 'Legato'),
        Exercise(id: 'w2', name: 'Chromatic Scale (Full Range)', targetBpm: 80, articulation: 'Legato'),
        Exercise(id: 'w3', name: 'Major Scales (C, G, D, F)', targetBpm: 90, articulation: 'Staccato'),
      ],
    );
    saveRoutine(dailyWarmup);

    final advancedTonguing = Routine(
      id: 'tonguing_default',
      title: 'Articulation drills',
      description: 'Focused routine on double and triple tonguing speed and clarity.',
      exercises: [
        Exercise(id: 't1', name: 'Double Tonguing T-K Drill', targetBpm: 120, articulation: 'Double Tonguing'),
        Exercise(id: 't2', name: 'Triple Tonguing T-T-K Arpeggios', targetBpm: 100, articulation: 'Triple Tonguing'),
      ],
    );
    saveRoutine(advancedTonguing);

    // Seed a sample piece
    final samplePiece = Piece(
      id: 'piece_default',
      title: 'Syrinx',
      composer: 'Claude Debussy',
      targetBpm: 50,
      measuresTotal: 35,
      measuresCompleted: 12,
      notes: 'Focus on the breath marks and key fluidity in the opening theme. Maintain deep tone quality on the low C/C# notes.',
    );
    savePiece(samplePiece);
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
    return _routinesBox.values.map((raw) {
      final decoded = jsonDecode(raw as String);
      return Routine.fromJson(decoded as Map<String, dynamic>);
    }).toList();
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
    return _repertoireBox.values.map((raw) {
      final decoded = jsonDecode(raw as String);
      return Piece.fromJson(decoded as Map<String, dynamic>);
    }).toList();
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
    final sessions = _sessionsBox.values.map((raw) {
      final decoded = jsonDecode(raw as String);
      return SessionRecord.fromJson(decoded as Map<String, dynamic>);
    }).toList();
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

  // --- LOCALIZATION ---
  String getPreferredLocale() {
    return _profileBox.get('preferred_locale', defaultValue: 'en') as String;
  }

  Future<void> setPreferredLocale(String locale) async {
    await _profileBox.put('preferred_locale', locale);
  }
}
