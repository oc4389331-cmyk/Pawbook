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

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onLoginSuccess() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _showGoogleAccountPickerModal(BuildContext context, AuthController authController, LanguageController langController) {
    final googleEmailController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4285F4),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('G', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Elige tu cuenta de Google',
                        style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF202124)),
                      ),
                      Text(
                        'para acceder a Pawtbook',
                        style: GoogleFonts.roboto(fontSize: 13, color: const Color(0xFF5F6368)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),

              // Account Option 1
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF4285F4),
                  child: Icon(Icons.person_rounded, color: Colors.white),
                ),
                title: Text('Oscar Romero', style: GoogleFonts.roboto(fontWeight: FontWeight.w500, color: const Color(0xFF202124))),
                subtitle: Text('oscar.romero@gmail.com', style: GoogleFonts.roboto(color: const Color(0xFF5F6368), fontSize: 13)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF5F6368)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await authController.loginWithGoogle(selectedEmail: 'oscar.romero@gmail.com');
                  if (ok && mounted) _onLoginSuccess();
                },
              ),
              const Divider(),

              // Account Option 2
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF34A853),
                  child: Icon(Icons.pets_rounded, color: Colors.white),
                ),
                title: Text('Creador Pawtbook', style: GoogleFonts.roboto(fontWeight: FontWeight.w500, color: const Color(0xFF202124))),
                subtitle: Text('pawtbook.creator@gmail.com', style: GoogleFonts.roboto(color: const Color(0xFF5F6368), fontSize: 13)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF5F6368)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await authController.loginWithGoogle(selectedEmail: 'pawtbook.creator@gmail.com');
                  if (ok && mounted) _onLoginSuccess();
                },
              ),
              const Divider(),

              // Option 3: Custom Google Email Input
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextField(
                  controller: googleEmailController,
                  decoration: InputDecoration(
                    hintText: 'tu.cuenta@gmail.com',
                    labelText: 'Usar otra cuenta de Google',
                    prefixIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF4285F4)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final email = googleEmailController.text.trim();
                    if (email.isEmpty) return;
                    Navigator.pop(ctx);
                    final ok = await authController.loginWithGoogle(selectedEmail: email);
                    if (ok && mounted) _onLoginSuccess();
                  },
                  child: Text('Confirmar y Validar Datos', style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Al continuar, Google compartirá tu nombre, correo electrónico y foto con Pawtbook para asociar tu Wallet de Solana.',
                style: GoogleFonts.roboto(fontSize: 11, color: const Color(0xFF5F6368)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
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
                      const SizedBox(height: 28),

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
                      const SizedBox(height: 36),

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

                      // Google Sign-In Button (Triggers authentic Google Account Picker Modal)
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
                              : () => _showGoogleAccountPickerModal(context, authController, langController),
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
                      const SizedBox(height: 18),

                      // Email Input (Warm Pawly Soft Container)
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          hintText: langController.t('emailHint'),
                          hintStyle: GoogleFonts.outfit(color: AppTheme.textMutedWarm),
                          prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.primaryTerracotta),
                          filled: true,
                          fillColor: AppTheme.surfaceWarm,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: AppTheme.borderWarm),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: AppTheme.borderWarm),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: AppTheme.primaryTerracotta, width: 2),
                          ),
                        ),
                        style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark),
                      ),
                      const SizedBox(height: 14),

                      // Email Login Outlined Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accentOrange,
                            side: const BorderSide(color: AppTheme.accentOrange, width: 1.8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                          label: Text(
                            langController.t('enterEmail'),
                            style: GoogleFonts.fredoka(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          onPressed: authController.isLoading
                              ? null
                              : () async {
                                  final email = _emailController.text.trim();
                                  if (email.isEmpty) return;
                                  final ok = await authController.loginWithEmail(email);
                                  if (ok && mounted) _onLoginSuccess();
                                },
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
