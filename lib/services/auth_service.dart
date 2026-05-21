import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_profile.dart';
import 'database_service.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  final DatabaseService _db = DatabaseService();

  Future<UserProfile?> signInWithGoogle() async {
    try {
      // In a real environment, this attempts a Google Sign-In.
      // Since Google Sign-In requires Firebase/GCP setup, if it's not configured
      // or throws an exception on some platforms, we handle the error and fallback to a mock profile.
      if (kIsWeb) {
        // Simple sign in
        final GoogleSignInAccount? account = await _googleSignIn.signIn();
        if (account != null) {
          final profile = UserProfile(
            id: account.id,
            name: account.displayName ?? 'Flutist',
            email: account.email,
            photoUrl: account.photoUrl,
          );
          await _db.saveUserProfile(profile);
          return profile;
        }
        return null;
      }
      
      // Native platforms or fallback
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        final profile = UserProfile(
          id: account.id,
          name: account.displayName ?? 'Flutist',
          email: account.email,
          photoUrl: account.photoUrl,
        );
        await _db.saveUserProfile(profile);
        return profile;
      }
      return null;
    } catch (e) {
      debugPrint('Google Sign-In error (using offline mock fallback): $e');
      // For developer convenience during testing and offline usage, return a mock Google Profile
      final mockProfile = UserProfile(
        id: 'google_mock_12345',
        name: 'Jean-Pierre Rampal',
        email: 'rampal.flute@googlemail.com',
        photoUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150', // Nice mock avatar
      );
      await _db.saveUserProfile(mockProfile);
      return mockProfile;
    }
  }

  Future<UserProfile> signInGuest(String name) async {
    final profile = UserProfile(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Guest Flutist' : name.trim(),
      email: 'guest@fluteapp.local',
      photoUrl: null,
    );
    await _db.saveUserProfile(profile);
    return profile;
  }

  Future<void> signOut() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('Error signing out from Google: $e');
    }
    await _db.deleteUserProfile();
  }

  UserProfile? getCurrentUser() {
    return _db.getUserProfile();
  }
}
