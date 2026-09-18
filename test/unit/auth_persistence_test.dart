import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pawtbook/controllers/auth_controller.dart';
import 'package:pawtbook/models/profile_model.dart';
import 'package:pawtbook/models/pet_model.dart';
import 'package:pawtbook/services/auth_storage_service.dart';
import 'package:pawtbook/services/supabase_service.dart';
import 'package:pawtbook/services/dynamic_auth_service.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';
import 'package:solana/base58.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthStorageService.instance.init();
  });

  group('Universal Auth Persistence & Auto-Login Tests', () {
    test('Base58 encoding works properly', () {
      final bytes = [1, 2, 3, 4, 5];
      final encoded = base58encode(bytes);
      expect(encoded, isNotEmpty);
    });
    test('Session is restored when cached profile exists in storage', () async {
      final storage = AuthStorageService.instance;
      storage.setItem('pawtbook_logged_user_id', 'usr_test_123');
      storage.setItem('pawtbook_logged_wallet', 'sol_phantom_test_wallet');
      storage.setItem('pawtbook_logged_email', 'chico_owner@test.com');
      storage.setItem('pawtbook_logged_out', 'false');

      final sampleProfile = ProfileModel(
        id: 'usr_test_123',
        walletAddress: 'sol_phantom_test_wallet',
        username: 'chico_owner',
        fullName: 'W. Ernesto',
        email: 'chico_owner@test.com',
        createdAt: DateTime.now(),
      );

      final supabaseService = SupabaseService(useMockFallback: true);
      // Seed profile in mock supabase
      await supabaseService.createProfile(sampleProfile);
      await supabaseService.createPet(
        PetModel(
          id: 'pet_chico_test',
          ownerId: 'usr_test_123',
          name: 'Chico',
          species: 'Dog',
          breed: 'Chihuahua',
          avatarUrl: 'https://example.com/chico.jpg',
          createdAt: DateTime.now(),
        ),
      );

      final authController = AuthController(supabaseService: supabaseService);
      final restored = await authController.restoreSession();

      expect(restored, isTrue);
      expect(authController.isAuthenticated, isTrue);
      expect(authController.currentProfile?.id, equals('usr_test_123'));
      expect(authController.currentProfile?.walletAddress, equals('sol_phantom_test_wallet'));
      expect(authController.userPets.isNotEmpty, isTrue);
      expect(authController.activePet?.name, equals('Chico'));
    });

    test('Solana Wallet session persists and restores automatically', () async {
      final sampleProfile = ProfileModel(
        id: 'usr_wallet_solana',
        walletAddress: 'Phantom_Solana_Wallet_999',
        username: 'sol_trader',
        fullName: 'Solana Pet Creator',
        createdAt: DateTime.now(),
      );

      final supabaseService = SupabaseService(useMockFallback: true);
      await supabaseService.createProfile(sampleProfile);

      final authController = AuthController(supabaseService: supabaseService);

      // Simulate wallet connection and storage
      authController.setProfileForTesting(sampleProfile);
      final storage = AuthStorageService.instance;
      storage.setItem('pawtbook_logged_user_id', sampleProfile.id);
      storage.setItem('pawtbook_logged_wallet', sampleProfile.walletAddress);
      storage.setItem('pawtbook_logged_out', 'false');

      // Create new AuthController simulating app relaunch
      final reloadedController = AuthController(supabaseService: supabaseService);
      final didRestore = await reloadedController.restoreSession();

      expect(didRestore, isTrue);
      expect(reloadedController.isAuthenticated, isTrue);
      expect(reloadedController.currentProfile?.walletAddress, equals('Phantom_Solana_Wallet_999'));
    });

    test('Explicit logout clears storage and prevents auto-login', () async {
      final sampleProfile = ProfileModel(
        id: 'usr_logout_test',
        walletAddress: 'sol_logout_test',
        username: 'logout_user',
        createdAt: DateTime.now(),
      );

      final supabaseService = SupabaseService(useMockFallback: true);
      await supabaseService.createProfile(sampleProfile);

      final authController = AuthController(supabaseService: supabaseService);
      authController.setProfileForTesting(sampleProfile);

      // Call explicit logout
      await authController.logout();

      expect(authController.isAuthenticated, isFalse);
      expect(authController.currentProfile, isNull);

      final storage = AuthStorageService.instance;
      expect(storage.getItem('pawtbook_logged_out'), equals('true'));
      expect(storage.getItem('pawtbook_logged_user_id'), isNull);

      // Attempt restore should fail
      final didRestore = await authController.restoreSession();
      expect(didRestore, isFalse);
      expect(authController.isAuthenticated, isFalse);
    });

    test('Solana device wallet address is persistent across logout and re-login without asking to recreate account', () async {
      final supabaseService = SupabaseService(useMockFallback: true);
      final dynamicAuthService = DynamicAuthService();

      final authController = AuthController(
        supabaseService: supabaseService,
        dynamicAuthService: dynamicAuthService,
      );

      // 1. Initial wallet connection (e.g. on Seeker / Mobile)
      final initialRes = await dynamicAuthService.connectSpecificWallet('Seeker');
      expect(initialRes.isSuccess, isTrue);
      final assignedWallet = initialRes.walletAddress;
      expect(assignedWallet, isNotNull);

      // 2. User registers/logs in with this wallet
      final loginSuccess = await authController.loginWithSolanaWallet(
        walletType: 'Seeker',
        fullName: 'Seeker Pet Owner',
      );
      expect(loginSuccess, isTrue);
      expect(authController.isAuthenticated, isTrue);
      expect(authController.currentProfile?.walletAddress, equals(assignedWallet));

      // 3. User explicitly logs out
      await authController.logout();
      expect(authController.isAuthenticated, isFalse);
      expect(authController.currentProfile, isNull);

      // 4. User connects wallet again to log in
      final reloadedController = AuthController(
        supabaseService: supabaseService,
        dynamicAuthService: dynamicAuthService,
      );

      final secondLoginSuccess = await reloadedController.loginWithSolanaWallet(
        walletType: 'Seeker',
      );

      // Must succeed and link to the EXACT same wallet and account without error
      expect(secondLoginSuccess, isTrue);
      expect(reloadedController.isAuthenticated, isTrue);
      expect(reloadedController.currentProfile?.walletAddress, equals(assignedWallet));
      expect(reloadedController.errorMessage, isNull);
    });
  });
}
