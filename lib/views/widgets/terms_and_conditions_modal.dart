import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../screens/login_screen.dart';

class TermsAndConditionsModal extends StatelessWidget {
  final VoidCallback? onAccepted;
  final bool showAuthButtons;

  const TermsAndConditionsModal({
    super.key,
    this.onAccepted,
    this.showAuthButtons = true,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onAccepted,
    bool showAuthButtons = true,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TermsAndConditionsModal(
        onAccepted: onAccepted,
        showAuthButtons: showAuthButtons,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      constraints: BoxConstraints(maxHeight: size.height * 0.88),
      decoration: const BoxDecoration(
        color: AppTheme.bgWarmCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle indicator
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.borderWarm,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTerracotta.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.gavel_rounded,
                    color: AppTheme.primaryTerracotta,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Términos y Condiciones',
                        style: GoogleFonts.fredoka(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTerracotta,
                        ),
                      ),
                      Text(
                        'Uso de la Plataforma Pawtbook 🐾',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppTheme.textMutedWarm,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.warmBrown),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(color: AppTheme.borderWarm, height: 1),

          // Scrollable Terms Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Highlights Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryTerracotta.withValues(alpha: 0.08),
                          AppTheme.accentOrange.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryTerracotta.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.verified_user_rounded, color: AppTheme.primaryTerracotta, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Para interactuar, ver videos ilimitados, dar likes, comentar y patrocinar mascotas en Solana, debes aceptar nuestros términos y crear tu cuenta.',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              color: AppTheme.textPrimaryDark,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  _buildTermSection(
                    icon: Icons.pets_rounded,
                    iconColor: AppTheme.primaryTerracotta,
                    title: '1. Ecosistema Pet-Centric & Roles',
                    content:
                        'Pawtbook es la red social y plataforma SocialFi en Solana donde las mascotas son las protagonistas. Solo los perfiles de mascotas registradas por sus tutores pueden publicar videos y fotos. Los usuarios humanos actúan como patrocinadores, seguidores e interactúan con la comunidad.',
                  ),

                  _buildTermSection(
                    icon: Icons.shield_rounded,
                    iconColor: AppTheme.emeraldGreen,
                    title: '2. Bienestar Animal y Cero Tolerancia al Maltrato',
                    content:
                        'Está terminantemente prohibido subir, compartir o promover contenido que involucre maltrato, abuso, negligencia, peleas o explotación animal. Pawtbook cuenta con moderación automatizada y comunitaria. Cualquier infracción resultará en el bloqueo inmediato y permanente de la cuenta.',
                  ),

                  _buildTermSection(
                    icon: Icons.bolt_rounded,
                    iconColor: AppTheme.solanaPurple,
                    title: '3. Solana Web3, PawtScore y Patrocinios',
                    content:
                        'El sistema de recompensas, PawtScore, propinas e insignias NFT utiliza la blockchain de Solana. Los usuarios son responsables de resguardar sus credenciales de acceso y llaves de billetera. Las transacciones en Solana son irreversibles por diseño de la red.',
                  ),

                  _buildTermSection(
                    icon: Icons.cloud_done_rounded,
                    iconColor: AppTheme.accentOrange,
                    title: '4. Almacenamiento Seguro & Privacidad de Datos',
                    content:
                        'Todo el material audiovisual publicado se almacena y optimiza en Cloudflare R2 con CDN de alta velocidad. Tu información personal está protegida y nunca es comercializada a terceros. Al subir contenido, otorgas a Pawtbook la licencia para mostrarlo en el feed global y perfiles asociados.',
                  ),

                  _buildTermSection(
                    icon: Icons.handshake_rounded,
                    iconColor: AppTheme.warmBrown,
                    title: '5. Aceptación y Actualizaciones',
                    content:
                        'Al registrarte y hacer clic en "Aceptar Términos", declaras haber leído y consentido estos términos y condiciones de uso y la política de privacidad de Pawtbook en su totalidad.',
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          if (showAuthButtons) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceWarm,
                border: Border(top: BorderSide(color: AppTheme.borderWarm, width: 1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Primary Button: Accept & Create Account
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTerracotta,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: AppTheme.primaryTerracotta.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      label: Text(
                        '🐾 Aceptar Términos y Crear Cuenta',
                        style: GoogleFonts.fredoka(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (onAccepted != null) {
                          onAccepted!();
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(
                                initialIsSignUp: true,
                                termsAcceptedInitially: true,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Secondary Button: Already have account / Log in
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.warmBrown,
                        side: const BorderSide(color: AppTheme.borderWarm, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.login_rounded, size: 18, color: AppTheme.primaryTerracotta),
                      label: Text(
                        '🔑 Ya tengo cuenta (Iniciar Sesión)',
                        style: GoogleFonts.fredoka(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warmBrown,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(
                              initialIsSignUp: false,
                              termsAcceptedInitially: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTerracotta,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Entendido',
                    style: GoogleFonts.fredoka(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTermSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWarm,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderWarm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.fredoka(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.warmBrown,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textPrimaryDark,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
