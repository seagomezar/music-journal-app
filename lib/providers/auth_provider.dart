import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _db = DatabaseService();
  UserProfile? _user;
  bool _isLoading = false;

  UserProfile? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  Future<void> checkAuthStatus() async {
    _user = _authService.getCurrentUser();
    notifyListeners();
  }

  Future<void> createLocalProfile(String name) async {
    _isLoading = true;
    notifyListeners();

    try {
      final profile = await _authService.createLocalProfile(name);
      _user = profile;
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating local profile: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateWeeklyGoal(int minutes) async {
    if (_user == null) return;
    _user = _user!.copyWith(
      weeklyPracticeGoalMinutes: minutes.clamp(1, 10080).toInt(),
    );
    await _db.saveUserProfile(_user!);
    notifyListeners();
  }

  Future<void> eraseAllData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.eraseAllData();
      _user = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error erasing local data: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
