import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class SupportedLanguage {
  final String code; // ISO-639-1 / BCP-47
  final String name;
  final String nativeName;
  final String flag;
  final TranslateLanguage mlKitLanguage;

  const SupportedLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.mlKitLanguage,
  });
}

class AppConstants {
  static const String appName = "Bee Talk";
  static const String appTagline = "Speak Free. Understand Instantly.";
  static const String appVersion = "1.0.0";

  // Database Paths
  static const String pathUsers = "users";
  static const String pathInvites = "invites";
  static const String pathChatRooms = "chat_rooms";
  static const String pathMessages = "messages";
  static const String pathUserChats = "user_chats";
  static const String pathPresence = "presence";

  // Shared Preferences Keys
  static const String prefUid = "pref_user_uid";
  static const String prefDisplayName = "pref_display_name";
  static const String prefNativeLanguage = "pref_native_language";
  static const String prefAvatarSeed = "pref_avatar_seed";
  static const String prefInviteCode = "pref_invite_code";
  static const String prefIsOnboarded = "pref_is_onboarded";

  // Supported ML Kit Languages
  static const List<SupportedLanguage> languages = [
    SupportedLanguage(
      code: 'ur',
      name: 'Urdu',
      nativeName: 'اردو',
      flag: '🇵🇰',
      mlKitLanguage: TranslateLanguage.urdu,
    ),
    SupportedLanguage(
      code: 'tr',
      name: 'Turkish',
      nativeName: 'Türkçe',
      flag: '🇹🇷',
      mlKitLanguage: TranslateLanguage.turkish,
    ),
    SupportedLanguage(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flag: '🇺🇸',
      mlKitLanguage: TranslateLanguage.english,
    ),
    SupportedLanguage(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
      flag: '🇪🇸',
      mlKitLanguage: TranslateLanguage.spanish,
    ),
    SupportedLanguage(
      code: 'ar',
      name: 'Arabic',
      nativeName: 'العربية',
      flag: '🇸🇦',
      mlKitLanguage: TranslateLanguage.arabic,
    ),
    SupportedLanguage(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिन्दी',
      flag: '🇮🇳',
      mlKitLanguage: TranslateLanguage.hindi,
    ),
    SupportedLanguage(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      flag: '🇫🇷',
      mlKitLanguage: TranslateLanguage.french,
    ),
    SupportedLanguage(
      code: 'de',
      name: 'German',
      nativeName: 'Deutsch',
      flag: '🇩🇪',
      mlKitLanguage: TranslateLanguage.german,
    ),
    SupportedLanguage(
      code: 'ja',
      name: 'Japanese',
      nativeName: '日本語',
      flag: '🇯🇵',
      mlKitLanguage: TranslateLanguage.japanese,
    ),
    SupportedLanguage(
      code: 'zh',
      name: 'Chinese',
      nativeName: '中文',
      flag: '🇨🇳',
      mlKitLanguage: TranslateLanguage.chinese,
    ),
    SupportedLanguage(
      code: 'ru',
      name: 'Russian',
      nativeName: 'Русский',
      flag: '🇷🇺',
      mlKitLanguage: TranslateLanguage.russian,
    ),
    SupportedLanguage(
      code: 'pt',
      name: 'Portuguese',
      nativeName: 'Português',
      flag: '🇧🇷',
      mlKitLanguage: TranslateLanguage.portuguese,
    ),
    SupportedLanguage(
      code: 'it',
      name: 'Italian',
      nativeName: 'Italiano',
      flag: '🇮🇹',
      mlKitLanguage: TranslateLanguage.italian,
    ),
    SupportedLanguage(
      code: 'ko',
      name: 'Korean',
      nativeName: '한국어',
      flag: '🇰🇷',
      mlKitLanguage: TranslateLanguage.korean,
    ),
    SupportedLanguage(
      code: 'id',
      name: 'Indonesian',
      nativeName: 'Bahasa Indonesia',
      flag: '🇮🇩',
      mlKitLanguage: TranslateLanguage.indonesian,
    ),
    SupportedLanguage(
      code: 'nl',
      name: 'Dutch',
      nativeName: 'Nederlands',
      flag: '🇳🇱',
      mlKitLanguage: TranslateLanguage.dutch,
    ),
    SupportedLanguage(
      code: 'pl',
      name: 'Polish',
      nativeName: 'Polski',
      flag: '🇵🇱',
      mlKitLanguage: TranslateLanguage.polish,
    ),
    SupportedLanguage(
      code: 'vi',
      name: 'Vietnamese',
      nativeName: 'Tiếng Việt',
      flag: '🇻🇳',
      mlKitLanguage: TranslateLanguage.vietnamese,
    ),
  ];

  static SupportedLanguage getLanguageByCode(String code) {
    return languages.firstWhere(
      (lang) => lang.code.toLowerCase() == code.toLowerCase(),
      orElse: () => languages.firstWhere((lang) => lang.code == 'en'),
    );
  }

  static SupportedLanguage getDefaultLanguage() {
    return languages.firstWhere((l) => l.code == 'en');
  }
}
