import 'url_launcher_service.dart';

class UrlLauncherStub implements UrlLauncherService {
  @override
  void openUrl(String url, {String target = '_blank'}) {}
}

UrlLauncherService getUrlLauncher() => UrlLauncherStub();
