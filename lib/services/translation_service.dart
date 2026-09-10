import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../core/constants/app_constants.dart';

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  final OnDeviceTranslatorModelManager _modelManager = OnDeviceTranslatorModelManager();
  final Map<String, OnDeviceTranslator> _translators = {};
  final Map<String, String> _translationCache = {};

  TranslateLanguage _getMlKitLanguage(String langCode) {
    final supported = AppConstants.getLanguageByCode(langCode);
    return supported.mlKitLanguage;
  }

  String _getCacheKey(String text, String source, String target) {
    return '${source.toLowerCase()}_${target.toLowerCase()}_$text';
  }

  String _extractLangCode(String langString) {
    final clean = langString.toLowerCase();
    if (clean.contains('urdu') || clean.contains('ur')) return 'ur';
    if (clean.contains('turkish') || clean.contains('türkçe') || clean.contains('tr')) return 'tr';
    if (clean.contains('english') || clean.contains('en')) return 'en';
    if (clean.contains('spanish') || clean.contains('español') || clean.contains('es')) return 'es';
    if (clean.contains('arabic') || clean.contains('العربية') || clean.contains('ar')) return 'ar';
    if (clean.contains('japanese') || clean.contains('日本語') || clean.contains('ja')) return 'ja';
    if (clean.contains('german') || clean.contains('deutsch') || clean.contains('de')) return 'de';
    if (clean.contains('french') || clean.contains('français') || clean.contains('fr')) return 'fr';
    if (clean.contains('hindi') || clean.contains('hi')) return 'hi';
    if (clean.contains('chinese') || clean.contains('zh')) return 'zh';
    return langString.trim().split(' ')[0].toLowerCase();
  }

  /// Translates text dynamically using On-Device ML Kit (Mobile) or Dynamic Engine (Web / Fallback)
  Future<String> translate({
    required String text,
    required String sourceLangCode,
    required String targetLangCode,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return text;

    final src = _extractLangCode(sourceLangCode);
    final tgt = _extractLangCode(targetLangCode);

    if (src == tgt) return text;

    final cacheKey = _getCacheKey(trimmed, src, tgt);
    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!;
    }

    // 1. Try On-Device ML Kit if on mobile (non-web)
    if (!kIsWeb) {
      try {
        final sourceLang = _getMlKitLanguage(src);
        final targetLang = _getMlKitLanguage(tgt);
        final translatorKey = '${sourceLang.bcpCode}_${targetLang.bcpCode}';

        if (!_translators.containsKey(translatorKey)) {
          final isSrcDownloaded = await _modelManager.isModelDownloaded(sourceLang.bcpCode);
          if (!isSrcDownloaded) await _modelManager.downloadModel(sourceLang.bcpCode);

          final isTgtDownloaded = await _modelManager.isModelDownloaded(targetLang.bcpCode);
          if (!isTgtDownloaded) await _modelManager.downloadModel(targetLang.bcpCode);

          _translators[translatorKey] = OnDeviceTranslator(
            sourceLanguage: sourceLang,
            targetLanguage: targetLang,
          );
        }

        final translator = _translators[translatorKey]!;
        final translated = await translator.translateText(trimmed);
        if (translated.isNotEmpty) {
          _translationCache[cacheKey] = translated;
          return translated;
        }
      } catch (e) {
        debugPrint('ML Kit translation notice: $e. Falling back to dynamic web engine.');
      }
    }

    // 2. Dynamic Real-time Translation Engine (Web & Fallback)
    try {
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$src&tl=$tgt&dt=t&q=${Uri.encodeComponent(trimmed)}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body);
        if (json.isNotEmpty && json[0] is List) {
          final buffer = StringBuffer();
          for (final item in json[0]) {
            if (item is List && item.isNotEmpty && item[0] != null) {
              buffer.write(item[0].toString());
            }
          }
          final result = buffer.toString().trim();
          if (result.isNotEmpty) {
            _translationCache[cacheKey] = result;
            return result;
          }
        }
      }
    } catch (e) {
      debugPrint('Dynamic translation engine error: $e');
    }

    return text;
  }

  void dispose() {
    for (final translator in _translators.values) {
      translator.close();
    }
    _translators.clear();
    _translationCache.clear();
  }
}

