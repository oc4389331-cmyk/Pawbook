import 'url_launcher_stub.dart'
    if (dart.library.html) 'url_launcher_web.dart';

abstract class UrlLauncherService {
  static final UrlLauncherService instance = getUrlLauncher();

  void openUrl(String url, {String target = '_blank'});
}
