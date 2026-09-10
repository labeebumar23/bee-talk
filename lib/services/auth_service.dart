import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/models/user_model.dart';
import '../core/utils/avatar_generator.dart';
import '../core/utils/code_generator.dart';
import 'database_service.dart';
import 'local_storage_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _dbService = DatabaseService();

  User? get currentFirebaseUser => _auth.currentUser;

  /// Signs in anonymously and returns the Firebase User ID.
  Future<String> signInAnonymously() async {
    try {
      if (_auth.currentUser != null) {
        return _auth.currentUser!.uid;
      }
      final userCredential = await _auth.signInAnonymously();
      final uid = userCredential.user!.uid;
      debugPrint('Anonymous sign-in successful. UID: $uid');
      return uid;
    } catch (e) {
      debugPrint('Error signing in anonymously: $e');
      rethrow;
    }
  }

  /// Completes the frictionless onboarding without email/phone/password
  Future<AppUser> completeOnboarding({
    required String displayName,
    required String nativeLanguage,
    String? avatarSeed,
  }) async {
    final uid = await signInAnonymously();
    final seed = avatarSeed ?? BeeAvatarUtil.generateRandomSeed();
    final inviteCode = InviteCodeUtil.generateCode();

    final user = AppUser(
      uid: uid,
      displayName: displayName.trim(),
      nativeLanguage: nativeLanguage,
      avatarSeed: seed,
      inviteCode: inviteCode,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      isOnline: true,
      lastSeen: DateTime.now().millisecondsSinceEpoch,
    );

    // Save profile to Firebase Realtime Database
    await _dbService.saveUserProfile(user);

    // Register user's unique invite code in /invites/{code}
    await _dbService.registerInviteCode(inviteCode, user);

    // Save to local storage for instant startup
    await LocalStorageService.saveUser(user);

    return user;
  }

  /// Updates user language and synchronizes across database & local cache
  Future<void> updateLanguage(AppUser user, String newLanguage) async {
    final updated = user.copyWith(nativeLanguage: newLanguage);
    await _dbService.updateUserLanguage(user.uid, newLanguage);
    await LocalStorageService.updateLanguage(newLanguage);
  }

  /// Updates display name
  Future<void> updateDisplayName(AppUser user, String newName) async {
    await _dbService.updateDisplayName(user.uid, newName);
    await LocalStorageService.updateDisplayName(newName);
  }

  /// Sign out / reset local identity
  Future<void> signOut() async {
    await _auth.signOut();
    await LocalStorageService.clear();
  }
}
