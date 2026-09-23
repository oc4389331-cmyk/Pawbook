import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../controllers/language_controller.dart';
import '../../theme/app_theme.dart';
import 'terms_and_conditions_modal.dart';

class AboutPawbookModal extends StatelessWidget {
  const AboutPawbookModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AboutPawbookModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageController>(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.bgWarmCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Handle drag indicator
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: AppTheme.borderWarm,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryTerracotta, AppTheme.brandCoral],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryTerracotta.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.pets_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pawbooklife',
                        style: GoogleFonts.fredoka(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTerracotta,
                        ),
                      ),
                      Text(
                        lang.t('appTagline'),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppTheme.textMutedWarm,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textMutedWarm),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          const Divider(color: AppTheme.borderWarm, height: 1),

          // Content scrollable
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Version Badge Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1E293B),
                          Color(0xFF0F172A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: Color(0xFF14F195), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              lang.t('appVersionLabel').replaceAll('{version}', AppConfig.appDisplayVersion),
                              style: GoogleFonts.fredoka(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14F195).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF14F195).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            kIsWeb ? 'Web Official 🌐' : 'Production APK 🚀',
                            style: GoogleFonts.fredoka(
                              color: const Color(0xFF14F195),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Section 1: What is Pawbooklife?
                  _buildFeatureCard(
                    icon: Icons.auto_awesome_rounded,
                    iconColor: AppTheme.accentOrange,
                    title: lang.t('aboutWhatIsTitle'),
                    description: lang.t('aboutWhatIsDesc'),
                  ),

                  const SizedBox(height: 12),

                  // Section 2: Solana & Web3 SocialFi
                  _buildFeatureCard(
                    icon: Icons.currency_bitcoin_rounded,
                    iconColor: const Color(0xFF14F195),
                    title: lang.t('aboutWeb3Title'),
                    description: lang.t('aboutWeb3Desc'),
                  ),

                  const SizedBox(height: 12),

                  // Section 3: Safe & Respectful Community
                  _buildFeatureCard(
                    icon: Icons.security_rounded,
                    iconColor: AppTheme.emeraldGreen,
                    title: lang.t('aboutCommunityTitle'),
                    description: lang.t('aboutCommunityDesc'),
                  ),

                  const SizedBox(height: 12),

                  // Section 4: Marketplace & Rewards
                  _buildFeatureCard(
                    icon: Icons.card_giftcard_rounded,
                    iconColor: AppTheme.brandCoral,
                    title: lang.t('aboutMarketplaceTitle'),
                    description: lang.t('aboutMarketplaceDesc'),
                  ),

                  const SizedBox(height: 14),

                  // Section 5: Official Support & Web3 Community (SolChat Plus & Email)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF9945FF).withValues(alpha: 0.08),
                          const Color(0xFF14F195).withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF9945FF).withValues(alpha: 0.3), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9945FF).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.support_agent_rounded, color: Color(0xFF9945FF), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                lang.t('supportTitle'),
                                style: GoogleFonts.fredoka(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.warmBrown,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // SolChat Plus Group Card Action
                        InkWell(
                          onTap: () => _launchExternalUrl('https://solchatplus.web.app/join/group/ce0f9388-9520-4d89-b4ae-3301125eeb1c'),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF14F195).withValues(alpha: 0.5), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF14F195).withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF14F195).withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF0F9D58), size: 17),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lang.t('supportSolChat'),
                                        style: GoogleFonts.fredoka(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimaryDark,
                                        ),
                                      ),
                                      Text(
                                        lang.t('supportSolChatDesc'),
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: AppTheme.textMutedWarm,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.open_in_new_rounded, size: 15, color: Color(0xFF0F9D58)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Direct Email Support
                        InkWell(
                          onTap: () => _launchExternalUrl('mailto:oc4389331@gmail.com'),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.borderWarm),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryTerracotta.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.email_rounded, color: AppTheme.primaryTerracotta, size: 17),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lang.t('supportEmail'),
                                        style: GoogleFonts.fredoka(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimaryDark,
                                        ),
                                      ),
                                      Text(
                                        lang.t('supportEmailDesc'),
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: AppTheme.textMutedWarm,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textMutedWarm),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Legal Hub Buttons (Terms of Use & Privacy/Security Policy)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryTerracotta,
                        ),
                        icon: const Icon(Icons.description_outlined, size: 15),
                        label: Text(
                          lang.t('termsAndConditions'),
                          style: GoogleFonts.fredoka(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          TermsAndConditionsModal.show(context, showAuthButtons: false, initialTabIndex: 0);
                        },
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.emeraldGreen,
                        ),
                        icon: const Icon(Icons.security_outlined, size: 15),
                        label: Text(
                          lang.t('termsTabPrivacy').isNotEmpty ? lang.t('termsTabPrivacy') : 'Seguridad & Privacidad',
                          style: GoogleFonts.fredoka(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          TermsAndConditionsModal.show(context, showAuthButtons: false, initialTabIndex: 1);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Center(
                    child: Text(
                      '© 2026 Pawbooklife. All Rights Reserved. 🐾',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppTheme.textMutedWarm,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWarm,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.fredoka(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTerracotta,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppTheme.textPrimaryDark,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchExternalUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching url $urlString: $e');
    }
  }
}
