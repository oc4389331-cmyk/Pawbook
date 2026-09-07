import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/language_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/language_selector.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _isOtpSent = false;
  bool _isSignUp = false; // false = Iniciar Sesión, true = Crear Cuenta

  @override
  void initState() {
    super.initState();
    // Restablecer estado de logout para permitir nuevo inicio de sesión
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<AuthController>(context, listen: false).resetLogoutState();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onLoginSuccess() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _handleGoogleSignIn(AuthController authController, LanguageController langController) async {
    final emailText = _emailController.text.trim();
    String? googleEmail = emailText.isNotEmpty && emailText.contains('@') ? emailText : null;

    if (googleEmail == null) {
      googleEmail = await _showGoogleEmailDialog();
      if (googleEmail == null || googleEmail.isEmpty) return;
    }

    final ok = await authController.loginWithGoogle(
      googleEmail: googleEmail,
      isSignUp: _isSignUp,
      fullName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
    );
    if (ok && mounted) {
      _onLoginSuccess();
    }
  }

  Future<String?> _showGoogleEmailDialog() async {
    final dialogController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceWarm,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Color(0xFF4285F4), shape: BoxShape.circle),
                child: const Text('G', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Continuar con Google',
                  style: GoogleFonts.fredoka(fontSize: 18, color: AppTheme.textPrimaryDark, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSignUp
                    ? 'Ingresa tu correo electrónico de Google para crear tu cuenta:'
                    : 'Ingresa tu correo electrónico de Google para iniciar sesión:',
                style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMutedWarm),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dialogController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'usuario@gmail.com',
                  hintStyle: GoogleFonts.outfit(color: AppTheme.textMutedWarm),
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF4285F4)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4285F4), width: 2)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text('Cancelar', style: GoogleFonts.outfit(color: AppTheme.textMutedWarm)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                final text = dialogController.text.trim();
                if (text.isNotEmpty && text.contains('@')) {
                  Navigator.of(ctx).pop(text);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Por favor ingresa un correo válido')),
                  );
                }
              },
              child: Text('Continuar', style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGoogleButton(AuthController authController, LanguageController langController) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimaryDark,
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
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
              langController.t('continueWithGoogle'),
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

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final langController = Provider.of<LanguageController>(context);

    return Scaffold(
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Hero Logo Card (Pawly Warm Style)
                      Container(
                        padding: const EdgeInsets.all(24),
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
                          size: 64,
                          color: AppTheme.primaryTerracotta,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        langController.t('appName'),
                        style: GoogleFonts.fredoka(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTerracotta,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        langController.t('appTagline'),
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          color: AppTheme.textMutedWarm,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Architecture Badges Pill
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChip('Solana SIWS', AppTheme.primaryTerracotta),
                          _buildChip('Dynamic.xyz Auth', AppTheme.accentOrange),
                          _buildChip('Cloudflare R2', AppTheme.emeraldGreen),
                          _buildChip('Stripe & Solana Pay', AppTheme.solanaPurple),
                        ],
                      ),
                      const SizedBox(height: 28),

                      if (authController.errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.12),
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
                                  style: GoogleFonts.outfit(color: Colors.red.shade900, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Connect Solana Wallet Button (Terracotta Warm Style)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTerracotta,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          icon: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
                          label: authController.isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  langController.t('connectWallet'),
                                  style: GoogleFonts.fredoka(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                          onPressed: authController.isLoading
                              ? null
                              : () async {
                                  final ok = await authController.loginWithSolanaWallet(walletType: 'Phantom');
                                  if (ok && mounted) _onLoginSuccess();
                                },
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      // --- EMAIL & GOOGLE AUTHENTICATION MODE SELECTOR (INICIAR SESIÓN vs CREAR CUENTA) ---
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                                  setState(() {
                                    _isSignUp = false;
                                    _isOtpSent = false;
                                    _emailController.clear();
                                    _otpController.clear();
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
                                      '🔑 Iniciar Sesión',
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
                                  setState(() {
                                    _isSignUp = true;
                                    _isOtpSent = false;
                                    _emailController.clear();
                                    _otpController.clear();
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
                                      '✨ Crear Cuenta',
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

                      if (!_isOtpSent) ...[
                        // Título según el modo
                        Text(
                          _isSignUp ? '✨ Crea tu cuenta en Pawbook' : '🔐 Inicia Sesión en Pawbook',
                          style: GoogleFonts.fredoka(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _isSignUp ? AppTheme.accentOrange : AppTheme.primaryTerracotta,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isSignUp
                              ? 'Ingresa tus datos o usa Google para registrarte en la plataforma.'
                              : 'Ingresa tu correo o usa Google para acceder a tu cuenta existente.',
                          style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMutedWarm),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),

                        // --- BOTÓN GOOGLE DENTRO DE AMBAS PESTAÑAS (INICIAR SESIÓN Y CREAR CUENTA) ---
                        _buildGoogleButton(authController, langController),
                        const SizedBox(height: 18),

                        // Divisor entre Google y Correo
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                _isSignUp ? 'o regístrate con correo' : 'o ingresa con tu correo',
                                style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMutedWarm, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Campo de nombre (solo en Crear Cuenta)
                        if (_isSignUp) ...[
                          TextField(
                            controller: _nameController,
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: 'Tu nombre completo',
                              hintStyle: GoogleFonts.outfit(color: AppTheme.textMutedWarm),
                              prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.accentOrange),
                              filled: true,
                              fillColor: AppTheme.surfaceWarm,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppTheme.accentOrange, width: 2)),
                            ),
                            style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Campo Email
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: langController.t('emailHint'),
                            hintStyle: GoogleFonts.outfit(color: AppTheme.textMutedWarm),
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: _isSignUp ? AppTheme.accentOrange : AppTheme.primaryTerracotta,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceWarm,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: _isSignUp ? AppTheme.accentOrange : AppTheme.primaryTerracotta,
                                width: 2,
                              ),
                            ),
                          ),
                          style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark),
                        ),
                        const SizedBox(height: 14),

                        // Botón: Enviar código (distinto color y texto según modo)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isSignUp ? AppTheme.accentOrange : AppTheme.primaryTerracotta,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            icon: Icon(
                              _isSignUp ? Icons.person_add_rounded : Icons.mark_email_read_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                            label: authController.isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    _isSignUp ? 'Crear Cuenta y Enviar Código 🚀' : 'Enviar Código de Verificación 📩',
                                    style: GoogleFonts.fredoka(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                            onPressed: authController.isLoading
                                ? null
                                : () async {
                                    final email = _emailController.text.trim();
                                    if (email.isEmpty || !email.contains('@')) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Por favor ingresa un correo válido (ej. usuario@gmail.com)')),
                                      );
                                      return;
                                    }
                                    if (_isSignUp && _nameController.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Por favor ingresa tu nombre completo')),
                                      );
                                      return;
                                    }

                                    final code = await authController.sendEmailOtp(
                                      email,
                                      isSignUp: _isSignUp,
                                      fullName: _nameController.text.trim(),
                                    );
                                    if (code != null) {
                                      setState(() {
                                        _isOtpSent = true;
                                      });
                                    }
                                  },
                          ),
                        ),
                      ] else ...[
                        // --- STEP 2: ENTER 6-DIGIT OTP VERIFICATION CODE ---
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceWarm,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _isSignUp ? AppTheme.accentOrange : AppTheme.primaryTerracotta,
                              width: 1.8,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _isSignUp ? Icons.how_to_reg_rounded : Icons.verified_user_rounded,
                                size: 48,
                                color: _isSignUp ? AppTheme.accentOrange : AppTheme.primaryTerracotta,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _isSignUp ? '¡Ya casi! Verifica tu correo' : 'Ingresa el código de 6 dígitos',
                                style: GoogleFonts.fredoka(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _isSignUp ? AppTheme.accentOrange : AppTheme.primaryTerracotta,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Enviamos un código de seguridad a:\n${_emailController.text.trim()}',
                                style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMutedWarm),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),

                              // Real Email Inbox Notice Banner
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.emeraldGreen.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.emeraldGreen.withOpacity(0.4)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.mark_email_read_rounded, color: AppTheme.emeraldGreen, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Te enviamos un código de 6 dígitos. Revisa tu bandeja de entrada y la carpeta SPAM.',
                                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emeraldGreen),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 6-digit OTP Code Input Field
                              TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.fredoka(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 8, color: AppTheme.primaryTerracotta),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: '------',
                                  hintStyle: GoogleFonts.fredoka(fontSize: 26, color: AppTheme.textMutedWarm, letterSpacing: 8),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide(
                                      color: _isSignUp ? AppTheme.accentOrange : AppTheme.primaryTerracotta,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Verify & Login / Register Button
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isSignUp ? AppTheme.accentOrange : AppTheme.primaryTerracotta,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  icon: Icon(
                                    _isSignUp ? Icons.how_to_reg_rounded : Icons.lock_open_rounded,
                                    color: Colors.white,
                                  ),
                                  label: authController.isLoading
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : Text(
                                          _isSignUp ? 'Verificar y Crear Cuenta 🎉' : 'Verificar e Iniciar Sesión 🔐',
                                          style: GoogleFonts.fredoka(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                  onPressed: authController.isLoading
                                      ? null
                                      : () async {
                                          final code = _otpController.text.trim();
                                          if (code.length < 6) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Ingresa el código completo de 6 dígitos')),
                                            );
                                            return;
                                          }
                                          final ok = await authController.verifyEmailOtpAndLogin(
                                            _emailController.text.trim(),
                                            code,
                                            fullName: _nameController.text.trim(),
                                          );
                                          if (ok && mounted) _onLoginSuccess();
                                        },
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Change Email / Resend Option
                              TextButton.icon(
                                icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppTheme.textMutedWarm),
                                label: Text(
                                  'Cambiar correo o reenviar código',
                                  style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isOtpSent = false;
                                    _otpController.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.fredoka(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
