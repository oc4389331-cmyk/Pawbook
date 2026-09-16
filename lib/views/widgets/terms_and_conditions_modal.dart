import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/language_controller.dart';
import '../../theme/app_theme.dart';
import '../screens/login_screen.dart';
import 'language_selector.dart';

class TermsAndConditionsModal extends StatefulWidget {
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
  State<TermsAndConditionsModal> createState() => _TermsAndConditionsModalState();
}

class _TermsAndConditionsModalState extends State<TermsAndConditionsModal> {
  bool _isAgreed = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final langController = Provider.of<LanguageController>(context);

    return Container(
      constraints: BoxConstraints(maxHeight: size.height * 0.90),
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

          // Header with Title, Language Selector, and Close Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTerracotta.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.gavel_rounded,
                    color: AppTheme.primaryTerracotta,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        langController.t('termsTitle'),
                        style: GoogleFonts.fredoka(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTerracotta,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        langController.t('termsSubtitle'),
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: AppTheme.textMutedWarm,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Dynamic Language Selector inside Terms Modal
                const LanguageSelector(),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.warmBrown, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          const Divider(color: AppTheme.borderWarm, height: 1),

          // Scrollable Terms Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Highlights Banner
                  Container(
                    padding: const EdgeInsets.all(12),
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
                        const Icon(Icons.verified_user_rounded, color: AppTheme.primaryTerracotta, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            langController.t('termsBannerText'),
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
                  const SizedBox(height: 14),

                  _buildTermSection(
                    icon: Icons.pets_rounded,
                    iconColor: AppTheme.primaryTerracotta,
                    title: langController.t('termsSection1Title'),
                    content: langController.t('termsSection1Content'),
                  ),

                  _buildTermSection(
                    icon: Icons.shield_rounded,
                    iconColor: AppTheme.emeraldGreen,
                    title: langController.t('termsSection2Title'),
                    content: langController.t('termsSection2Content'),
                  ),

                  _buildTermSection(
                    icon: Icons.bolt_rounded,
                    iconColor: AppTheme.solanaPurple,
                    title: langController.t('termsSection3Title'),
                    content: langController.t('termsSection3Content'),
                  ),

                  _buildTermSection(
                    icon: Icons.cloud_done_rounded,
                    iconColor: AppTheme.accentOrange,
                    title: langController.t('termsSection4Title'),
                    content: langController.t('termsSection4Content'),
                  ),

                  _buildTermSection(
                    icon: Icons.handshake_rounded,
                    iconColor: AppTheme.warmBrown,
                    title: langController.t('termsSection5Title'),
                    content: langController.t('termsSection5Content'),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // Bottom Action Buttons with Checkbox
          if (widget.showAuthButtons) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceWarm,
                border: Border(top: BorderSide(color: AppTheme.borderWarm, width: 1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mandatory Acceptance Checkbox
                  InkWell(
                    onTap: () => setState(() => _isAgreed = !_isAgreed),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _isAgreed,
                            activeColor: AppTheme.primaryTerracotta,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                            onChanged: (val) => setState(() => _isAgreed = val ?? false),
                          ),
                          Expanded(
                            child: Text(
                              langController.t('termsCheckboxPrompt'),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _isAgreed ? AppTheme.primaryTerracotta : AppTheme.textPrimaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Primary Button: Accept & Create Account (ENABLED ONLY WHEN _isAgreed == true)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isAgreed ? AppTheme.primaryTerracotta : Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        elevation: _isAgreed ? 3 : 0,
                        shadowColor: AppTheme.primaryTerracotta.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                      icon: Icon(
                        _isAgreed ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: Text(
                        langController.t('termsAcceptAndSignUp'),
                        style: GoogleFonts.fredoka(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _isAgreed
                          ? () {
                              Navigator.of(context).pop();
                              if (widget.onAccepted != null) {
                                widget.onAccepted!();
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
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Secondary Button: Already have account / Log in
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.warmBrown,
                        side: const BorderSide(color: AppTheme.borderWarm, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.login_rounded, size: 18, color: AppTheme.primaryTerracotta),
                      label: Text(
                        langController.t('termsAlreadyHaveAccount'),
                        style: GoogleFonts.fredoka(
                          fontSize: 13.5,
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTerracotta,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    langController.t('understood'),
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(13),
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
