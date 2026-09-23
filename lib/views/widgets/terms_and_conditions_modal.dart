import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/language_controller.dart';
import '../../theme/app_theme.dart';
import '../screens/login_screen.dart';
import 'language_selector.dart';

class TermsAndConditionsModal extends StatefulWidget {
  final VoidCallback? onAccepted;
  final bool showAuthButtons;
  final int initialTabIndex;

  const TermsAndConditionsModal({
    super.key,
    this.onAccepted,
    this.showAuthButtons = true,
    this.initialTabIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onAccepted,
    bool showAuthButtons = true,
    int initialTabIndex = 0,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TermsAndConditionsModal(
        onAccepted: onAccepted,
        showAuthButtons: showAuthButtons,
        initialTabIndex: initialTabIndex,
      ),
    );
  }

  @override
  State<TermsAndConditionsModal> createState() => _TermsAndConditionsModalState();
}

class _TermsAndConditionsModalState extends State<TermsAndConditionsModal> {
  bool _isAgreed = false;
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex;
  }

  Future<void> _openWebLegal(String path) async {
    final targetUri = path.startsWith('http')
        ? Uri.parse(path)
        : Uri.parse('${kIsWeb ? '' : 'https://pawbook-358b.onrender.com'}$path');
    try {
      if (await canLaunchUrl(targetUri)) {
        await launchUrl(targetUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching legal web URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 650;
    final lang = Provider.of<LanguageController>(context);

    final contentWidget = Container(
      constraints: BoxConstraints(
        maxHeight: size.height * 0.92,
        maxWidth: isDesktop ? 650 : double.infinity,
      ),
      margin: isDesktop ? EdgeInsets.symmetric(horizontal: (size.width - 650) / 2) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: AppTheme.bgWarmCream,
        borderRadius: isDesktop
            ? const BorderRadius.all(Radius.circular(32))
            : const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 28,
            offset: Offset(0, -4),
          ),
        ],
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

          // Header with Dynamic Icon, Titles, Language Selector & Close Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getHeaderIconColor().withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getHeaderIcon(),
                    color: _getHeaderIconColor(),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getHeaderTitle(lang),
                        style: GoogleFonts.fredoka(
                          fontSize: 17.5,
                          fontWeight: FontWeight.bold,
                          color: _getHeaderIconColor(),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _getHeaderSubtitle(lang),
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

          // Segmented Tabs: [Terms of Use] [Privacy & Security] [Animal Welfare]
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabButton(
                    index: 0,
                    icon: Icons.gavel_rounded,
                    label: lang.t('termsTabTerms').isNotEmpty ? lang.t('termsTabTerms') : 'Términos',
                    activeColor: AppTheme.primaryTerracotta,
                  ),
                  const SizedBox(width: 8),
                  _buildTabButton(
                    index: 1,
                    icon: Icons.security_rounded,
                    label: lang.t('termsTabPrivacy').isNotEmpty ? lang.t('termsTabPrivacy') : 'Seguridad',
                    activeColor: AppTheme.emeraldGreen,
                  ),
                  const SizedBox(width: 8),
                  _buildTabButton(
                    index: 2,
                    icon: Icons.pets_rounded,
                    label: lang.t('termsTabWelfare').isNotEmpty ? lang.t('termsTabWelfare') : 'Bienestar Animal',
                    activeColor: AppTheme.accentOrange,
                  ),
                ],
              ),
            ),
          ),

          const Divider(color: AppTheme.borderWarm, height: 1),

          // Scrollable Legal Content Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tab 0: Terms of Use
                  if (_selectedTab == 0) ..._buildTermsTabContent(lang),

                  // Tab 1: Privacy & Security
                  if (_selectedTab == 1) ..._buildPrivacyTabContent(lang),

                  // Tab 2: Animal Welfare Policy
                  if (_selectedTab == 2) ..._buildWelfareTabContent(lang),

                  // Web version direct access banner
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
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
                            const Icon(Icons.language_rounded, size: 18, color: AppTheme.primaryTerracotta),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lang.t('termsWebNotice').isNotEmpty
                                    ? lang.t('termsWebNotice')
                                    : 'Consulta los documentos oficiales completos en nuestra web.',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppTheme.textPrimaryDark,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryTerracotta,
                                  side: const BorderSide(color: AppTheme.primaryTerracotta, width: 1.2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                icon: const Icon(Icons.article_outlined, size: 15),
                                label: Text(
                                  lang.t('openWebTerms').isNotEmpty ? lang.t('openWebTerms') : 'Términos Web 📄',
                                  style: GoogleFonts.fredoka(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () => _openWebLegal('/terms'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.emeraldGreen,
                                  side: const BorderSide(color: AppTheme.emeraldGreen, width: 1.2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                icon: const Icon(Icons.shield_outlined, size: 15),
                                label: Text(
                                  lang.t('openWebPrivacy').isNotEmpty ? lang.t('openWebPrivacy') : 'Privacidad Web 🛡️',
                                  style: GoogleFonts.fredoka(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () => _openWebLegal('/privacy'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: InkWell(
                            onTap: () => _openWebLegal('https://solchatplus.web.app/join/group/ce0f9388-9520-4d89-b4ae-3301125eeb1c'),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14F195).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF14F195).withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.chat_bubble_rounded, size: 16, color: Color(0xFF0F9D58)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '¡Únete a mi grupo "support pawbooklife" en SolChat Plus! 💬',
                                      style: GoogleFonts.fredoka(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F9D58),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFF0F9D58)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _openWebLegal('mailto:oc4389331@gmail.com'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.email_outlined, size: 14, color: AppTheme.primaryTerracotta),
                                const SizedBox(width: 6),
                                Text(
                                  'Soporte: oc4389331@gmail.com',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryTerracotta,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
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
                              lang.t('termsCheckboxPrompt'),
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

                  // Primary Button: Accept & Create Account
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
                        lang.t('termsAcceptAndSignUp'),
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
                        lang.t('termsAlreadyHaveAccount'),
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
                    lang.t('understood'),
                    style: GoogleFonts.fredoka(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return contentWidget;
  }

  // Segment Tab Button Builder
  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
    required Color activeColor,
  }) {
    final isActive = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor : AppTheme.surfaceWarm,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeColor : AppTheme.borderWarm,
            width: 1.2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : AppTheme.warmBrown,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.fredoka(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : AppTheme.warmBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Header helper methods
  IconData _getHeaderIcon() {
    switch (_selectedTab) {
      case 1:
        return Icons.security_rounded;
      case 2:
        return Icons.pets_rounded;
      default:
        return Icons.gavel_rounded;
    }
  }

  Color _getHeaderIconColor() {
    switch (_selectedTab) {
      case 1:
        return AppTheme.emeraldGreen;
      case 2:
        return AppTheme.accentOrange;
      default:
        return AppTheme.primaryTerracotta;
    }
  }

  String _getHeaderTitle(LanguageController lang) {
    switch (_selectedTab) {
      case 1:
        return lang.t('privacyTitle').isNotEmpty ? lang.t('privacyTitle') : 'Políticas de Seguridad';
      case 2:
        return lang.t('welfareTitle').isNotEmpty ? lang.t('welfareTitle') : 'Bienestar Animal';
      default:
        return lang.t('termsTitle');
    }
  }

  String _getHeaderSubtitle(LanguageController lang) {
    switch (_selectedTab) {
      case 1:
        return lang.t('privacySubtitle').isNotEmpty ? lang.t('privacySubtitle') : 'Protección de datos y Web3';
      case 2:
        return lang.t('welfareSubtitle').isNotEmpty ? lang.t('welfareSubtitle') : 'Cero tolerancia al maltrato';
      default:
        return lang.t('termsSubtitle');
    }
  }

  // Tab 0 Content: Terms of Use
  List<Widget> _buildTermsTabContent(LanguageController lang) {
    return [
      _buildHighlightBanner(
        icon: Icons.verified_user_rounded,
        text: lang.t('termsBannerText'),
        accentColor: AppTheme.primaryTerracotta,
      ),
      const SizedBox(height: 14),
      _buildTermSection(
        icon: Icons.pets_rounded,
        iconColor: AppTheme.primaryTerracotta,
        title: lang.t('termsSection1Title'),
        content: lang.t('termsSection1Content'),
      ),
      _buildTermSection(
        icon: Icons.shield_rounded,
        iconColor: AppTheme.emeraldGreen,
        title: lang.t('termsSection2Title'),
        content: lang.t('termsSection2Content'),
      ),
      _buildTermSection(
        icon: Icons.bolt_rounded,
        iconColor: AppTheme.solanaPurple,
        title: lang.t('termsSection3Title'),
        content: lang.t('termsSection3Content'),
      ),
      _buildTermSection(
        icon: Icons.cloud_done_rounded,
        iconColor: AppTheme.accentOrange,
        title: lang.t('termsSection4Title'),
        content: lang.t('termsSection4Content'),
      ),
      _buildTermSection(
        icon: Icons.handshake_rounded,
        iconColor: AppTheme.warmBrown,
        title: lang.t('termsSection5Title'),
        content: lang.t('termsSection5Content'),
      ),
      if (lang.t('termsSection6Title').isNotEmpty)
        _buildTermSection(
          icon: Icons.copyright_rounded,
          iconColor: Colors.deepPurple,
          title: lang.t('termsSection6Title'),
          content: lang.t('termsSection6Content'),
        ),
      if (lang.t('termsSection7Title').isNotEmpty)
        _buildTermSection(
          icon: Icons.shopping_bag_rounded,
          iconColor: AppTheme.brandCoral,
          title: lang.t('termsSection7Title'),
          content: lang.t('termsSection7Content'),
        ),
      if (lang.t('termsSection8Title').isNotEmpty)
        _buildTermSection(
          icon: Icons.lock_clock_rounded,
          iconColor: Colors.blueGrey,
          title: lang.t('termsSection8Title'),
          content: lang.t('termsSection8Content'),
        ),
    ];
  }

  // Tab 1 Content: Privacy & Security
  List<Widget> _buildPrivacyTabContent(LanguageController lang) {
    return [
      _buildHighlightBanner(
        icon: Icons.lock_outline_rounded,
        text: lang.t('privacyHeroText').isNotEmpty
            ? lang.t('privacyHeroText')
            : 'En Pawbooklife protegemos tus datos y los de tus mascotas. Nunca comercializamos tu información personal con terceros.',
        accentColor: AppTheme.emeraldGreen,
      ),
      const SizedBox(height: 14),
      _buildTermSection(
        icon: Icons.list_alt_rounded,
        iconColor: AppTheme.emeraldGreen,
        title: lang.t('privacySection1Title'),
        content: lang.t('privacySection1Content'),
      ),
      _buildTermSection(
        icon: Icons.cloud_done_rounded,
        iconColor: AppTheme.primaryTerracotta,
        title: lang.t('privacySection2Title'),
        content: lang.t('privacySection2Content'),
      ),
      _buildTermSection(
        icon: Icons.vpn_key_rounded,
        iconColor: AppTheme.solanaPurple,
        title: lang.t('privacySection3Title'),
        content: lang.t('privacySection3Content'),
      ),
      _buildTermSection(
        icon: Icons.auto_awesome_rounded,
        iconColor: AppTheme.brandCoral,
        title: lang.t('privacySection4Title'),
        content: lang.t('privacySection4Content'),
      ),
      _buildTermSection(
        icon: Icons.account_box_rounded,
        iconColor: AppTheme.warmBrown,
        title: lang.t('privacySection5Title'),
        content: lang.t('privacySection5Content'),
      ),
      _buildTermSection(
        icon: Icons.cookie_rounded,
        iconColor: Colors.amber.shade800,
        title: lang.t('privacySection6Title'),
        content: lang.t('privacySection6Content'),
      ),
      _buildTermSection(
        icon: Icons.support_agent_rounded,
        iconColor: const Color(0xFF9945FF),
        title: '7. Canal Oficial de Soporte y SolChat Plus',
        content: 'Para soporte técnico directo, resolución de incidencias o unirte a la comunidad:\n\n• SolChat Plus: ¡Únete a mi grupo "support pawbooklife" en SolChat Plus!\nhttps://solchatplus.web.app/join/group/ce0f9388-9520-4d89-b4ae-3301125eeb1c\n\n• Correo de Soporte: oc4389331@gmail.com\n• Soporte General: support@pawbooklife.com',
      ),
    ];
  }

  // Tab 2 Content: Animal Welfare Policy
  List<Widget> _buildWelfareTabContent(LanguageController lang) {
    return [
      _buildHighlightBanner(
        icon: Icons.favorite_rounded,
        text: lang.t('welfareHeroText').isNotEmpty
            ? lang.t('welfareHeroText')
            : 'La protección y el amor por los animales son el pilar de Pawbooklife. Cero tolerancia al maltrato animal.',
        accentColor: AppTheme.accentOrange,
      ),
      const SizedBox(height: 14),
      _buildTermSection(
        icon: Icons.do_not_disturb_on_rounded,
        iconColor: Colors.redAccent,
        title: lang.t('welfareSection1Title'),
        content: lang.t('welfareSection1Content'),
      ),
      _buildTermSection(
        icon: Icons.warning_amber_rounded,
        iconColor: AppTheme.accentOrange,
        title: lang.t('welfareSection2Title'),
        content: lang.t('welfareSection2Content'),
      ),
      _buildTermSection(
        icon: Icons.nature_people_rounded,
        iconColor: AppTheme.emeraldGreen,
        title: lang.t('welfareSection3Title'),
        content: lang.t('welfareSection3Content'),
      ),
    ];
  }

  Widget _buildHighlightBanner({
    required IconData icon,
    required String text,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.08),
            AppTheme.accentOrange.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
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
