import 'package:flutter_test/flutter_test.dart';
import 'package:pawtbook/controllers/auth_controller.dart';
import 'package:pawtbook/models/pet_model.dart';

void main() {
  group('Role & Navigation Permissions Unit Tests', () {
    late AuthController authController;

    setUp(() {
      authController = AuthController();
    });

    test('New authenticated user starts as Human Only (Sponsor) role', () async {
      await authController.loginWithSolanaWallet();
      expect(authController.isAuthenticated, isTrue);
      expect(authController.hasPet, isFalse);
      expect(authController.isHumanOnly, isTrue);
      expect(authController.isPetCreator, isFalse);
    });

    test('Registering a pet upgrades user to Pet Creator role', () async {
      await authController.loginWithSolanaWallet();
      expect(authController.hasPet, isFalse);

      final newPet = PetModel(
        id: 'pet_test_99',
        ownerId: authController.currentProfile!.id,
        name: 'Rex',
        species: 'Dog',
        createdAt: DateTime.now(),
      );

      await authController.registerPet(newPet);
      expect(authController.hasPet, isTrue);
      expect(authController.isPetCreator, isTrue);
      expect(authController.activePet?.name, equals('Rex'));
    });
  });
}
