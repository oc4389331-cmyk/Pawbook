import 'package:url_launcher/url_launcher.dart' as ul;
import 'url_launcher_service.dart';

class UrlLauncherStub implements UrlLauncherService {
  @override
  void openUrl(String url, {String target = '_blank'}) {
    try {
      final uri = Uri.parse(url);
      ul.launchUrl(uri, mode: ul.LaunchMode.externalApplication);
    } catch (_) {}
  }
}

UrlLauncherService getUrlLauncher() => UrlLauncherStub();
