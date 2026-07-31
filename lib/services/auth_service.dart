import '../models/user_profile.dart';
import 'database_service.dart';

class AuthService {
  final DatabaseService _db = DatabaseService();

  Future<UserProfile> createLocalProfile(String name) async {
    final profile = UserProfile(
      id: 'local_profile',
      name: name.trim().isEmpty ? 'Guest Flutist' : name.trim(),
    );
    await _db.saveUserProfile(profile);
    return profile;
  }

  Future<void> eraseAllData() async {
    await _db.clearAllUserData();
  }

  UserProfile? getCurrentUser() {
    return _db.getUserProfile();
  }
}
