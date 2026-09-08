import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../models/pet_model.dart';
import '../services/supabase_service.dart';
import '../services/dynamic_auth_service.dart';
import '../services/render_backend_service.dart';
import '../services/r2_storage_service.dart';
import '../services/auth_storage_service.dart';

class AuthController extends ChangeNotifier {
  final SupabaseService _supabaseService;
  final DynamicAuthService _dynamicAuthService;
  final RenderBackendService _renderBackendService;

  ProfileModel? _currentProfile;
  List<PetModel> _userPets = [];
  PetModel? _activePet;
  bool _isLoading = false;
  String? _errorMessage;
  bool _userLoggedOutExplicitly = false; // Previene restauración de sesión tras logout manual
  bool _pendingIsSignUp = false; // Guarda el modo (signup/login) durante el redirect OAuth de Google

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
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
          final event = data.event;
          final session = data.session;

          // Si el usuario cerró sesión explícitamente, ignorar cualquier restauración
          if (_userLoggedOutExplicitly) {
            debugPrint('[Auth] Sesión ignorada: usuario cerró sesión explícitamente.');
            return;
          }

          // Manejar evento de cierre de sesión
          if (event == AuthChangeEvent.signedOut) {
            debugPrint('[Auth] Evento signedOut recibido.');
            _currentProfile = null;
            _userPets = [];
            _activePet = null;
            notifyListeners();
            return;
          }

          // Restaurar sesión en eventos de inicio (signedIn, tokenRefreshed, initialSession)
          if ((event == AuthChangeEvent.signedIn ||
                  event == AuthChangeEvent.tokenRefreshed ||
                  event == AuthChangeEvent.initialSession) &&
              session?.user != null &&
              _currentProfile == null) {
            final user = session!.user;
            final meta = user.userMetadata ?? {};

            // Extraer datos del perfil de Google OAuth
            final email = user.email ?? meta['email']?.toString();
            final fullName = meta['full_name']?.toString() ??
                meta['name']?.toString();
            final avatarUrl = meta['avatar_url']?.toString() ??
                meta['picture']?.toString();
            final wallet = 'sol_' + user.id.replaceAll('-', '').substring(0, 16);

            debugPrint('[Auth] Google OAuth signedIn: email=$email, name=$fullName');

            // Leer intención OAuth desde almacenamiento persistente (sobrevive redirección en web)
            final storedOauthAction = AuthStorageService.instance.getItem('pawtbook_oauth_action');
            final isSignUpMode = storedOauthAction == 'signup' || _pendingIsSignUp || (kIsWeb && Uri.base.queryParameters['isSignUp'] == 'true');
            final isLoginMode = storedOauthAction == 'login';

            // 1. VALIDACIÓN EN MODO "CREAR CUENTA" (Sign Up):
            // Si el usuario eligió "Crear Cuenta" con Google, pero el correo ya existe en base de datos -> BLOQUEAR
            if (email != null && email.isNotEmpty && isSignUpMode) {
              final existing = await _supabaseService.getProfileByEmail(email);
              if (existing != null) {
                debugPrint('[Auth] Cuenta existente encontrada para $email en modo Crear Cuenta - bloqueando.');
                AuthStorageService.instance.removeItem('pawtbook_oauth_action');
                _pendingIsSignUp = false;
                await Supabase.instance.client.auth.signOut();
                _errorMessage = '⚠️ Este correo ($email) ya tiene una cuenta registrada. Por favor, selecciona "Iniciar Sesión".';
                _setLoading(false);
                notifyListeners();
                return;
              }
            }

            // 2. VALIDACIÓN EN MODO "INICIAR SESIÓN" (Login):
            // Si el usuario eligió "Iniciar Sesión" con Google, pero el correo no existe en base de datos -> BLOQUEAR
            if (email != null && email.isNotEmpty && isLoginMode) {
              final existing = await _supabaseService.getProfileByEmail(email);
              if (existing == null) {
                debugPrint('[Auth] No existe cuenta para $email en modo Iniciar Sesión - bloqueando.');
                AuthStorageService.instance.removeItem('pawtbook_oauth_action');
                await Supabase.instance.client.auth.signOut();
                _errorMessage = '⚠️ No existe una cuenta registrada con el correo ($email). Por favor, ve a "Crear Cuenta".';
                _setLoading(false);
                notifyListeners();
                return;
              }
            }

            // Limpiar la intención de OAuth una vez completada la validación
            AuthStorageService.instance.removeItem('pawtbook_oauth_action');
            _pendingIsSignUp = false;

            await _processAuthenticatedUser(
              walletAddress: wallet,
              email: email,
              fullName: fullName,
              avatarUrl: avatarUrl,
              jwtToken: session.accessToken,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Auth listener error: $e');
    }
  }

