import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_translations.dart';

class LanguageController extends ChangeNotifier {
  static const String _prefKey = 'pawtbook_language_code';
  String _currentLanguage = 'en'; // Default to English as primary language

  String get currentLanguage => _currentLanguage;

  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English', 'flag': '🇺🇸'},
    {'code': 'es', 'name': 'Español', 'flag': '🇪🇸'},
    {'code': 'zh', 'name': '中文', 'flag': '🇨🇳'},
    {'code': 'ja', 'name': '日本語', 'flag': '🇯🇵'},
  ];

  LanguageController() {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && supportedLanguages.any((l) => l['code'] == saved)) {
        if (_currentLanguage != saved) {
          _currentLanguage = saved;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  void setLanguage(String langCode) {
    if (_currentLanguage != langCode) {
      _currentLanguage = langCode;
      notifyListeners();
      _saveLanguage(langCode);
    }
  }

  Future<void> _saveLanguage(String langCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, langCode);
    } catch (_) {}
  }

  String t(String key, [Map<String, String>? params]) {
    var text = AppTranslations.getText(_currentLanguage, key);
    if (params != null) {
      params.forEach((paramKey, paramVal) {
        text = text.replaceAll('{$paramKey}', paramVal);
      });
    }
    return text;
  }
}
