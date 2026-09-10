import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../core/models/user_model.dart';

class LocalStorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static bool isOnboarded() {
    return _prefs?.getBool(AppConstants.prefIsOnboarded) ?? false;
  }

  static Future<void> saveUser(AppUser user) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefUid, user.uid);
    await prefs.setString(AppConstants.prefDisplayName, user.displayName);
    await prefs.setString(AppConstants.prefNativeLanguage, user.nativeLanguage);
    await prefs.setString(AppConstants.prefAvatarSeed, user.avatarSeed);
    await prefs.setString(AppConstants.prefInviteCode, user.inviteCode);
    await prefs.setBool(AppConstants.prefIsOnboarded, true);
  }

  static AppUser? getCachedUser() {
    final uid = _prefs?.getString(AppConstants.prefUid);
    final displayName = _prefs?.getString(AppConstants.prefDisplayName);
    final nativeLanguage = _prefs?.getString(AppConstants.prefNativeLanguage);
    final avatarSeed = _prefs?.getString(AppConstants.prefAvatarSeed);
    final inviteCode = _prefs?.getString(AppConstants.prefInviteCode);

    if (uid != null && displayName != null && nativeLanguage != null) {
      return AppUser(
        uid: uid,
        displayName: displayName,
        nativeLanguage: nativeLanguage,
        avatarSeed: avatarSeed ?? 'bee_1',
        inviteCode: inviteCode ?? '',
        createdAt: 0,
      );
    }
    return null;
  }

  static Future<void> updateLanguage(String langCode) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefNativeLanguage, langCode);
  }

  static Future<void> updateDisplayName(String name) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefDisplayName, name);
  }

  static Future<void> clear() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
