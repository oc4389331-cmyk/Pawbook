import 'package:shared_preferences/shared_preferences.dart';
import 'auth_storage_service.dart';

class StubAuthStorage implements AuthStorageService {
  static final Map<String, String> _memoryStore = {};
  static SharedPreferences? _prefs;

  @override
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      for (final key in _prefs!.getKeys()) {
        final val = _prefs!.getString(key);
        if (val != null) {
          _memoryStore[key] = val;
        }
      }
    } catch (_) {}
  }

  @override
  void setItem(String key, String value) {
    _memoryStore[key] = value;
    _prefs?.setString(key, value);
    if (_prefs == null) {
      SharedPreferences.getInstance().then((p) {
        _prefs = p;
        p.setString(key, value);
      }).catchError((_) {});
    }
  }

  @override
  String? getItem(String key) {
    return _memoryStore[key] ?? _prefs?.getString(key);
  }

  @override
  void removeItem(String key) {
    _memoryStore.remove(key);
    _prefs?.remove(key);
    if (_prefs == null) {
      SharedPreferences.getInstance().then((p) {
        _prefs = p;
        p.remove(key);
      }).catchError((_) {});
    }
  }
}

AuthStorageService getAuthStorage() => StubAuthStorage();
