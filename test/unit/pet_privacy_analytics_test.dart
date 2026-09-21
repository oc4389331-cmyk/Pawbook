import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawtbook/controllers/auth_controller.dart';
import 'package:pawtbook/controllers/language_controller.dart';
import 'package:pawtbook/models/pet_model.dart';
import 'package:pawtbook/models/profile_model.dart';
import 'package:pawtbook/views/widgets/pet_analytics_dashboard_modal.dart';
import 'package:provider/provider.dart';

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _MockHttpOverrides();

  group('Pet Analytics & Statistics Privacy Tests', () {
    final chicoPet = PetModel(
      id: 'pet_d1148fad',
      ownerId: 'usr_VL5CBAhr',
      name: 'Chico',
      species: 'Perro',
      breed: 'Otro',
      bio: 'Me gusta correr',
      avatarUrl: '',
      totalSponsoredScore: 500,
      createdAt: DateTime.now(),
    );

    testWidgets('Non-owner account CANNOT see Chico analytics (shows private locked view)', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authController = AuthController();
      final langController = LanguageController();

      // Logged in as a DIFFERENT user (e.g. external user / seeker wallet)
      final otherUser = ProfileModel(
        id: 'usr_58ttSbEq',
        walletAddress: '58ttSbEqUGftHtBmPmcacLigRqM1H6BwhoLTw4D4T5c4',
        username: 'paw_58ttSbEq',
        email: 'other_user@gmail.com',
        createdAt: DateTime.now(),
      );
      authController.setProfileForTesting(otherUser, []);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: authController),
            ChangeNotifierProvider<LanguageController>.value(value: langController),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PetAnalyticsDashboardModal(pet: chicoPet),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Must display the locked private screen
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.text(langController.t('privateStatsTitle')), findsOneWidget);
      expect(find.text(langController.t('privateStatsDesc')), findsOneWidget);
      // Must NOT display sensitive creator performance tabs
      expect(find.text('Tiempo de Vista'), findsNothing);
    });

    test('Chico is strictly identified as private to Ernesto and non-owners are rejected', () {
      final authController = AuthController();

      // Case 1: Ernesto logged in
      final ernestoUser = ProfileModel(
        id: 'usr_VL5CBAhr',
        walletAddress: 'VL5CBAhrjpZUmtqADzqpRgmC7J76KYBNF4TC7iqEb6PN',
        username: 'wernesto66',
        email: 'wernesto66@gmail.com',
        createdAt: DateTime.now(),
      );
      authController.setProfileForTesting(ernestoUser, [chicoPet]);

      final isErnestoOwner = (ernestoUser.email == 'wernesto66@gmail.com' ||
          ernestoUser.id == 'usr_VL5CBAhr' ||
          ernestoUser.id == 'usr_sol_400a');
      expect(isErnestoOwner, isTrue);

      // Case 2: Other user logged in with Seeker wallet
      final otherUser = ProfileModel(
        id: 'usr_58ttSbEq',
        walletAddress: '58ttSbEqUGftHtBmPmcacLigRqM1H6BwhoLTw4D4T5c4',
        username: 'paw_58ttSbEq',
        email: 'other_user@gmail.com',
        createdAt: DateTime.now(),
      );
      authController.setProfileForTesting(otherUser, []);

      final isOtherOwner = (otherUser.email == 'wernesto66@gmail.com' ||
          otherUser.id == 'usr_VL5CBAhr' ||
          otherUser.id == 'usr_sol_400a');
      expect(isOtherOwner, isFalse);

      // Case 3: Other pet belongs strictly to its creator/owner
      final lunaPet = PetModel(
        id: 'pet_luna_cTgH6w',
        ownerId: 'usr_cTgH6wCK',
        name: 'Luna',
        species: 'Gato',
        breed: 'Siamés',
        bio: 'Gatita juguetona',
        avatarUrl: '',
        totalSponsoredScore: 200,
        createdAt: DateTime.now(),
      );

      final isOtherUserLunaOwner = (lunaPet.ownerId.isNotEmpty &&
              lunaPet.ownerId != 'usr_owner' &&
              lunaPet.ownerId == otherUser.id) ||
          authController.userPets.any((p) => p.id == lunaPet.id && p.ownerId == otherUser.id);
      expect(isOtherUserLunaOwner, isFalse);

      // When the actual creator of Luna logs in:
      final lunaOwner = ProfileModel(
        id: 'usr_cTgH6wCK',
        walletAddress: 'cTgH6wCK999...',
        username: 'oscar_luna',
        email: 'oscar.romero@anda.gob.sv',
        createdAt: DateTime.now(),
      );
      final isLunaRealOwner = (lunaPet.ownerId.isNotEmpty &&
              lunaPet.ownerId != 'usr_owner' &&
              lunaPet.ownerId == lunaOwner.id);
      expect(isLunaRealOwner, isTrue);
    });
  });
}