  Future<bool> loginWithSolanaWallet({String walletType = 'Phantom'}) async {
    _userLoggedOutExplicitly = false; // El usuario quiere iniciar sesión de nuevo
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

  Future<String?> sendEmailOtp(String email, {bool isSignUp = false, String? fullName}) async {
    _userLoggedOutExplicitly = false; // El usuario quiere iniciar sesión de nuevo
    _setLoading(true);
    _errorMessage = null;

    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      _errorMessage = 'Por favor ingresa un correo electrónico válido (ej. usuario@gmail.com)';
      _setLoading(false);
      notifyListeners();
      return null;
    }

    // Check account existence by email
    final existingProfile = await _supabaseService.getProfileByEmail(cleanEmail);

    if (isSignUp) {
      // Sign Up mode: If email is already in use, reject registration
      if (existingProfile != null) {
        _errorMessage = '⚠️ Este correo ya está en uso con una cuenta. Por favor inicia sesión.';
        _setLoading(false);
        notifyListeners();
        return null;
      }
    } else {
      // Login mode: If no account exists for this email, reject login
      if (existingProfile == null) {
        _errorMessage = '⚠️ No existe ninguna cuenta registrada con este correo. Por favor crea una cuenta primero.';
        _setLoading(false);
        notifyListeners();
        return null;
      }
    }

    try {
      final code = await _dynamicAuthService.sendEmailOTP(cleanEmail);
      _setLoading(false);
      if (code == null) {
        _errorMessage = 'Por favor ingresa un correo electrónico válido (ej. usuario@gmail.com)';
      }
      notifyListeners();
      return code;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  Future<bool> verifyEmailOtpAndLogin(String email, String otpCode, {String? fullName}) async {
    _userLoggedOutExplicitly = false; // El usuario quiere iniciar sesión de nuevo
    _setLoading(true);
    _errorMessage = null;

    try {
      final cleanEmail = email.trim().toLowerCase();
      final res = await _dynamicAuthService.verifyEmailOTP(cleanEmail, otpCode);
      if (!res.isSuccess || res.walletAddress == null) {
        _errorMessage = res.errorMessage ?? '❌ Código de verificación incorrecto';
        _setLoading(false);
        notifyListeners();
        return false;
      }

      await _processAuthenticatedUser(
        walletAddress: res.walletAddress!,
        email: cleanEmail,
        fullName: fullName,
        jwtToken: res.jwtToken ?? '',
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithEmail(String email) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final cleanEmail = email.trim().toLowerCase();
      final res = await _dynamicAuthService.authenticateWithEmail(cleanEmail);
      if (!res.isSuccess || res.walletAddress == null) {
        _errorMessage = res.errorMessage ?? 'Email login failed';
        _setLoading(false);
        notifyListeners();
        return false;
      }

      await _processAuthenticatedUser(
        walletAddress: res.walletAddress!,
        email: cleanEmail,
        jwtToken: res.jwtToken ?? '',
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle({String? googleEmail, bool isSignUp = false, String? fullName}) async {
    _userLoggedOutExplicitly = false; // El usuario quiere iniciar sesión de nuevo
    _pendingIsSignUp = isSignUp; // Guardar modo para validación post-OAuth
    // Persistir la acción elegida en localStorage para sobrevivir la redirección del navegador
    AuthStorageService.instance.setItem('pawtbook_oauth_action', isSignUp ? 'signup' : 'login');
    _setLoading(true);
    _errorMessage = null;

    try {
      // FLUJO PRINCIPAL: Redirigir directamente a Google OAuth
      // Google devolverá email, nombre y avatar al listener onAuthStateChange
      if (Supabase.instance.client != null) {
        try {
          final baseRedirect = kIsWeb
              ? (Uri.base.host.contains('pawbooklife.com')
                  ? 'https://pawbooklife.com'
                  : Uri.base.origin)
              : null;
              
          final redirectTo = baseRedirect != null
              ? (isSignUp ? '$baseRedirect/?isSignUp=true' : baseRedirect)
              : null;

          final launched = await Supabase.instance.client.auth.signInWithOAuth(
            OAuthProvider.google,
            redirectTo: redirectTo,
          );
          if (launched) {
            _setLoading(false);
            // En web: el app hace redirect a Google y regresa.
            // El listener onAuthStateChange manejará el signedIn cuando regrese.
            return true;
          }
        } catch (e) {
          debugPrint('[Auth] Supabase Google OAuth error: $e');
        }
      }

      // Fallback: si Supabase OAuth no está disponible, usar Dynamic.xyz
      if (googleEmail != null && googleEmail.trim().isNotEmpty) {
        final cleanEmail = googleEmail.trim().toLowerCase();
        
        if (isSignUp) {
          final existing = await _supabaseService.getProfileByEmail(cleanEmail);
          if (existing != null) {
            AuthStorageService.instance.removeItem('pawtbook_oauth_action');
            _errorMessage = '⚠️ Este correo ($cleanEmail) ya tiene una cuenta registrada. Por favor, selecciona "Iniciar Sesión".';
            _setLoading(false);
            notifyListeners();
            return false;
          }
        }

        final res = await _dynamicAuthService.authenticateWithGoogle(email: cleanEmail);
        if (res.isSuccess && res.walletAddress != null) {
          await _processAuthenticatedUser(
            walletAddress: res.walletAddress!,
            email: res.email,
            fullName: fullName ?? (cleanEmail.split('@').first),
            jwtToken: res.jwtToken ?? '',
          );
          _setLoading(false);
          return true;
        }
      }

      _errorMessage = '❌ No se pudo iniciar el proceso de autenticación con Google.';
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
    String? fullName,
    String? avatarUrl,
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
    if (profile == null && email != null && email.isNotEmpty) {
      profile = await _supabaseService.getProfileByEmail(email);
    }
    if (profile == null) {
      // Build a readable username from full name or email
      String username;
      if (fullName != null && fullName.trim().isNotEmpty) {
        username = fullName.trim().toLowerCase().replaceAll(' ', '_');
        if (username.length > 20) username = username.substring(0, 20);
      } else if (email != null && email.contains('@')) {
        username = email.split('@').first.toLowerCase();
      } else {
        final subLen = min(8, walletAddress.length);
        username = 'paw_' + walletAddress.substring(0, subLen);
      }

      final subLen = min(8, walletAddress.length);
      profile = await _supabaseService.createProfile(
        ProfileModel(
          id: 'usr_' + walletAddress.substring(0, subLen),
          walletAddress: walletAddress,
          username: username,
          email: email,
          fullName: fullName,
          avatarUrl: avatarUrl,
          pawtScore: 100, // Initial welcome bonus score
          createdAt: DateTime.now(),
        ),
      );
    } else if (profile != null) {
      // Update existing profile with Google data if fields are missing
      bool needsUpdate = false;
      String? updatedName = profile.fullName;
      String? updatedAvatar = profile.avatarUrl;
      String? updatedEmail = profile.email;

      if ((profile.fullName == null || profile.fullName!.isEmpty) &&
          fullName != null && fullName.isNotEmpty) {
        updatedName = fullName;
        needsUpdate = true;
      }
      if ((profile.avatarUrl == null || profile.avatarUrl!.isEmpty) &&
          avatarUrl != null && avatarUrl.isNotEmpty) {
        updatedAvatar = avatarUrl;
        needsUpdate = true;
      }
      if ((profile.email == null || profile.email!.isEmpty) &&
          email != null && email.isNotEmpty) {
        updatedEmail = email;
        needsUpdate = true;
      }
      if (needsUpdate) {
        profile = await _supabaseService.updateProfile(
          profile.copyWith(
            fullName: updatedName,
            avatarUrl: updatedAvatar,
            email: updatedEmail,
          ),
        );
      }
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

      final res = await _renderBackendService.updateProfile(
        id: updated.id,
        username: updated.username,
        fullName: updated.fullName,
        avatarUrl: updated.avatarUrl,
        bio: updated.bio,
      );

      if (res['success'] == true) {
        _currentProfile = updated;
      } else {
        _errorMessage = res['error'] ?? 'Error al actualizar perfil en el servidor';
        _setLoading(false);
        notifyListeners();
        return false;
      }

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

  Future<String?> updateProfileAvatarR2(Uint8List imageBytes, String filename) async {
    if (_currentProfile == null) return null;
    _setLoading(true);
    _errorMessage = null;

    try {
      final oldAvatarUrl = _currentProfile!.avatarUrl;
      final userId = _currentProfile!.id;

      // 1. Request presigned upload URL for avatar
      final uploadRes = await _renderBackendService.requestAvatarUploadUrl(
        userId: userId,
        filename: filename,
      );

      if (uploadRes['success'] != true) {
        _errorMessage = uploadRes['error'] ?? 'No se pudo obtener URL presignada para la foto de perfil.';
        _setLoading(false);
        notifyListeners();
        return null;
      }

      final presignedPutUrl = uploadRes['presignedPutUrl'] as String;
      final publicUrl = uploadRes['publicUrl'] as String;

      // 2. Upload image to Cloudflare R2
      final r2Service = R2StorageService();
      final uploadedUrl = await r2Service.uploadMediaWithPresignedUrl(
        presignedPutUrl: presignedPutUrl,
        publicUrl: publicUrl,
        bytes: imageBytes,
        contentType: 'image/jpeg',
      );

      // 3. Delete previous avatar from Cloudflare R2 if it exists
      if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty && oldAvatarUrl != uploadedUrl) {
        if (oldAvatarUrl.contains('pawbooklife.com') || oldAvatarUrl.contains('avatars/') || oldAvatarUrl.contains('r2')) {
          try {
            await _renderBackendService.deleteR2Object(mediaUrl: oldAvatarUrl);
            debugPrint('[AuthController] 🗑️ Imagen anterior de Cloudflare R2 eliminada: $oldAvatarUrl');
          } catch (e) {
            debugPrint('[AuthController] Error al eliminar imagen anterior de R2: $e');
          }
        }
      }

      // 4. Update profile avatarUrl in Supabase and local state
      await updateCurrentProfile(avatarUrl: uploadedUrl);

      _setLoading(false);
      notifyListeners();
      return uploadedUrl;
    } catch (e) {
      _errorMessage = 'Error al actualizar foto en Cloudflare R2: $e';
      _setLoading(false);
      notifyListeners();
      return null;
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

  Future<void> logout() async {
    // Marcar que el usuario cerró sesión ANTES de limpiar Supabase
    // para que el listener no restaure la sesión
    _userLoggedOutExplicitly = true;
    _currentProfile = null;
    _userPets = [];
    _activePet = null;
    _errorMessage = null;
    notifyListeners();

    try {
      if (Supabase.instance.client != null) {
        // Usar scope global para invalidar tokens en el servidor y limpiar localStorage
        await Supabase.instance.client.auth.signOut(scope: SignOutScope.global);
        debugPrint('[Auth] ✅ Sesión cerrada globalmente en Supabase.');
      }
    } catch (e) {
      debugPrint('[Auth] Error al cerrar sesión en Supabase: $e');
    }
  }

  void resetLogoutState() {
    _userLoggedOutExplicitly = false;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
