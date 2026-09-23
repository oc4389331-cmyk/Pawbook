import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/language_controller.dart';
import '../../models/post_model.dart';
import '../../theme/app_theme.dart';
import 'video_thumbnail_widget.dart';

class SharePostModal extends StatelessWidget {
  final PostModel post;

  const SharePostModal({
    super.key,
    required this.post,
  });

  static void show(BuildContext context, {required PostModel post}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SharePostModal(post: post),
    );
  }

  String _buildInviteUrl(String petName) {
    return 'https://pawbooklife.com/invite?pet=${post.petId}&post=${post.id}&name=${Uri.encodeComponent(petName)}';
  }

  String _buildShareMessage(String petName, String inviteUrl) {
    return '🐾 ¡Te invito a unirte a la comunidad de $petName en Pawbooklife! Descubre contenido exclusivo, dale likes y patrocínalo en Solana 🚀: $inviteUrl';
  }

  Future<void> _launchExternalUrl(BuildContext context, String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Error launching url: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final langController = Provider.of<LanguageController>(context, listen: false);
    final petName = post.petName ?? 'Mascota';
    final inviteUrl = _buildInviteUrl(petName);
    final shareMessage = _buildShareMessage(petName, inviteUrl);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgWarmCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle pill
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: AppTheme.borderWarm,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 18),

          // Header Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.share_rounded, color: AppTheme.accentOrange, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      langController.t('sharePost'),
                      style: GoogleFonts.fredoka(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryDark,
                      ),
                    ),
                    Text(
                      langController.t('sharePostSubtitle'),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textMutedWarm,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppTheme.textMutedWarm),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Post / Pet Preview Mini-Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWarm,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderWarm),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: VideoThumbnailWidget(
                      mediaUrl: post.mediaUrl,
                      mediaType: post.mediaType,
                      fallbackImageUrl: post.petAvatarUrl,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              petName,
                              style: GoogleFonts.fredoka(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14F195).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Solana',
                              style: GoogleFonts.fredoka(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0D9488),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        post.caption.isNotEmpty ? post.caption : '🐾 Comunidad oficial en Pawbooklife',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppTheme.textMutedWarm,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Quick Direct Social Buttons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // WhatsApp
              _buildSocialCircle(
                label: langController.t('shareOnWhatsapp'),
                icon: Icons.chat_rounded,
                bgColor: const Color(0xFF25D366),
                onTap: () {
                  Navigator.pop(context);
                  _launchExternalUrl(context, 'https://wa.me/?text=${Uri.encodeComponent(shareMessage)}');
                },
              ),
              // X / Twitter
              _buildSocialCircle(
                label: langController.t('shareOnX'),
                icon: Icons.alternate_email_rounded,
                bgColor: const Color(0xFF111827),
                onTap: () {
                  Navigator.pop(context);
                  _launchExternalUrl(context, 'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(shareMessage)}');
                },
              ),
              // Telegram
              _buildSocialCircle(
                label: langController.t('shareOnTelegram'),
                icon: Icons.send_rounded,
                bgColor: const Color(0xFF229ED9),
                onTap: () {
                  Navigator.pop(context);
                  _launchExternalUrl(context, 'https://t.me/share/url?url=${Uri.encodeComponent(inviteUrl)}&text=${Uri.encodeComponent("🐾 ¡Únete al grupo de $petName en Pawbooklife!")}');
                },
              ),
              // Native System Share Sheet
              _buildSocialCircle(
                label: langController.t('shareToApps'),
                icon: Icons.share_rounded,
                bgColor: AppTheme.primaryTerracotta,
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await Share.share(
                      shareMessage,
                      subject: 'Pawbooklife - $petName',
                    );
                  } catch (e) {
                    debugPrint('Share plus error: $e');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Copy Link Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWarm,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderWarm),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: AppTheme.textMutedWarm, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    inviteUrl,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppTheme.textMutedWarm,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: Text(
                    langController.t('copyInviteLink'),
                    style: GoogleFonts.fredoka(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteUrl));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.emeraldGreen,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                langController.t('inviteLinkCopied'),
                                style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialCircle({
    required String label,
    required IconData icon,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: bgColor.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 70),
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryDark,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
