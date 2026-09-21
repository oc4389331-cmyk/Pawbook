import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pawtbook/config/app_config.dart';
import 'package:pawtbook/controllers/language_controller.dart';
import 'package:pawtbook/l10n/app_translations.dart';
import 'package:pawtbook/views/widgets/about_pawbook_modal.dart';

void main() {
  group('About Pawbooklife & Multi-Language Tests', () {
    test('AppConfig has valid app version and display version', () {
      expect(AppConfig.appVersion, isNotEmpty);
      expect(AppConfig.appDisplayVersion, contains('1.0.0'));
      expect(AppConfig.appName, equals('Pawbooklife'));
    });

    test('All new translation keys exist across en, es, zh, and ja', () {
      final keys = [
        'aboutPawbookTitle',
        'aboutPawbookSubtitle',
        'appVersionLabel',
        'aboutWhatIsTitle',
        'aboutWhatIsDesc',
        'aboutWeb3Title',
        'aboutWeb3Desc',
        'aboutCommunityTitle',
        'aboutCommunityDesc',
        'aboutMarketplaceTitle',
        'aboutMarketplaceDesc',
        'aboutBtn',
        'videoLimitDialogTitle',
        'videoLimitDialogMsg',
        'trimVideoBtn',
        'videoTrimCancelled',
        'videoNotUploadedTrimRequired',
        'likeComment',
        'studioDoneBtn',
        'studioTrimTool',
        'studioFilterTool',
        'studioStickersTool',
        'studioTextTool',
        'studioAudioTool',
      ];

      for (final lang in ['en', 'es', 'zh', 'ja']) {
        for (final key in keys) {
          final text = AppTranslations.getText(lang, key);
          expect(text, isNotEmpty, reason: 'Key "$key" is missing in language "$lang"');
          expect(text, isNot(equals(key)), reason: 'Key "$key" fell back to its key name in "$lang"');
        }
      }
    });

    test('LanguageController dynamically switches translations for new features', () {
      final controller = LanguageController();

      // Default English as requested by user
      expect(controller.currentLanguage, equals('en'));
      expect(controller.t('likeComment'), equals('Like'));
      expect(controller.t('aboutBtn'), equals('About Pawbooklife'));

      // Switch to Spanish
      controller.setLanguage('es');
      expect(controller.currentLanguage, equals('es'));
      expect(controller.t('likeComment'), equals('Me gusta'));
      expect(controller.t('aboutBtn'), equals('Acerca de Pawbooklife'));

      // Switch to Chinese
      controller.setLanguage('zh');
      expect(controller.currentLanguage, equals('zh'));
      expect(controller.t('likeComment'), equals('赞'));
      expect(controller.t('aboutBtn'), equals('关于 Pawbooklife'));

      // Switch to Japanese
      controller.setLanguage('ja');
      expect(controller.currentLanguage, equals('ja'));
      expect(controller.t('likeComment'), equals('いいね'));
      expect(controller.t('aboutBtn'), equals('Pawbooklife について'));
    });

    testWidgets('AboutPawbookModal renders app information, version badge, and feature cards', (WidgetTester tester) async {
      final langController = LanguageController();

      await tester.pumpWidget(
        ChangeNotifierProvider<LanguageController>.value(
          value: langController,
          child: const MaterialApp(
            home: Scaffold(
              body: AboutPawbookModal(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // App Title and Version
      expect(find.text('Pawbooklife'), findsOneWidget);
      expect(find.textContaining('1.0.0'), findsOneWidget);
      expect(find.text('Production APK 🚀'), findsOneWidget);

      // Feature Card Titles
      expect(find.text(langController.t('aboutWhatIsTitle')), findsOneWidget);
      expect(find.text(langController.t('aboutWeb3Title')), findsOneWidget);
      expect(find.text(langController.t('aboutCommunityTitle')), findsOneWidget);
      expect(find.text(langController.t('aboutMarketplaceTitle')), findsOneWidget);
    });
  });
}
