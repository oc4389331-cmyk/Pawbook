import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/language_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/language_selector.dart';
import '../widgets/terms_and_conditions_modal.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool initialIsSignUp;
  final bool termsAcceptedInitially;

  const LoginScreen({
    super.key,
    this.initialIsSignUp = false,
    this.termsAcceptedInitially = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();

  late bool _isSignUp; // false = Iniciar Sesión, true = Crear Cuenta
  late bool _acceptedTerms;

  // Controlador de animación para el loader de patita
  late AnimationController _pawAnimController;
  late Animation<double> _pawScaleAnim;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
    _acceptedTerms = widget.termsAcceptedInitially;

    // Inicializar animación de patita
    _pawAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pawScaleAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pawAnimController, curve: Curves.easeInOut),
    );

    // Restablecer estado de logout para permitir nuevo inicio de sesión
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authController = Provider.of<AuthController>(context, listen: false);
        authController.resetLogoutState();
        if (authController.isAuthenticated) {
          _onLoginSuccess();
        }
      }
    });
  }

  @override
  void dispose() {
    _pawAnimController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onLoginSuccess() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  bool _validateTermsForSignUp(LanguageController langController) {
    if (_isSignUp && !_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryTerracotta,
          content: Text(
            langController.t('termsRequiredNotice'),
            style: GoogleFonts.fredoka(color: Colors.white),
          ),
          action: SnackBarAction(
            label: langController.t('viewTerms'),
            textColor: Colors.white,
            onPressed: () => TermsAndConditionsModal.show(context, showAuthButtons: false),
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _handleGoogleSignIn(AuthController authController, LanguageController langController) async {
    if (!_validateTermsForSignUp(langController)) return;
    await authController.loginWithGoogle(
      isSignUp: _isSignUp,
      fullName: _isSignUp && _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : null,
    );
  }

  Future<void> _handleWalletSignIn(
    AuthController authController,
    LanguageController langController, {
    required String walletType,
  }) async {
    if (!_validateTermsForSignUp(langController)) return;
    final success = await authController.loginWithSolanaWallet(
      walletType: walletType,
      isSignUp: _isSignUp,
      fullName: _isSignUp && _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : null,
    );
    if (success && mounted) {
      _onLoginSuccess();
    }
  }

  void _showOtherWalletsModal(AuthController authController, LanguageController langController) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.bgWarmCream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primaryTerracotta, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    langController.t('selectSolanaWalletModalTitle'),
                    style: GoogleFonts.fredoka(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                langController.t('selectSolanaWalletModalSubtitle'),
                style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Option 1: Solana Mobile / Seeker Seed Vault
              _buildModalWalletOption(
                title: langController.t('seekerVaultTitle'),
                subtitle: langController.t('seekerVaultSubtitle'),
                iconWidget: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_android_rounded, color: Colors.deepPurple),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleWalletSignIn(authController, langController, walletType: 'Seeker');
                },
              ),
              const SizedBox(height: 10),

              // Option 2: Generic Solana In-App / Embedded Web3 Wallet
              _buildModalWalletOption(
                title: langController.t('embeddedWeb3WalletTitle'),
                subtitle: langController.t('embeddedWeb3WalletSubtitle'),
                iconWidget: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flash_on_rounded, color: AppTheme.emeraldGreen),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleWalletSignIn(authController, langController, walletType: 'Dynamic');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalWalletOption({
    required String title,
    required String subtitle,
    required Widget iconWidget,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWarm,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderWarm),
        ),
        child: Row(
          children: [
            iconWidget,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.fredoka(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppTheme.textMutedWarm,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMutedWarm),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsAndConditionsCheckbox(LanguageController langController) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _acceptedTerms
            ? AppTheme.emeraldGreen.withOpacity(0.08)
            : AppTheme.surfaceWarm,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _acceptedTerms ? AppTheme.emeraldGreen.withOpacity(0.5) : AppTheme.borderWarm,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: _acceptedTerms,
            activeColor: AppTheme.primaryTerracotta,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            onChanged: (val) {
              setState(() => _acceptedTerms = val ?? false);
            },
          ),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (langController.t('termsAcceptPrefix').isNotEmpty)
                  Text(
                    langController.t('termsAcceptPrefix'),
                    style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textPrimaryDark),
                  ),
                GestureDetector(
                  onTap: () => TermsAndConditionsModal.show(context, showAuthButtons: false),
                  child: Text(
                    langController.t('termsAcceptLink'),
                    style: GoogleFonts.fredoka(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTerracotta,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton(AuthController authController, LanguageController langController) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimaryDark,
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppTheme.borderWarm, width: 1.5),
          ),
        ),
        onPressed: authController.isLoading ? null : () => _handleGoogleSignIn(authController, langController),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF4285F4),
                shape: BoxShape.circle,
              ),
              child: const Text(
                'G',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _isSignUp ? langController.t('signUpWithGoogle') : langController.t('loginWithGoogle'),
              style: GoogleFonts.fredoka(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhantomButton(AuthController authController, LanguageController langController) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFAB9FF2), // Branded Phantom Purple
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: const Color(0xFFAB9FF2).withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        onPressed: authController.isLoading
            ? null
            : () => _handleWalletSignIn(authController, langController, walletType: 'Phantom'),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: const Text(
                '👻',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _isSignUp ? langController.t('signUpWithPhantom') : langController.t('loginWithPhantom'),
              style: GoogleFonts.fredoka(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2C194D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolflareButton(AuthController authController, LanguageController langController) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFC7227), // Branded Solflare Flame
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: const Color(0xFFFC7227).withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        onPressed: authController.isLoading
            ? null
            : () => _handleWalletSignIn(authController, langController, walletType: 'Solflare'),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: const Text(
                '🔥',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _isSignUp ? langController.t('signUpWithSolflare') : langController.t('loginWithSolflare'),
              style: GoogleFonts.fredoka(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherWalletsButton(AuthController authController, LanguageController langController) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryTerracotta,
          backgroundColor: AppTheme.surfaceWarm,
          side: const BorderSide(color: AppTheme.borderWarm, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        onPressed: authController.isLoading ? null : () => _showOtherWalletsModal(authController, langController),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppTheme.primaryTerracotta),
            const SizedBox(width: 8),
            Text(
              langController.t('otherSolanaWallets'),
              style: GoogleFonts.fredoka(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTerracotta,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final langController = Provider.of<LanguageController>(context);

    // Detectar autenticación exitosa (p.ej. luego de Google OAuth)
    if (authController.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onLoginSuccess();
      });
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.bgWarmCream,
          body: SafeArea(
            child: Column(
              children: [
                // Language Selector Bar at Top
                Padding(
                  padding: const EdgeInsets.only(top: 12, right: 20),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: const LanguageSelector(),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // App Hero Logo Card
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceWarm,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryTerracotta.withOpacity(0.12),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                              border: Border.all(color: AppTheme.cardWarm, width: 3),
                            ),
                            child: const Icon(
                              Icons.pets_rounded,
                              size: 56,
                              color: AppTheme.primaryTerracotta,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            langController.t('appName'),
                            style: GoogleFonts.fredoka(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTerracotta,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            langController.t('appTagline'),
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: AppTheme.textMutedWarm,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),

                          // Architecture Badges Pill
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildChip('Solana Web3', AppTheme.pastelLavender, AppTheme.solanaPurple),
                              _buildChip('Phantom & Solflare', AppTheme.pastelPeach, AppTheme.brandCoral),
                              _buildChip('Google Auth', AppTheme.pastelSkyBlue, const Color(0xFF1976D2)),
                              _buildChip('Cloudflare R2', AppTheme.pastelMint, AppTheme.emeraldGreen),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Error Banner
                          if (authController.errorMessage != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.redAccent, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      authController.errorMessage!,
                                      style: GoogleFonts.outfit(
                                        color: Colors.red.shade900,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                                    onPressed: () => authController.clearError(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // --- MODE SELECTOR TABS (Iniciar Sesión / Crear Cuenta) ---
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceWarm,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.borderWarm),
                            ),
                            child: Row(
                              children: [
                                // Botón Iniciar Sesión
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      authController.clearError();
                                      setState(() {
                                        _isSignUp = false;
                                        _nameController.clear();
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: !_isSignUp
                                            ? AppTheme.primaryTerracotta
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: Text(
                                          langController.t('loginTab'),
                                          style: GoogleFonts.fredoka(
                                            color: !_isSignUp ? Colors.white : AppTheme.textMutedWarm,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Botón Crear Cuenta
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      authController.clearError();
                                      setState(() {
                                        _isSignUp = true;
                                        _nameController.clear();
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _isSignUp
                                            ? AppTheme.accentOrange
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: Text(
                                          langController.t('signUpTab'),
                                          style: GoogleFonts.fredoka(
                                            color: _isSignUp ? Colors.white : AppTheme.textMutedWarm,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Título y Subtítulo según el modo
                          Text(
                            _isSignUp ? langController.t('signUpTitle') : langController.t('loginTitle'),
                            style: GoogleFonts.fredoka(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _isSignUp ? AppTheme.accentOrange : AppTheme.primaryTerracotta,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isSignUp
                                ? langController.t('signUpSubtitle')
                                : langController.t('loginSubtitle'),
                            style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMutedWarm),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),

                          // Campo opcional de nombre (solo en Crear Cuenta)
                          if (_isSignUp) ...[
                            TextField(
                              controller: _nameController,
                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                hintText: langController.t('tutorNameHint'),
                                hintStyle: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 13),
                                prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.accentOrange),
                                filled: true,
                                fillColor: AppTheme.surfaceWarm,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppTheme.accentOrange, width: 2)),
                              ),
                              style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark),
                            ),
                            _buildTermsAndConditionsCheckbox(langController),
                            const SizedBox(height: 12),
                          ],

                          // --- BOTÓN GOOGLE ---
                          _buildGoogleButton(authController, langController),
                          const SizedBox(height: 20),

                          // Divisor Solana Web3
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  langController.t('orAccessWithSolanaWallet'),
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppTheme.textMutedWarm,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // --- BOTÓN PHANTOM WALLET ---
                          _buildPhantomButton(authController, langController),
                          const SizedBox(height: 12),

                          // --- BOTÓN SOLFLARE WALLET ---
                          _buildSolflareButton(authController, langController),
                          const SizedBox(height: 12),

                          // --- BOTÓN OTRAS WALLETS DE SOLANA ---
                          _buildOtherWalletsButton(authController, langController),
                          const SizedBox(height: 24),

                          // Tarjeta informativa sobre la billetera de beneficios
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.pastelMint,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.accentTeaGreen, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.emeraldGreen.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.accentTeaGreen),
                                  ),
                                  child: const Icon(Icons.verified_user_rounded, color: AppTheme.emeraldGreen, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    langController.t('walletBenefitsNotice'),
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: AppTheme.textPrimaryDark,
                                      height: 1.35,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── PAW LOADING OVERLAY ──────────────────────────────────────────────
        if (authController.isLoading)
          Positioned.fill(
            child: Container(
              color: AppTheme.pastelVanilla.withValues(alpha: 0.94),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Círculo exterior con glow
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.accentCoral.withValues(alpha: 0.25),
                            AppTheme.accentCoral.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                      child: Center(
                        // Patita pulsante con ScaleTransition
                        child: ScaleTransition(
                          scale: _pawScaleAnim,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.brandCoral.withValues(alpha: 0.25),
                                  blurRadius: 24,
                                  spreadRadius: 6,
                                ),
                              ],
                              border: Border.all(
                                color: AppTheme.pastelPeach,
                                width: 3,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.pets_rounded,
                                size: 46,
                                color: AppTheme.brandCoral,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      langController.t('connectingWalletProgress'),
                      style: GoogleFonts.fredoka(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryTerracotta,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      langController.t('verifyingWalletProgress'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppTheme.textMutedWarm,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Dots de progreso
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) {
                        return AnimatedBuilder(
                          animation: _pawAnimController,
                          builder: (_, __) {
                            final delay = i * 0.33;
                            final val = ((_pawAnimController.value - delay).clamp(0.0, 1.0));
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.brandCoral.withValues(alpha: 0.3 + val * 0.7),
                              ),
                            );
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChip(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: textColor.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.fredoka(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }
}
