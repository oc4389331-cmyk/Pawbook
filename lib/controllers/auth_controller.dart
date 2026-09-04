import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../models/pet_model.dart';
import '../services/supabase_service.dart';
import '../services/dynamic_auth_service.dart';
import '../services/render_backend_service.dart';

class AuthController extends ChangeNotifier {
  final SupabaseService _supabaseService;
  final DynamicAuthService _dynamicAuthService;
  final RenderBackendService _renderBackendService;

  ProfileModel? _currentProfile;
  List<PetModel> _userPets = [];
  PetModel? _activePet;
  bool _isLoading = false;
  String? _errorMessage;

  ProfileModel? get currentProfile => _currentProfile;
  List<PetModel> get userPets => List.unmodifiable(_userPets);
  PetModel? get activePet => _activePet;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _currentProfile != null;
  bool get hasPet => _userPets.isNotEmpty;
  bool get isHumanOnly => _userPets.isEmpty;
  bool get isPetCreator => _userPets.isNotEmpty;

  AuthController({
    SupabaseService? supabaseService,
    DynamicAuthService? dynamicAuthService,
    RenderBackendService? renderBackendService,
  })  : _supabaseService = supabaseService ?? SupabaseService(),
        _dynamicAuthService = dynamicAuthService ?? DynamicAuthService(),
        _renderBackendService = renderBackendService ?? RenderBackendService() {
    _initSupabaseAuthListener();
  }

