import 'auth_storage_stub.dart'
    if (dart.library.html) 'auth_storage_web.dart';

abstract class AuthStorageService {
  static final AuthStorageService instance = getAuthStorage();

  void setItem(String key, String value);
  String? getItem(String key);
  void removeItem(String key);
}
