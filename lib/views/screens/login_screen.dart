import 'package:flutter/material.dart';
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.bgDark,
              AppTheme.solanaPurple.withValues(alpha: 0.15),
              AppTheme.bgDark,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Hero Icon & Title
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.solanaPurple, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.solanaPurple.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.pets, size: 64, color: AppTheme.solanaGreen),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Pawtbook',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'SocialFi para Mascotas en Solana 🐾',
                    style: TextStyle(fontSize: 16, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 40),

                  // Architecture Badges Pill
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip('Solana SIWS', AppTheme.solanaPurple),
                      _buildChip('Dynamic.xyz Auth', Colors.deepPurpleAccent),
                      _buildChip('Cloudflare R2', Colors.orange),
                      _buildChip('Supabase RLS', AppTheme.solanaGreen),
                    ],
                  ),
                  const SizedBox(height: 40),

                  if (authController.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: Text(
                        authController.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Solana Wallet Button (Phantom / Solflare via Mobile Wallet Adapter / Dynamic.xyz)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.solanaPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
                      label: authController.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Conectar Wallet (Solana)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: authController.isLoading
                          ? null
                          : () async {
                              final ok = await authController.loginWithSolanaWallet(walletType: 'Phantom');
                              if (ok && mounted) _onLoginSuccess();
                            },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email Login with Embedded Solana Wallet
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: 'tu@email.com',
                      hintStyle: const TextStyle(color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.borderDark),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.borderDark),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.solanaGreen,
                        side: const BorderSide(color: AppTheme.solanaGreen, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.login, size: 18),
                      label: const Text('Ingresar con Email (Embedded Wallet)'),
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
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
