import 'auth_storage_service.dart';

class StubAuthStorage implements AuthStorageService {
  static final Map<String, String> _memoryStore = {};

  @override
  void setItem(String key, String value) {
    _memoryStore[key] = value;
  }

  @override
  String? getItem(String key) {
    return _memoryStore[key];
  }

  @override
  void removeItem(String key) {
    _memoryStore.remove(key);
  }
}

AuthStorageService getAuthStorage() => StubAuthStorage();
