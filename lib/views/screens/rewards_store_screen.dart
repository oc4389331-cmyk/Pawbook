import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/language_controller.dart';
import '../../controllers/pet_controller.dart';
import '../../theme/app_theme.dart';

class RewardsStoreScreen extends StatefulWidget {
  const RewardsStoreScreen({super.key});

  @override
  State<RewardsStoreScreen> createState() => _RewardsStoreScreenState();
}

class _RewardsStoreScreenState extends State<RewardsStoreScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthController>(context, listen: false);
      final petController = Provider.of<PetController>(context, listen: false);
      if (auth.currentProfile != null) {
        petController.fetchUserOrders(auth.currentProfile!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final petController = Provider.of<PetController>(context);
    final langController = Provider.of<LanguageController>(context);
    final userScore = authController.currentProfile?.pawtScore ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.bgWarmCream,
      appBar: AppBar(
        backgroundColor: AppTheme.bgWarmCream,
        elevation: 0,
        title: Text(
          langController.t('rewardsStoreTitle'),
          style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta, fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Balance Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.brandCoral, Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brandCoral.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, size: 40, color: Colors.white),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(langController.t('accumulatedScoreLabel'), style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                      Text(
                        '$userScore 🐾 PawtScore',
                        style: GoogleFonts.fredoka(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              langController.t('physicalRewardsAvailable'),
              style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
            ),
            const SizedBox(height: 12),

            // Rewards Items Catalog
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: petController.availableRewards.length,
              itemBuilder: (context, index) {
                final item = petController.availableRewards[index];
                final canAfford = userScore >= item.pointsCost;

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: AppTheme.borderWarm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            item.imageUrl,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 70,
                              height: 70,
                              color: AppTheme.pastelPeach.withValues(alpha: 0.5),
                              child: const Icon(Icons.card_giftcard, color: AppTheme.brandCoral),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title, style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(item.description, style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.pastelMint,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${NumberFormat('#,###').format(item.pointsCost)} PawtScore',
                                  style: GoogleFonts.fredoka(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canAfford ? AppTheme.brandCoral : AppTheme.borderWarm,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: !canAfford
                              ? null
                              : () async {
                                  final ok = await petController.redeemReward(
                                    userId: authController.currentProfile!.id,
                                    reward: item,
                                    currentPawtScore: userScore,
                                  );

                                  if (ok) {
                                    authController.deductPawtScore(item.pointsCost);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${langController.t("redeemSuccessMsg")} (${item.title})'),
                                          backgroundColor: AppTheme.emeraldGreen,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: Text(langController.t('redeem'), style: GoogleFonts.fredoka(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Order History Section
            Text(
              langController.t('claimedRewardsTitle'),
              style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
            ),
            const SizedBox(height: 12),

            if (petController.userOrders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('🐾', style: GoogleFonts.outfit(color: AppTheme.textMutedWarm)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: petController.userOrders.length,
                itemBuilder: (context, index) {
                  final order = petController.userOrders[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWarm,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderWarm),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.rewardName, style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontWeight: FontWeight.bold)),
                            Text('${order.pointsCost} ${langController.t("points")}', style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            order.status.toUpperCase(),
                            style: GoogleFonts.fredoka(color: AppTheme.emeraldGreen, fontSize: 11, fontWeight: FontWeight.bold),
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
