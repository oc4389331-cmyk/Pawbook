import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);

    return Scaffold(
      backgroundColor: AppTheme.bgWarmCream,
      body: SafeArea(
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
                  'Pawtbook 🐾',
                  style: GoogleFonts.fredoka(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTerracotta,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Care & SocialFi for All Your Pets in One Place',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: AppTheme.textMutedWarm,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

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
                            'Conectar Wallet (Solana)',
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
                const SizedBox(height: 18),

                // Email Input (Warm Pawly Soft Container)
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: 'tu@email.com',
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
                      'Ingresar con Email (Embedded Wallet)',
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
