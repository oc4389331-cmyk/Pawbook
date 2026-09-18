import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../theme/app_theme.dart';

class PawbookTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onAvatarPressed;
  final Widget? customTrailing;

  const PawbookTopAppBar({
    super.key,
    this.onNotificationPressed,
    this.onAvatarPressed,
    this.customTrailing,
  });

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final profile = authController.currentProfile;
    final pet = authController.activePet;
    final avatarUrl = (authController.isPetModeActive && pet != null && pet.avatarUrl.isNotEmpty)
        ? pet.avatarUrl
        : (profile?.avatarUrl ?? '');

    return SafeArea(
      bottom: false,
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Logo con Patita Naranja + Texto pawbooklife
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.brandCoral.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pets_rounded,
                    color: AppTheme.brandCoral,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'pawbooklife',
                  style: GoogleFonts.fredoka(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryDark,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),

            // Right: Trailing actions (Notificaciones y Avatar)
            if (customTrailing != null)
              customTrailing!
            else
              Row(
                children: [
                  // Bell Notification Icon with Badge
                  InkWell(
                    onTap: onNotificationPressed,
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: AppTheme.textPrimaryDark,
                            size: 22,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.brandCoral,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Avatar Circle with Online indicator
                  InkWell(
                    onTap: onAvatarPressed,
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.emeraldGreen, width: 1.8),
                          ),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.surfaceWarm,
                            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl.isEmpty
                                ? const Icon(Icons.person_rounded, size: 18, color: AppTheme.primaryTerracotta)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
