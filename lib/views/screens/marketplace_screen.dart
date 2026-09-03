import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/language_controller.dart';
import '../../services/render_backend_service.dart';
import '../../theme/app_theme.dart';

class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  void _showCheckoutModal(BuildContext context, Map<String, dynamic> item, LanguageController langController, AuthController authController) {
    String paymentMethod = 'stripe';
    bool isProcessing = false;
    final renderService = RenderBackendService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.bgWarmCream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.borderWarm,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Item Summary Row
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          item['imageUrl'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${item['priceUsd']} USD  •  ${item['pricePoints']} pts',
                              style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    langController.t('selectMarketplacePayment'),
                    style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),

                  // Payment Choice 1: Stripe Card / Google Pay / PayPal
                  GestureDetector(
                    onTap: () => setModalState(() => paymentMethod = 'stripe'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: paymentMethod == 'stripe' ? AppTheme.primaryTerracotta.withOpacity(0.12) : AppTheme.surfaceWarm,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: paymentMethod == 'stripe' ? AppTheme.primaryTerracotta : AppTheme.borderWarm,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.credit_card_rounded, color: AppTheme.primaryTerracotta, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tarjeta, Google Pay, PayPal',
                                  style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Pago seguro en USD vía Stripe Checkout',
                                  style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (paymentMethod == 'stripe')
                            const Icon(Icons.check_circle_rounded, color: AppTheme.primaryTerracotta, size: 24),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment Choice 2: Crypto (Solana Pay)
                  GestureDetector(
                    onTap: () => setModalState(() => paymentMethod = 'solana_pay'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: paymentMethod == 'solana_pay' ? AppTheme.emeraldGreen.withOpacity(0.12) : AppTheme.surfaceWarm,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: paymentMethod == 'solana_pay' ? AppTheme.emeraldGreen : AppTheme.borderWarm,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.emeraldGreen, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Crypto (Solana Pay ⚡)',
                                  style: GoogleFonts.fredoka(color: AppTheme.emeraldGreen, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Paga al instante con SOL o USDC en Solana',
                                  style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (paymentMethod == 'solana_pay')
                            const Icon(Icons.check_circle_rounded, color: AppTheme.emeraldGreen, size: 24),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Submit Payment Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              setModalState(() => isProcessing = true);

                              if (paymentMethod == 'stripe') {
                                final res = await renderService.createStripeCheckoutSession(
                                  userId: authController.currentProfile?.id ?? 'usr_buyer',
                                  petId: 'item_${item['id']}',
                                  pointsAmount: item['pricePoints'] as int,
                                  priceUsd: (item['priceUsd'] as double),
                                );
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppTheme.primaryTerracotta,
                                    content: Text('🎉 Pago iniciado con Tarjeta / Google Pay / PayPal! (${res['sessionId'] ?? 'OK'})', style: GoogleFonts.fredoka()),
                                  ),
                                );
                              } else {
                                await Future.delayed(const Duration(milliseconds: 600));
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppTheme.emeraldGreen,
                                    content: Text('⚡ Pago exitoso con Solana Pay! Tu ${item['name']} está en camino.', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: paymentMethod == 'solana_pay' ? AppTheme.emeraldGreen : AppTheme.primaryTerracotta,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: isProcessing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              paymentMethod == 'solana_pay'
                                  ? 'Pagar \$${item['priceUsd']} en Solana SOL'
                                  : 'Pagar \$${item['priceUsd']} con Tarjeta / PayPal',
                              style: GoogleFonts.fredoka(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

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
                    'Compra con Puntos PawtScore o paga con Tarjeta, Google Pay, PayPal o Solana Pay',
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
                childAspectRatio: 0.64,
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
                        padding: const EdgeInsets.all(10),
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

                            // DUAL PAYMENT OPTION BUTTONS
                            Row(
                              children: [
                                // Option 1: Redeem with Points
                                Expanded(
                                  child: SizedBox(
                                    height: 34,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        if (canAfford) {
                                          authController.deductPawtScore(item['pricePoints'] as int);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: AppTheme.emeraldGreen,
                                              content: Text('🎉 ¡Canjeado ${item['name']} con ${item['pricePoints']} pts!', style: GoogleFonts.fredoka()),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: AppTheme.primaryTerracotta,
                                              content: Text('Necesitas ${item['pricePoints']} pts. ¡Patrocina mascotas para ganar más!', style: GoogleFonts.fredoka()),
                                            ),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: canAfford ? AppTheme.accentOrange : AppTheme.cardWarm,
                                        padding: EdgeInsets.zero,
                                        elevation: 1,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Text(
                                        '${item['pricePoints']}pt',
                                        style: GoogleFonts.fredoka(
                                          color: canAfford ? Colors.white : AppTheme.textMutedWarm,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // Option 2: Buy with Cash / Card / Crypto Modal
                                Expanded(
                                  child: SizedBox(
                                    height: 34,
                                    child: ElevatedButton(
                                      onPressed: () => _showCheckoutModal(context, item, langController, authController),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryTerracotta,
                                        padding: EdgeInsets.zero,
                                        elevation: 1,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Text(
                                        '\$${item['priceUsd']}',
                                        style: GoogleFonts.fredoka(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
