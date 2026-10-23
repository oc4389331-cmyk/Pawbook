import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pawtbook/controllers/auth_controller.dart';
import 'package:pawtbook/models/profile_model.dart';
import 'package:pawtbook/services/auth_storage_service.dart';
import 'package:pawtbook/services/supabase_service.dart';
import 'package:pawtbook/services/dynamic_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthStorageService.instance.init();
    AuthStorageService.instance.removeItem('pawtbook_logged_user_id');
    AuthStorageService.instance.removeItem('pawtbook_logged_wallet');
    AuthStorageService.instance.removeItem('pawtbook_logged_email');
    AuthStorageService.instance.removeItem('pawtbook_oauth_action');
    AuthStorageService.instance.setItem('pawtbook_logged_out', 'true');
  });

  group('Google Auth Sign-Up Validation & Duplicate Prevention Tests', () {
    const existingGoogleEmail = 'lucas_owner@gmail.com';
    const existingGoogleWallet = 'sol_existing_wallet_987';
    final existingProfile = ProfileModel(
      id: 'usr_google_existing_1',
      walletAddress: existingGoogleWallet,
      username: 'lucas_owner',
      fullName: 'Lucas Pet Parent',
      email: existingGoogleEmail,
      createdAt: DateTime.now(),
    );

    test('1. Crear Cuenta con Google rechaza si el usuario ya existe y no permite continuar', () async {
      final supabaseService = SupabaseService(useMockFallback: true);
      await supabaseService.createProfile(existingProfile);

      final authController = AuthController(
        supabaseService: supabaseService,
        dynamicAuthService: DynamicAuthService(),
      );

      // Intento de "Crear Cuenta" (isSignUp: true) con correo ya registrado
      final signUpSuccess = await authController.loginWithGoogle(
        googleEmail: existingGoogleEmail,
        isSignUp: true,
        fullName: 'Lucas Fake New Name',
      );

      // Debe rechazar la creación de cuenta
      expect(signUpSuccess, isFalse);
      expect(authController.isAuthenticated, isFalse);
      expect(authController.currentProfile, isNull);
      expect(authController.errorMessage, isNotNull);
      expect(authController.errorMessage, contains('ya está registrada con Google'));
      expect(authController.errorMessage, contains('Por favor, selecciona "Iniciar Sesión" para entrar.'));

      // Verificar que NO se modificó ni creó perfil duplicado
      final checkProfile = await supabaseService.getProfileByEmail(existingGoogleEmail);
      expect(checkProfile?.id, equals('usr_google_existing_1'));
      expect(checkProfile?.fullName, equals('Lucas Pet Parent'));
    });

    test('2. handleGoogleAuthResult en modo Crear Cuenta (Web OAuth / 1-Tap) bloquea si ya existe', () async {
      final supabaseService = SupabaseService(useMockFallback: true);
      await supabaseService.createProfile(existingProfile);

      final authController = AuthController(
        supabaseService: supabaseService,
        dynamicAuthService: DynamicAuthService(),
      );

      // Simular retorno de Google OAuth con intención de Crear Cuenta (isSignUp: true)
      AuthStorageService.instance.setItem('pawtbook_oauth_action', 'signup');

      final result = await authController.handleGoogleAuthResult(
        email: existingGoogleEmail,
        fullName: 'Lucas Another Attempt',
        userId: 'google_uid_existing_123',
        isSignUp: true,
      );

      expect(result, isFalse);
      expect(authController.isAuthenticated, isFalse);
      expect(authController.currentProfile, isNull);
      expect(authController.errorMessage, contains('ya está registrada con Google'));
      expect(AuthStorageService.instance.getItem('pawtbook_oauth_action'), isNull);
    });

    test('3. Iniciar Sesión con Google rechaza si la cuenta NO existe y pide crear cuenta', () async {
      final supabaseService = SupabaseService(useMockFallback: true);
      final authController = AuthController(
        supabaseService: supabaseService,
        dynamicAuthService: DynamicAuthService(),
      );

      const nonExistentEmail = 'never_registered@gmail.com';

      // Intento de "Iniciar Sesión" (isSignUp: false) con correo no registrado
      final loginSuccess = await authController.loginWithGoogle(
        googleEmail: nonExistentEmail,
        isSignUp: false,
      );

      expect(loginSuccess, isFalse);
      expect(authController.isAuthenticated, isFalse);
      expect(authController.currentProfile, isNull);
      expect(authController.errorMessage, isNotNull);
      expect(authController.errorMessage, contains('No existe una cuenta registrada con este correo de Google'));
      expect(authController.errorMessage, contains('Por favor, ve a "Crear Cuenta".'));
    });

    test('4. Iniciar Sesión con Google exitoso si la cuenta ya existe', () async {
      final supabaseService = SupabaseService(useMockFallback: true);
      await supabaseService.createProfile(existingProfile);

      final authController = AuthController(
        supabaseService: supabaseService,
        dynamicAuthService: DynamicAuthService(),
      );

      // Iniciar sesión (isSignUp: false) con la cuenta registrada
      final loginSuccess = await authController.loginWithGoogle(
        googleEmail: existingGoogleEmail,
        isSignUp: false,
      );

      expect(loginSuccess, isTrue);
      expect(authController.isAuthenticated, isTrue);
      expect(authController.currentProfile?.id, equals('usr_google_existing_1'));
      expect(authController.currentProfile?.email, equals(existingGoogleEmail));
      expect(authController.errorMessage, isNull);
    });

    test('5. Crear Cuenta con Google exitosa para usuario completamente nuevo', () async {
      final supabaseService = SupabaseService(useMockFallback: true);
      final authController = AuthController(
        supabaseService: supabaseService,
        dynamicAuthService: DynamicAuthService(),
      );

      const brandNewEmail = 'brand_new_dog_lover@gmail.com';

      // Crear cuenta con usuario nuevo
      final signUpSuccess = await authController.loginWithGoogle(
        googleEmail: brandNewEmail,
        isSignUp: true,
        fullName: 'New Dog Lover',
      );

      expect(signUpSuccess, isTrue);
      expect(authController.isAuthenticated, isTrue);
      expect(authController.currentProfile?.email, equals(brandNewEmail));
      expect(authController.errorMessage, isNull);

      // Verificar que el nuevo perfil fue persistido en la base de datos
      final persistedProfile = await supabaseService.getProfileByEmail(brandNewEmail);
      expect(persistedProfile, isNotNull);
      expect(persistedProfile?.email, equals(brandNewEmail));
    });
  });
}
