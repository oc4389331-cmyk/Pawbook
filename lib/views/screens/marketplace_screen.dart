import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/language_controller.dart';
import '../../theme/app_theme.dart';

class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final langController = Provider.of<LanguageController>(context);
    final userScore = authController.currentProfile?.pawtScore ?? 100;

    final List<Map<String, dynamic>> bandanas = [
      {
        'id': 'bdn_solana',
        'name': 'Solana Cyber Bandana ⚡',
        'pricePoints': 250,
        'priceUsd': 12.99,
        'imageUrl': 'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?w=600',
        'tag': langController.t('solanaExclusive'),
        'color': AppTheme.solanaPurple,
      },
      {
        'id': 'bdn_golden',
        'name': 'Pawtbook Gold Edition 👑',
        'pricePoints': 500,
        'priceUsd': 24.99,
        'imageUrl': 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=600',
        'tag': langController.t('bestSeller'),
        'color': AppTheme.primaryTerracotta,
      },
      {
        'id': 'bdn_neon',
        'name': 'Neon Paw Glow Bandana 🌟',
        'pricePoints': 180,
        'priceUsd': 9.99,
        'imageUrl': 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?w=600',
        'tag': langController.t('limitedEdition'),
        'color': AppTheme.accentOrange,
      },
      {
        'id': 'bdn_ocean',
        'name': 'Ocean Beach Walker 🌊',
        'pricePoints': 200,
        'priceUsd': 10.99,
        'imageUrl': 'https://images.unsplash.com/photo-1537151608828-ea2b11777ee8?w=600',
        'tag': langController.t('summerCollection'),
        'color': AppTheme.emeraldGreen,
      },
    ];

    return Scaffold(
      backgroundColor: AppTheme.bgWarmCream,
      appBar: AppBar(
        backgroundColor: AppTheme.bgWarmCream,
        elevation: 0,
        title: Text(
          '🛍️ ${langController.t('marketplace')}',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta, fontSize: 22),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWarm,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderWarm),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded, color: AppTheme.accentOrange, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$userScore pts',
                  style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner (Pawly Warm Gradient)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryTerracotta, AppTheme.accentOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryTerracotta.withOpacity(0.2),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      langController.t('officialMerch'),
                      style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    langController.t('exclusiveBandanas'),
                    style: GoogleFonts.fredoka(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    langController.t('redeemSubtitle'),
                    style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.9), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              langController.t('featuredCollection'),
              style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.70,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: bandanas.length,
              itemBuilder: (ctx, idx) {
                final item = bandanas[idx];
                final canAfford = userScore >= (item['pricePoints'] as int);

                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWarm,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.borderWarm, width: 1.2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              item['imageUrl'],
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (item['color'] as Color),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  item['tag'],
                                  style: GoogleFonts.fredoka(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.stars_rounded, color: AppTheme.accentOrange, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${item['pricePoints']} pts',
                                  style: GoogleFonts.fredoka(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                const Spacer(),
                                Text(
                                  '\$${item['priceUsd']}',
                                  style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 36,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (canAfford) {
                                    authController.deductPawtScore(item['pricePoints'] as int);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppTheme.emeraldGreen,
                                        content: Text('🎉 Redeemed ${item['name']} successfully!', style: GoogleFonts.fredoka()),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppTheme.primaryTerracotta,
                                        content: Text('Insufficient PawtScore points. Sponsor pets to earn more!', style: GoogleFonts.fredoka()),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canAfford ? AppTheme.primaryTerracotta : AppTheme.cardWarm,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Text(
                                  canAfford ? langController.t('redeemBandana') : langController.t('getPoints'),
                                  style: GoogleFonts.fredoka(
                                    color: canAfford ? Colors.white : AppTheme.textMutedWarm,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
