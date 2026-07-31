import 'package:flutter/material.dart';
import '../models/routine.dart';
import '../services/database_service.dart';

class RoutineProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  List<Routine> _routines = [];
  bool _isLoading = false;

  List<Routine> get routines => _routines;
  bool get isLoading => _isLoading;

  Future<void> loadRoutines() async {
    _isLoading = true;
    notifyListeners();
    try {
      _routines = _db.getRoutines();
    } catch (e) {
      debugPrint('Error loading routines: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveRoutine(Routine routine) async {
    final previousRoutines = List<Routine>.from(_routines);
    final updatedRoutines = List<Routine>.from(_routines);
    final existingIndex = updatedRoutines.indexWhere(
      (candidate) => candidate.id == routine.id,
    );
    if (existingIndex == -1) {
      updatedRoutines.add(routine);
    } else {
      updatedRoutines[existingIndex] = routine;
    }
    _routines = updatedRoutines;
    notifyListeners();

    try {
      await _db.saveRoutine(routine);
    } catch (e) {
      _routines = previousRoutines;
      notifyListeners();
      debugPrint('Error saving routine: $e');
      rethrow;
    }
  }

  Future<void> deleteRoutine(String id) async {
    try {
      await _db.deleteRoutine(id);
      await loadRoutines();
    } catch (e) {
      debugPrint('Error deleting routine: $e');
      rethrow;
    }
  }
}
