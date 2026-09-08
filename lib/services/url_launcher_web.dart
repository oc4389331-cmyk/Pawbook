// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'url_launcher_service.dart';

class UrlLauncherWeb implements UrlLauncherService {
  @override
  void openUrl(String url, {String target = '_blank'}) {
    try {
      html.window.open(url, target);
    } catch (_) {}
  }
}

UrlLauncherService getUrlLauncher() => UrlLauncherWeb();
