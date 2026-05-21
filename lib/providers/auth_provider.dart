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

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final profile = await _authService.signInWithGoogle();
      if (profile != null) {
        _user = profile;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error signing in: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<void> signInGuest(String name) async {
    _isLoading = true;
    notifyListeners();

    try {
      final profile = await _authService.signInGuest(name);
      _user = profile;
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing in guest: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateWeeklyGoal(int minutes) async {
    if (_user == null) return;
    _user = _user!.copyWith(weeklyPracticeGoalMinutes: minutes);
    await _db.saveUserProfile(_user!);
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _user = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing out: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
