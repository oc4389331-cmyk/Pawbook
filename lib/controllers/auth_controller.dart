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
        _renderBackendService = renderBackendService ?? RenderBackendService();

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

  Future<bool> loginWithGoogle() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      // Authenticate via Dynamic.xyz Google OAuth (Solana Mainnet Env ID)
      final res = await _dynamicAuthService.authenticateWithGoogle();

      if (!res.isSuccess || res.walletAddress == null) {
        _errorMessage = res.errorMessage ?? 'Error al autenticar con Google';
        _setLoading(false);
        return false;
      }

      final email = res.email ?? 'user.google@gmail.com';
      final walletAddress = res.walletAddress!;

      await _processAuthenticatedUser(
        walletAddress: walletAddress,
        email: email,
        jwtToken: res.jwtToken ?? 'dyn_jwt_google_${email.hashCode.abs().toRadixString(16)}',
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
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
