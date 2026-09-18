import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class FloatingBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onPawPressed;
  final int notificationCount;

  const FloatingBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onPawPressed,
    this.notificationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // White floating bar container
          Container(
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
              boxShadow: AppTheme.softCardShadow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Item 0: Feed / Inicio
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_rounded,
                  label: 'Inicio',
                  isSelected: currentIndex == 0,
                ),

                // Item 1: Marketplace / Explorar
                _buildNavItem(
                  index: 1,
                  icon: Icons.search_rounded,
                  label: 'Explorar',
                  isSelected: currentIndex == 1,
                ),

                // Gap for the center elevated paw button
                const SizedBox(width: 56),

                // Item 2: Rewards / Recompensas
                _buildNavItem(
                  index: 3,
                  icon: Icons.card_giftcard_rounded,
                  label: 'Premios',
                  isSelected: currentIndex == 3,
                  badgeCount: notificationCount,
                ),

                // Item 3: Perfil
                _buildNavItem(
                  index: 2,
                  icon: Icons.person_rounded,
                  label: 'Perfil',
                  isSelected: currentIndex == 2,
                ),
              ],
            ),
          ),

          // Elevated Center Paw Action Button
          Positioned(
            top: -18,
            child: GestureDetector(
              onTap: onPawPressed,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.pawButtonGradient,
                  boxShadow: AppTheme.elevatedPawShadow,
                  border: Border.all(color: Colors.white, width: 3.5),
                ),
                child: const Center(
                  child: Icon(
                    Icons.pets_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    int badgeCount = 0,
  }) {
    final color = isSelected ? AppTheme.brandCoral : AppTheme.textMutedWarm;

    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 24),
                if (badgeCount > 0)
                  Positioned(
                    top: -3,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.fredoka(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
