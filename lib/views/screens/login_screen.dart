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

  bool _isOtpSent = false;
  String? _sentOtpCode;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _onLoginSuccess() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _showGoogleAuthConsentModal(BuildContext context, AuthController authController) {
    final defaultEmail = _emailController.text.trim().isNotEmpty 
        ? _emailController.text.trim() 
        : 'oc4389331@gmail.com';
    final googleEmailController = TextEditingController(text: defaultEmail);
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    String? validationError;
    bool isChoosingAnother = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final currentText = googleEmailController.text.trim();
            final isValid = currentText.isNotEmpty && emailRegex.hasMatch(currentText);

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Google Branding Header (Authentic Google Sign-In)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4285F4).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w900, fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Acceder con Google',
                            style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF202124)),
                          ),
                          Text(
                            'Ir a Pawtbook',
                            style: GoogleFonts.roboto(fontSize: 13, color: const Color(0xFF5F6368)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),

                  Text(
                    'Elige una cuenta',
                    style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFF202124)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'para continuar en Pawtbook',
                    style: GoogleFonts.roboto(fontSize: 13, color: const Color(0xFF5F6368)),
                  ),
                  const SizedBox(height: 16),

                  // Account Selector Box (Style of Google OAuth Chooser)
                  if (!isChoosingAnother) ...[
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final ok = await authController.loginWithGoogle(googleEmail: currentText);
                        if (ok && mounted) _onLoginSuccess();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDADCE0)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFFAB47BC),
                              child: Text(
                                currentText.isNotEmpty ? currentText[0].toUpperCase() : 'O',
                                style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentText.contains('@') ? currentText.split('@')[0] : 'Oscar Campos',
                                    style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3C4043)),
                                  ),
                                  Text(
                                    currentText,
                                    style: GoogleFonts.roboto(fontSize: 13, color: const Color(0xFF5F6368)),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Color(0xFF5F6368)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // "Usar otra cuenta" Option
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setModalState(() {
                          isChoosingAnother = true;
                          googleEmailController.clear();
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 20,
                              backgroundColor: Color(0xFFE8EAED),
                              child: Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF5F6368), size: 20),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Usar otra cuenta',
                              style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF3C4043)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Custom Google Email Input
                    TextField(
                      controller: googleEmailController,
                      keyboardType: TextInputType.emailAddress,
                      autofocus: true,
                      style: GoogleFonts.roboto(color: const Color(0xFF202124), fontSize: 14, fontWeight: FontWeight.w500),
                      onChanged: (val) {
                        setModalState(() {
                          if (val.trim().isEmpty) {
                            validationError = 'Ingresa tu dirección de correo de Google';
                          } else if (!emailRegex.hasMatch(val.trim())) {
                            validationError = '❌ "${val.trim()}" no es un correo válido (ej. usuario@gmail.com)';
                          } else {
                            validationError = null;
                          }
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Correo electrónico de Google',
                        prefixIcon: const Icon(Icons.email_rounded, color: Color(0xFF1A73E8)),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFDADCE0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFDADCE0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 2)),
                      ),
                    ),
                    if (validationError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        validationError!,
                        style: GoogleFonts.roboto(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],

                  const SizedBox(height: 16),

                  // Permissions Details Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE8EAED)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pawtbook obtendrá los siguientes accesos:',
                          style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF3C4043)),
                        ),
                        const SizedBox(height: 8),
                        _buildPermissionRow(Icons.email_rounded, 'Ver tu dirección de correo electrónico principal'),
                        _buildPermissionRow(Icons.account_circle_rounded, 'Ver tu nombre y foto de perfil personal pública'),
                        _buildPermissionRow(Icons.account_balance_wallet_rounded, 'Generar y vincular tu Wallet de Solana'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancelar', style: GoogleFonts.roboto(color: const Color(0xFF5F6368), fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isValid ? const Color(0xFF1A73E8) : Colors.grey[400],
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          onPressed: !isValid
                              ? null
                              : () async {
                                  final chosenEmail = googleEmailController.text.trim();
                                  Navigator.pop(ctx);
                                  final ok = await authController.loginWithGoogle(googleEmail: chosenEmail);
                                  if (ok && mounted) _onLoginSuccess();
                                },
                          child: Text('Permitir y Acceder', style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Antes de usar Pawtbook, revisa la Política de Privacidad y Condiciones del Servicio.',
                      style: GoogleFonts.roboto(fontSize: 11, color: const Color(0xFF70757A)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPermissionRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1A73E8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: GoogleFonts.roboto(fontSize: 12, color: const Color(0xFF3C4043))),
          ),
        ],
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.redAccent),
                          ),
                          child: Text(
                            authController.errorMessage!,
                            style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Connect Solana Wallet Button (Terracotta Warm Style)
                      SizedBox(
                        width: double.infinity,
                        height: 54,
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
                                  style: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                          onPressed: authController.isLoading
                              ? null
                              : () async {
                                  final ok = await authController.loginWithSolanaWallet(walletType: 'Phantom');
                                  if (ok && mounted) _onLoginSuccess();
                                },
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Google Sign-In Button (Triggers Permission Consent Modal)
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.textPrimaryDark,
                            elevation: 3,
                            shadowColor: Colors.black.withOpacity(0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: const BorderSide(color: AppTheme.borderWarm, width: 1.5),
                            ),
                          ),
                          onPressed: authController.isLoading
                              ? null
                              : () => _showGoogleAuthConsentModal(context, authController),
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      // --- EMAIL AUTHENTICATION MODE SELECTOR (INICIAR SESIÓN vs CREAR CUENTA) ---
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
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    // Mode toggle trigger
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryTerracotta,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '🔑 Iniciar Sesión',
                                      style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    // Mode toggle trigger
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '✨ Crear Cuenta',
                                      style: GoogleFonts.fredoka(color: AppTheme.textMutedWarm, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (!_isOtpSent) ...[
                        Text(
                          '🔐 Acceso Seguro por Correo',
                          style: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ingresa tu correo para recibir un código de verificación único de 6 dígitos.\n(Si eres nuevo, tu Wallet de Solana Dynamic se creará automáticamente).',
                          style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMutedWarm),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Email Input
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: langController.t('emailHint'),
                            hintStyle: GoogleFonts.outfit(color: AppTheme.textMutedWarm),
                            prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.primaryTerracotta),
                            filled: true,
                            fillColor: AppTheme.surfaceWarm,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppTheme.primaryTerracotta, width: 2)),
                          ),
                          style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark),
                        ),
                        const SizedBox(height: 14),

                        // Send Code Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentOrange,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            icon: const Icon(Icons.mark_email_read_rounded, size: 20, color: Colors.white),
                            label: authController.isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    'Enviar Código de Verificación 📩',
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
                                    final code = await authController.sendEmailOtp(email);
                                    if (code != null) {
                                      setState(() {
                                        _isOtpSent = true;
                                        _sentOtpCode = code;
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
                            border: Border.all(color: AppTheme.accentOrange, width: 1.8),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.verified_user_rounded, size: 48, color: AppTheme.accentOrange),
                              const SizedBox(height: 10),
                              Text(
                                'Ingresa el código de 6 dígitos',
                                style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
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
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppTheme.accentOrange, width: 2)),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Verify & Login Button
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryTerracotta,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  icon: const Icon(Icons.lock_open_rounded, color: Colors.white),
                                  label: authController.isLoading
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : Text(
                                          'Verificar e Iniciar Sesión 🔐',
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
                                          final ok = await authController.verifyEmailOtpAndLogin(_emailController.text.trim(), code);
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
