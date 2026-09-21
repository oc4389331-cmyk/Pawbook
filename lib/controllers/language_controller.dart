import 'package:flutter/material.dart';
import '../l10n/app_translations.dart';

class LanguageController extends ChangeNotifier {
  String _currentLanguage = 'en'; // Default to English as primary language

  String get currentLanguage => _currentLanguage;

  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English', 'flag': '🇺🇸'},
    {'code': 'es', 'name': 'Español', 'flag': '🇪🇸'},
    {'code': 'zh', 'name': '中文', 'flag': '🇨🇳'},
    {'code': 'ja', 'name': '日本語', 'flag': '🇯🇵'},
  ];

  void setLanguage(String langCode) {
    if (_currentLanguage != langCode) {
      _currentLanguage = langCode;
      notifyListeners();
    }
  }

  String t(String key) {
    return AppTranslations.getText(_currentLanguage, key);
  }
}
