import 'package:flutter/material.dart';
import '../core/models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/local_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();

  AppUser? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _initializeUser();
  }

  /// Initial startup check - loads cached user profile or checks Firebase Auth
  Future<void> _initializeUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      await LocalStorageService.init();

      // Check if user is cached locally
      final cachedUser = LocalStorageService.getCachedUser();
      if (cachedUser != null) {
        _currentUser = cachedUser;
        _dbService.setupPresence(_currentUser!.uid);

        // Fetch fresh profile in background
        _dbService.getUserProfile(_currentUser!.uid).then((fresh) {
          if (fresh != null) {
            _currentUser = fresh;
            LocalStorageService.saveUser(fresh);
            notifyListeners();
          }
        });
      } else {
        // If Firebase already has an anonymous session
        final fbUser = _authService.currentFirebaseUser;
        if (fbUser != null) {
          final remoteUser = await _dbService.getUserProfile(fbUser.uid);
          if (remoteUser != null) {
            _currentUser = remoteUser;
            await LocalStorageService.saveUser(remoteUser);
            _dbService.setupPresence(_currentUser!.uid);
          }
        }
      }
    } catch (e) {
      debugPrint('Auth initialization error: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Complete Onboarding with Display Name and Native Language
  Future<bool> completeOnboarding({
    required String displayName,
    required String nativeLanguage,
    String? avatarSeed,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.completeOnboarding(
        displayName: displayName,
        nativeLanguage: nativeLanguage,
        avatarSeed: avatarSeed,
      );
      _currentUser = user;
      _dbService.setupPresence(user.uid);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Change Native Language (e.g. from Urdu to Turkish)
  Future<void> updateNativeLanguage(String newLanguage) async {
    if (_currentUser == null) return;
    try {
      await _authService.updateLanguage(_currentUser!, newLanguage);
      _currentUser = _currentUser!.copyWith(nativeLanguage: newLanguage);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating language: $e');
    }
  }

  /// Update Display Name
  Future<void> updateDisplayName(String newName) async {
    if (_currentUser == null) return;
    try {
      await _authService.updateDisplayName(_currentUser!, newName);
      _currentUser = _currentUser!.copyWith(displayName: newName);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating display name: $e');
    }
  }

  /// Sign out / Reset session
  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }
}