  void _initSupabaseAuthListener() {
    try {
      if (Supabase.instance.client != null) {
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
          final session = data.session;
          if (session?.user != null && _currentProfile == null) {
            final user = session!.user;
            final email = user.email;
            final wallet = 'sol_' + user.id.replaceAll('-', '').substring(0, 16);
            _processAuthenticatedUser(
              walletAddress: wallet,
              email: email,
              jwtToken: session.accessToken,
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<bool> loginWithSolanaWallet({String walletType = 'Phantom'}) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final res = await _dynamicAuthService.authenticateWithSolanaWallet(walletType: walletType);
      if (!res.isSuccess || res.walletAddress == null) {
        _errorMessage = res.errorMessage ?? 'Wallet authentication failed';
        _setLoading(false);
        return false;
      }

      await _processAuthenticatedUser(
        walletAddress: res.walletAddress!,
        jwtToken: res.jwtToken ?? '',
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<String?> sendEmailOtp(String email) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final code = await _dynamicAuthService.sendEmailOTP(email);
      _setLoading(false);
      if (code == null) {
        _errorMessage = 'Por favor ingresa un correo electrónico válido (ej. usuario@gmail.com)';
      }
      return code;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return null;
    }
  }

  Future<bool> verifyEmailOtpAndLogin(String email, String otpCode) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final res = await _dynamicAuthService.verifyEmailOTP(email, otpCode);
      if (!res.isSuccess || res.walletAddress == null) {
        _errorMessage = res.errorMessage ?? '❌ Código de verificación incorrecto';
        _setLoading(false);
        return false;
      }

      await _processAuthenticatedUser(
        walletAddress: res.walletAddress!,
        email: email,
        jwtToken: res.jwtToken ?? '',
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> loginWithEmail(String email) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final res = await _dynamicAuthService.authenticateWithEmail(email);
      if (!res.isSuccess || res.walletAddress == null) {
        _errorMessage = res.errorMessage ?? 'Email login failed';
        _setLoading(false);
        return false;
      }

      await _processAuthenticatedUser(
        walletAddress: res.walletAddress!,
        email: email,
        jwtToken: res.jwtToken ?? '',
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> loginWithGoogle({String? googleEmail}) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      // Attempt real Supabase Auth Google OAuth flow
      // NOTE: Requires Google provider enabled in Supabase dashboard:
      // Authentication > Providers > Google > Enable
      if (Supabase.instance.client != null) {
        try {
          final launched = await Supabase.instance.client.auth.signInWithOAuth(
            OAuthProvider.google,
            redirectTo: kIsWeb ? Uri.base.origin : null,
          );
          if (launched) {
            _setLoading(false);
            return true;
          }
        } catch (e) {
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('validation_failed') ||
              errorStr.contains('provider') ||
              errorStr.contains('not enabled') ||
              errorStr.contains('unsupported')) {
            _errorMessage =
                '⚙️ Google OAuth no está habilitado en el servidor. Por favor usa la opción de inicio de sesión por correo electrónico con código de verificación. '
                '\n\n(Para el administrador: activar el proveedor Google en Supabase Dashboard → Authentication → Providers → Google)';
            _setLoading(false);
            notifyListeners();
            return false;
          }
          debugPrint('Supabase Google OAuth error: $e');
        }
      }

      _errorMessage =
          '⚙️ El inicio de sesión con Google no está configurado. Usa la opción de correo electrónico con código de verificación.';
      _setLoading(false);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<void> _processAuthenticatedUser({
    required String walletAddress,
    String? email,
    required String jwtToken,
  }) async {
    // 1. Verify with Render backend
    await _renderBackendService.verifyAuth(
      token: jwtToken,
      walletAddress: walletAddress,
      email: email,
    );

    // 2. Query or create Supabase profile
    var profile = await _supabaseService.getProfileByWallet(walletAddress);
    if (profile == null) {
      final subLen = min(8, walletAddress.length);
      final username = 'paw_' + walletAddress.substring(0, subLen);
      profile = await _supabaseService.createProfile(
        ProfileModel(
          id: 'usr_' + walletAddress.substring(0, subLen),
          walletAddress: walletAddress,
          username: username,
          email: email,
          pawtScore: 100, // Initial welcome bonus score
          createdAt: DateTime.now(),
        ),
      );
    }
    _currentProfile = profile;

    // 3. Query user pets
    _userPets = await _supabaseService.getPetsForOwner(_currentProfile!.id);
    if (_userPets.isNotEmpty) {
      _activePet = _userPets.first;
    } else {
      _activePet = null;
    }
    notifyListeners();
  }

  Future<bool> loginWithEmailAndPassword(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final cleanEmail = email.trim();
      final hash = cleanEmail.hashCode.abs().toRadixString(16);
      final walletAddress = 'PawEmb${hash}SolanaWallet';

      await _processAuthenticatedUser(
        walletAddress: walletAddress,
        email: cleanEmail,
        jwtToken: 'dyn_jwt_pwd_$hash',
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<void> registerPet(PetModel pet, {String? ownerEmail, String? ownerPassword}) async {
    _setLoading(true);

    try {
      // 1. If guest, automatically create Tutor profile & Embedded Solana Wallet
      if (_currentProfile == null) {
        final email = (ownerEmail != null && ownerEmail.trim().isNotEmpty)
            ? ownerEmail.trim()
            : 'tutor.${pet.name.toLowerCase()}@gmail.com';
        final hash = email.hashCode.abs().toRadixString(16);
        final walletAddress = 'PawGgl${hash}SolanaWallet';

        await _processAuthenticatedUser(
          walletAddress: walletAddress,
          email: email,
          jwtToken: 'dyn_jwt_pet_${pet.name.toLowerCase()}_$hash',
        );
      }

      // 2. Link pet to owner ID and register in Supabase
      final petWithOwner = pet.copyWith(ownerId: _currentProfile!.id);
      final createdPet = await _supabaseService.createPet(petWithOwner);

      _userPets.add(createdPet);
      _activePet = createdPet;

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<bool> updateCurrentProfile({
    String? username,
    String? fullName,
    String? avatarUrl,
    String? bio,
  }) async {
    if (_currentProfile == null) return false;
    _setLoading(true);

    try {
      final updated = _currentProfile!.copyWith(
        username: username != null && username.trim().isNotEmpty ? username.trim() : _currentProfile!.username,
        fullName: fullName != null && fullName.trim().isNotEmpty ? fullName.trim() : _currentProfile!.fullName,
        avatarUrl: avatarUrl != null && avatarUrl.trim().isNotEmpty ? avatarUrl.trim() : _currentProfile!.avatarUrl,
        bio: bio != null && bio.trim().isNotEmpty ? bio.trim() : _currentProfile!.bio,
      );

      final saved = await _supabaseService.updateProfile(updated);
      _currentProfile = saved;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  void setActivePet(PetModel pet) {
    _activePet = pet;
    notifyListeners();
  }

  void addPawtScore(int amount) {
    if (_currentProfile != null) {
      _currentProfile = _currentProfile!.copyWith(
        pawtScore: _currentProfile!.pawtScore + amount,
      );
      notifyListeners();
    }
  }

  void deductPawtScore(int amount) {
    if (_currentProfile != null && _currentProfile!.pawtScore >= amount) {
      _currentProfile = _currentProfile!.copyWith(
        pawtScore: _currentProfile!.pawtScore - amount,
      );
      notifyListeners();
    }
  }

  void logout() {
    _currentProfile = null;
    _userPets = [];
    _activePet = null;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
