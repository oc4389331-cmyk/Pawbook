// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'auth_storage_service.dart';

class WebAuthStorage implements AuthStorageService {
  @override
  void setItem(String key, String value) {
    try {
      html.window.localStorage[key] = value;
      html.window.sessionStorage[key] = value;
    } catch (_) {}
  }

  @override
  String? getItem(String key) {
    try {
      return html.window.localStorage[key] ?? html.window.sessionStorage[key];
    } catch (_) {
      return null;
    }
  }

  @override
  void removeItem(String key) {
    try {
      html.window.localStorage.remove(key);
      html.window.sessionStorage.remove(key);
    } catch (_) {}
  }
}

AuthStorageService getAuthStorage() => WebAuthStorage();
