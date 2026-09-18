import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  bool _isPetModeActive = true;

  ProfileModel? get currentProfile => _currentProfile;
  List<PetModel> get userPets => List.unmodifiable(_userPets);
  PetModel? get activePet => _activePet;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _currentProfile != null;
  bool get hasPet => _userPets.isNotEmpty;
  bool get isHumanOnly => _userPets.isEmpty;
  bool get isPetCreator => _userPets.isNotEmpty;
  bool get isPetModeActive => _isPetModeActive && hasPet;

  void setPetModeActive(bool value) {
    _isPetModeActive = value;
    notifyListeners();
  }

  void toggleProfileMode() {
    if (hasPet) {
      _isPetModeActive = !_isPetModeActive;
      notifyListeners();
    }
  }

  AuthController({
    SupabaseService? supabaseService,
    DynamicAuthService? dynamicAuthService,
    RenderBackendService? renderBackendService,
  })  : _supabaseService = supabaseService ?? SupabaseService(),
        _dynamicAuthService = dynamicAuthService ?? DynamicAuthService(),
        _renderBackendService = renderBackendService ?? RenderBackendService() {
    _initSupabaseAuthListener();
    restoreSession();
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
            final isLoginMode = storedOauthAction == 'login' || (kIsWeb && Uri.base.queryParameters['isSignUp'] == 'false');

            // 1. VALIDACIÓN EN MODO "CREAR CUENTA" (Sign Up):
            // Si el usuario eligió "Crear Cuenta" con Google, pero la cuenta ya existe en base de datos -> BLOQUEAR
            if (isSignUpMode) {
              final existingByWallet = await _supabaseService.getProfileByWallet(wallet);
              final existingByEmail = (email != null && email.isNotEmpty) ? await _supabaseService.getProfileByEmail(email) : null;
              final existing = existingByWallet ?? existingByEmail;

              if (existing != null) {
                debugPrint('[Auth] Cuenta existente encontrada para ${email ?? wallet} en modo Crear Cuenta - bloqueando.');
                AuthStorageService.instance.removeItem('pawtbook_oauth_action');
                _pendingIsSignUp = false;
                await Supabase.instance.client.auth.signOut();
                _errorMessage = '⚠️ Este correo (${email ?? "Google"}) ya tiene una cuenta registrada en Pawbook. Por favor, selecciona "Iniciar Sesión".';
                _setLoading(false);
                notifyListeners();
                return;
              }
            }

            // 2. VALIDACIÓN EN MODO "INICIAR SESIÓN" (Login):
            // Si el usuario eligió "Iniciar Sesión" con Google, pero no tiene cuenta creada -> BLOQUEAR
            if (isLoginMode) {
              final existingByWallet = await _supabaseService.getProfileByWallet(wallet);
              final existingByEmail = (email != null && email.isNotEmpty) ? await _supabaseService.getProfileByEmail(email) : null;
              final existing = existingByWallet ?? existingByEmail;

              if (existing == null) {
                debugPrint('[Auth] No existe cuenta para ${email ?? wallet} en modo Iniciar Sesión - bloqueando.');
                AuthStorageService.instance.removeItem('pawtbook_oauth_action');
                await Supabase.instance.client.auth.signOut();
                _errorMessage = '⚠️ No existe una cuenta registrada con el correo (${email ?? "este usuario"}). Por favor, ve a "Crear Cuenta".';
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

  Future<bool> loginWithSolanaWallet({
    String walletType = 'Phantom',
    bool isSignUp = false,
    String? fullName,
    bool forceNew = false,
  }) async {
    _userLoggedOutExplicitly = false; // El usuario quiere iniciar sesión de nuevo
    _setLoading(true);
    _errorMessage = null;

    try {
      final res = await _dynamicAuthService.authenticateWithSolanaWallet(
        walletType: walletType,
        forceNew: forceNew,
      );
      if (!res.isSuccess || res.walletAddress == null) {
        _errorMessage = res.errorMessage ?? 'No se pudo conectar con la wallet $walletType.';
        _setLoading(false);
        notifyListeners();
        return false;
      }

      final walletAddr = res.walletAddress!;

      // Validar existencia de perfil en Supabase
      final existingProfile = await _supabaseService.getProfileByWallet(walletAddr);

      // Web3 UX: Autenticación transparente e inmediata
      // Si el perfil ya existe, ingresa directo a su cuenta existente
      // Si no existe, crea automáticamente su perfil sin bloqueos ni errores de pestaña
      await _processAuthenticatedUser(
        walletAddress: walletAddr,
        fullName: fullName,
        jwtToken: res.jwtToken ?? '',
        existingProfile: existingProfile,
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
      // 1. In-App Direct Authentication when email is provided (Zero external browser redirect)
      if (googleEmail != null && googleEmail.trim().isNotEmpty) {
        final cleanEmail = googleEmail.trim().toLowerCase();
        final existing = await _supabaseService.getProfileByEmail(cleanEmail);

        if (isSignUp) {
          if (existing != null) {
            AuthStorageService.instance.removeItem('pawtbook_oauth_action');
            _errorMessage = '⚠️ Este correo ($cleanEmail) ya tiene una cuenta registrada. Por favor, selecciona "Iniciar Sesión".';
            _setLoading(false);
            notifyListeners();
            return false;
          }
        } else {
          if (existing == null) {
            AuthStorageService.instance.removeItem('pawtbook_oauth_action');
            _errorMessage = '⚠️ No existe una cuenta registrada con el correo ($cleanEmail). Por favor, ve a "Crear Cuenta".';
            _setLoading(false);
            notifyListeners();
            return false;
          }
        }

        final res = await _dynamicAuthService.authenticateWithGoogle(email: cleanEmail);
        final walletAddress = existing?.walletAddress ?? res.walletAddress ?? 'sol_${cleanEmail.hashCode.abs()}';

        await _processAuthenticatedUser(
          walletAddress: walletAddress,
          email: cleanEmail,
          fullName: existing?.fullName ?? fullName ?? (cleanEmail.split('@').first),
          jwtToken: res.jwtToken ?? '',
          existingProfile: existing,
        );
        _setLoading(false);
        return true;
      }

      // 2. Native Mobile 1-Tap Google Sign-In with Device Account Picker (Zero Browser Redirect)
      if (!kIsWeb) {
        try {
          final GoogleSignIn googleSignIn = GoogleSignIn(
            scopes: ['email', 'profile'],
          );

          // Try silent sign-in first (if already logged in on device)
          GoogleSignInAccount? account;
          try {
            account = await googleSignIn.signInSilently();
          } catch (_) {}

          // Otherwise show native Android Google Account picker
          account ??= await googleSignIn.signIn();

          if (account != null) {
            final userEmail = account.email.trim().toLowerCase();
            final userName = account.displayName ?? (fullName ?? userEmail.split('@').first);
            final userPhoto = account.photoUrl;

            // Attempt to fetch ID token if available, but do not block login if unavailable
            String? idToken;
            try {
              final auth = await account.authentication;
              idToken = auth.idToken;
              if (idToken != null) {
                try {
                  await Supabase.instance.client.auth.signInWithIdToken(
                    provider: OAuthProvider.google,
                    idToken: idToken,
                    accessToken: auth.accessToken,
                  );
                } catch (e) {
                  debugPrint('Supabase signInWithIdToken note: $e');
                }
              }
            } catch (e) {
              debugPrint('Auth token extraction note: $e');
            }

            // Strictly verify account in Supabase
            final existing = await _supabaseService.getProfileByEmail(userEmail);

            if (isSignUp) {
              if (existing != null) {
                _errorMessage = '⚠️ Este correo ($userEmail) ya tiene una cuenta registrada. Por favor, selecciona "Iniciar Sesión".';
                _setLoading(false);
                notifyListeners();
                return false;
              }
            } else {
              if (existing == null) {
                _errorMessage = '⚠️ No existe una cuenta registrada con el correo ($userEmail). Por favor, ve a "Crear Cuenta".';
                _setLoading(false);
                notifyListeners();
                return false;
              }
            }

            String walletAddress;
            String jwtToken;

            if (existing != null) {
              walletAddress = existing.walletAddress;
              jwtToken = idToken ?? 'dyn_jwt_g_${userEmail.hashCode.abs().toRadixString(16)}';
            } else {
              final res = await _dynamicAuthService.authenticateWithGoogle(email: userEmail);
              walletAddress = res.walletAddress ?? 'sol_${userEmail.hashCode.abs()}';
              jwtToken = idToken ?? res.jwtToken ?? 'dyn_jwt_g_${userEmail.hashCode.abs().toRadixString(16)}';
            }

            await _processAuthenticatedUser(
              walletAddress: walletAddress,
              email: userEmail,
              fullName: userName,
              avatarUrl: userPhoto,
              jwtToken: jwtToken,
              existingProfile: existing,
            );

            _setLoading(false);
            notifyListeners();
            return true;
          } else {
            // User cancelled Google Account selection dialog
            _setLoading(false);
            notifyListeners();
            return false;
          }
        } catch (e) {
          debugPrint('Native Google Sign-In note: $e');
          final errStr = e.toString();
          if (errStr.contains('10') || errStr.contains('sign_in_failed')) {
            _errorMessage = 'Falta registrar la huella SHA-1 de Android en tu proyecto de Google Cloud.';
          } else {
            _errorMessage = 'Error al iniciar sesión con Google: $e';
          }
          _setLoading(false);
          notifyListeners();
          return false;
        }
      }

      // 3. Web Redirect OAuth only for Web browsers
      if (kIsWeb && Supabase.instance.client != null) {
        try {
          final baseRedirect = Uri.base.host.contains('pawbooklife.com')
              ? 'https://pawbooklife.com'
              : (Uri.base.host.contains('onrender.com')
                  ? 'https://pawbook-358b.onrender.com'
                  : 'http://localhost:3000');

          _pendingIsSignUp = isSignUp;
          AuthStorageService.instance.setItem('pawtbook_oauth_action', isSignUp ? 'signup' : 'login');

          await Supabase.instance.client.auth.signInWithOAuth(
            OAuthProvider.google,
            redirectTo: '$baseRedirect?isSignUp=$isSignUp',
          );
          return true;
        } catch (e) {
          debugPrint('[Auth] Supabase Google OAuth error: $e');
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
    ProfileModel? existingProfile,
  }) async {
    // 1. Resolve profile
    var profile = existingProfile;
    if (profile == null && email != null && email.isNotEmpty) {
      profile = await _supabaseService.getProfileByEmail(email);
    }
    if (profile == null && walletAddress.isNotEmpty) {
      profile = await _supabaseService.getProfileByWallet(walletAddress);
    }

    if (profile == null) {
      // New user creation
      await _renderBackendService.verifyAuth(
        token: jwtToken,
        walletAddress: walletAddress,
        email: email,
      );

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

    // Provision / sync with Dynamic.xyz Cloud Dashboard (For ALL accounts: Email, Google, or Solana Wallet)
    if (_currentProfile != null) {
      final syncEmail = (_currentProfile!.email != null && _currentProfile!.email!.isNotEmpty)
          ? _currentProfile!.email!
          : '${_currentProfile!.username.toLowerCase()}@pawtbooklife.com';

      _renderBackendService.provisionDynamicUser(
        email: syncEmail,
        username: _currentProfile!.username,
        fullName: _currentProfile!.fullName,
        walletAddress: _currentProfile!.walletAddress,
      ).ignore();

      _dynamicAuthService.syncWalletWithDynamic(
        walletAddress: _currentProfile!.walletAddress,
        email: syncEmail,
        username: _currentProfile!.username,
      ).ignore();
    }

    // 3. Query user pets and ensure Dynamic Solana Wallet Address is assigned
    final rawPets = await _supabaseService.getPetsForOwner(_currentProfile!.id);
    _userPets = rawPets.map((p) {
      if (p.nftMintAddress == null || p.nftMintAddress!.isEmpty) {
        return p.copyWith(nftMintAddress: p.dynamicWalletAddress);
      }
      return p;
    }).toList();

    if (_userPets.isNotEmpty) {
      _activePet = _userPets.first;
    } else {
      _activePet = null;
    }

    // 4. Save persistent session to device storage (Auto-Login across restarts)
    try {
      final storage = AuthStorageService.instance;
      storage.setItem('pawtbook_logged_user_id', _currentProfile!.id);
      storage.setItem('pawtbook_logged_wallet', _currentProfile!.walletAddress);
      if (_currentProfile!.email != null && _currentProfile!.email!.isNotEmpty) {
        storage.setItem('pawtbook_logged_email', _currentProfile!.email!);
      }
      storage.setItem('pawtbook_cached_profile', jsonEncode(_currentProfile!.toJson()));
      storage.setItem('pawtbook_logged_out', 'false');
      _userLoggedOutExplicitly = false;
      debugPrint('[Auth] 💾 Sesión guardada de forma persistente: ${_currentProfile!.username} (${_currentProfile!.id})');
    } catch (e) {
      debugPrint('[Auth] Error guardando sesión en almacenamiento persistente: $e');
    }

    notifyListeners();
  }

  /// Restaura la sesión guardada del usuario al abrir la app (Auto-Login instantáneo)
  Future<bool> restoreSession() async {
    try {
      final storage = AuthStorageService.instance;
      final isLoggedOut = storage.getItem('pawtbook_logged_out') == 'true';
      if (isLoggedOut || _userLoggedOutExplicitly) {
        debugPrint('[Auth] No se restaura sesión: usuario cerró sesión explícitamente.');
        return false;
      }

      final savedUserId = storage.getItem('pawtbook_logged_user_id');
      final savedWallet = storage.getItem('pawtbook_logged_wallet');
      final savedEmail = storage.getItem('pawtbook_logged_email');
      final cachedProfileStr = storage.getItem('pawtbook_cached_profile');

      if ((savedUserId == null || savedUserId.isEmpty) &&
          (savedWallet == null || savedWallet.isEmpty) &&
          (savedEmail == null || savedEmail.isEmpty)) {
        return false;
      }

      debugPrint('[Auth] 🔄 Auto-Login: Restaurando sesión para $savedUserId / $savedEmail / $savedWallet');

      // 1. Restauración instantánea desde caché local (0 ms de espera)
      if (cachedProfileStr != null && cachedProfileStr.isNotEmpty) {
        try {
          final jsonMap = jsonDecode(cachedProfileStr) as Map<String, dynamic>;
          _currentProfile = ProfileModel.fromJson(jsonMap);
          notifyListeners();
        } catch (_) {}
      }

      // 2. Consulta y sincronización en segundo plano con Supabase
      ProfileModel? freshProfile;
      if (savedUserId != null && savedUserId.isNotEmpty) {
        freshProfile = await _supabaseService.getProfileById(savedUserId);
      }
      if (freshProfile == null && savedEmail != null && savedEmail.isNotEmpty) {
        freshProfile = await _supabaseService.getProfileByEmail(savedEmail);
      }
      if (freshProfile == null && savedWallet != null && savedWallet.isNotEmpty) {
        freshProfile = await _supabaseService.getProfileByWallet(savedWallet);
      }

      if (freshProfile != null) {
        _currentProfile = freshProfile;
        storage.setItem('pawtbook_cached_profile', jsonEncode(freshProfile.toJson()));
      }

      if (_currentProfile == null) {
        debugPrint('[Auth] ⚠️ No se pudo resolver perfil para sesión guardada.');
        return false;
      }

      // 3. Carga de mascotas del usuario
      final rawPets = await _supabaseService.getPetsForOwner(_currentProfile!.id);
      _userPets = rawPets.map((p) {
        if (p.nftMintAddress == null || p.nftMintAddress!.isEmpty) {
          return p.copyWith(nftMintAddress: p.dynamicWalletAddress);
        }
        return p;
      }).toList();

      if (_userPets.isNotEmpty) {
        _activePet = _userPets.first;
      } else {
        _activePet = null;
      }

      // 4. Refresco silencioso de Google en Android si aplica
      if (!kIsWeb) {
        try {
          final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
          googleSignIn.signInSilently().catchError((_) => null);
        } catch (_) {}
      }

      notifyListeners();
      debugPrint('[Auth] ✅ Auto-Login completado: ${_currentProfile!.username} | Mascota activa: ${_activePet?.name}');
      return true;
    } catch (e) {
      debugPrint('[Auth] Error al restaurar sesión: $e');
      return false;
    }
  }

  void setProfileForTesting(ProfileModel? profile, [List<PetModel>? pets]) {
    _currentProfile = profile;
    if (pets != null) {
      _userPets = pets;
      _activePet = pets.isNotEmpty ? pets.first : null;
    }
    notifyListeners();
  }

  Future<bool> loginWithEmailAndPassword(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final cleanEmail = email.trim();
      final authRes = await _dynamicAuthService.authenticateWithGoogle(email: cleanEmail);
      final walletAddress = authRes.walletAddress ?? 'sol_${cleanEmail.hashCode.abs()}';

      await _processAuthenticatedUser(
        walletAddress: walletAddress,
        email: cleanEmail,
        jwtToken: authRes.jwtToken ?? 'dyn_jwt_pwd_${cleanEmail.hashCode.abs().toRadixString(16)}',
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<void> registerPet(PetModel pet, {String? customPayoutWallet}) async {
    _setLoading(true);

    try {
      // 1. If guest, automatically create Tutor profile & Embedded Solana Wallet
      if (_currentProfile == null) {
        final generatedWallet = 'sol_${DateTime.now().millisecondsSinceEpoch}';
        await _processAuthenticatedUser(
          walletAddress: generatedWallet,
          fullName: 'Tutor de ${pet.name}',
          jwtToken: 'dyn_jwt_guest_$generatedWallet',
        );
      }

      // 2. Link pet to owner ID and ensure the connected wallet is assigned as the benefit/payout wallet
      final petWallet = (customPayoutWallet != null && customPayoutWallet.isNotEmpty)
          ? customPayoutWallet
          : (pet.nftMintAddress != null && pet.nftMintAddress!.isNotEmpty
              ? pet.nftMintAddress!
              : (_currentProfile?.walletAddress ?? pet.dynamicWalletAddress));

      final petWithOwner = pet.copyWith(
        ownerId: _currentProfile!.id,
        nftMintAddress: petWallet,
      );
      PetModel createdPet;
      try {
        createdPet = await _supabaseService.createPet(petWithOwner);
      } catch (e) {
        debugPrint('[AuthController] registerPet Supabase fallback: $e');
        createdPet = petWithOwner;
      }

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

  /// Update Pet Avatar in Cloudflare R2, delete previous image, and sync Supabase
  Future<bool> updatePetAvatarR2({
    required String petId,
    required Uint8List imageBytes,
    required String filename,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final petIndex = _userPets.indexWhere((p) => p.id == petId);
      final pet = petIndex >= 0 ? _userPets[petIndex] : (_activePet?.id == petId ? _activePet : null);
      if (pet == null) {
        _errorMessage = 'Mascota no encontrada en la cuenta actual';
        _setLoading(false);
        notifyListeners();
        return false;
      }

      final oldAvatarUrl = pet.avatarUrl;

      // 1. Request presigned upload URL for pet avatar
      final uploadRes = await _renderBackendService.requestAvatarUploadUrl(
        userId: 'pet_$petId',
        filename: filename,
      );

      if (uploadRes['success'] != true) {
        _errorMessage = 'No se pudo generar la autorización para subir la foto.';
        _setLoading(false);
        notifyListeners();
        return false;
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

      // 3. Delete previous avatar from Cloudflare R2 if it was an R2 URL
      if (oldAvatarUrl.isNotEmpty && oldAvatarUrl != uploadedUrl) {
        if (oldAvatarUrl.contains('pawbooklife.com') || oldAvatarUrl.contains('avatars/') || oldAvatarUrl.contains('r2')) {
          try {
            await _renderBackendService.deleteR2Object(mediaUrl: oldAvatarUrl);
            debugPrint('[AuthController] 🗑️ Foto anterior de mascota eliminada de Cloudflare R2: $oldAvatarUrl');
          } catch (e) {
            debugPrint('[AuthController] Error al eliminar foto anterior de R2: $e');
          }
        }
      }

      // 4. Update pet in Supabase
      final updatedPet = pet.copyWith(avatarUrl: uploadedUrl);
      await _supabaseService.updatePet(updatedPet);
      await _renderBackendService.updatePet(id: updatedPet.id, avatarUrl: uploadedUrl);

      // 5. Update local state
      if (petIndex >= 0) {
        _userPets[petIndex] = updatedPet;
      }
      if (_activePet?.id == petId) {
        _activePet = updatedPet;
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[AuthController] Error al actualizar foto de mascota: $e');
      _errorMessage = 'No se pudo completar la actualización de la foto de perfil.';
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
      try {
        _supabaseService.updateProfile(_currentProfile!);
      } catch (e) {
        debugPrint('[Auth] Error persisting addPawtScore to Supabase: $e');
      }
    }
  }

  void deductPawtScore(int amount) {
    if (_currentProfile != null && _currentProfile!.pawtScore >= amount) {
      _currentProfile = _currentProfile!.copyWith(
        pawtScore: _currentProfile!.pawtScore - amount,
      );
      notifyListeners();
      try {
        _supabaseService.updateProfile(_currentProfile!);
      } catch (e) {
        debugPrint('[Auth] Error persisting deductPawtScore to Supabase: $e');
      }
    }
  }

  Future<void> logout() async {
    _userLoggedOutExplicitly = true;
    _currentProfile = null;
    _userPets = [];
    _activePet = null;
    _errorMessage = null;

    try {
      final storage = AuthStorageService.instance;
      storage.removeItem('pawtbook_logged_user_id');
      storage.removeItem('pawtbook_logged_wallet');
      storage.removeItem('pawtbook_logged_email');
      storage.removeItem('pawtbook_cached_profile');
      storage.removeItem('pawtbook_auth_provider');
      storage.setItem('pawtbook_logged_out', 'true');
      debugPrint('[Auth] 🧹 Almacenamiento persistente de sesión limpiado.');
    } catch (e) {
      debugPrint('[Auth] Error limpiando almacenamiento persistente: $e');
    }

    if (!kIsWeb) {
      try {
        final googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
      } catch (_) {}
    }

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
