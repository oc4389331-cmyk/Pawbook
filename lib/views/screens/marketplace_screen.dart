import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/language_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../controllers/marketplace_controller.dart';
import '../../controllers/oracle_controller.dart';
import '../../models/bandana_product_model.dart';
import '../../services/dynamic_auth_service.dart';
import '../../services/r2_storage_service.dart';
import '../../services/render_backend_service.dart';
import '../../theme/app_theme.dart';

class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  void _showCheckoutModal(
    BuildContext context,
    BandanaProductModel item,
    LanguageController langController,
    AuthController authController,
    MarketplaceController marketplaceController,
    OracleController oracleController,
  ) {
    if (item.isSoldOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryTerracotta,
          content: Text('⚠️ Esta bandana está agotada.', style: GoogleFonts.fredoka(color: Colors.white)),
        ),
      );
      return;
    }

    bool isProcessing = false;
    String selectedToken = 'SOL'; // 'SOL' or 'SKR'
    String selectedWallet = 'Phantom';
    int selectedQuantity = 1;
    final dynamicAuthService = DynamicAuthService();
    final recipientWallet = AppConfig.marketplaceTreasuryWallet;
    final double solRate = 150.0; // Approx SOL rate in USD

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double totalUsd = item.priceUsd * selectedQuantity;
            final double totalSol = totalUsd / solRate;
            final double totalSkr = oracleController.convertUsdToSkr(totalUsd);

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
              child: SingleChildScrollView(
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            item.imageUrl,
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 68,
                              height: 68,
                              color: AppTheme.surfaceWarm,
                              child: const Icon(Icons.pets, color: AppTheme.primaryTerracotta),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontSize: 17, fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${item.priceUsd.toStringAsFixed(2)} USD c/u',
                                style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.emeraldGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '📦 Stock disponible: ${item.stock}',
                                  style: GoogleFonts.fredoka(color: AppTheme.emeraldGreen, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // QUANTITY SELECTOR (Restricted by available stock)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.borderWarm),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cantidad a comprar:',
                                style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Máximo: ${item.stock} ${item.stock == 1 ? "unidad" : "unidades"}',
                                style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 11),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: selectedQuantity > 1
                                    ? () => setModalState(() => selectedQuantity--)
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline_rounded),
                                color: AppTheme.primaryTerracotta,
                                iconSize: 26,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgWarmCream,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.primaryTerracotta, width: 1.5),
                                ),
                                child: Text(
                                  '$selectedQuantity',
                                  style: GoogleFonts.fredoka(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryTerracotta,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: selectedQuantity < item.stock
                                    ? () => setModalState(() => selectedQuantity++)
                                    : null,
                                icon: const Icon(Icons.add_circle_outline_rounded),
                                color: AppTheme.emeraldGreen,
                                iconSize: 26,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // TOKEN / CRYPTO SELECTION (SOL vs $SKR)
                    Text(
                      'Selecciona Token de Pago (Solana):',
                      style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // SOL Option
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => selectedToken = 'SOL'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              decoration: BoxDecoration(
                                color: selectedToken == 'SOL' ? AppTheme.solanaPurple.withOpacity(0.15) : AppTheme.surfaceWarm,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selectedToken == 'SOL' ? AppTheme.solanaPurple : AppTheme.borderWarm,
                                  width: selectedToken == 'SOL' ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('🟣 ', style: TextStyle(fontSize: 15)),
                                      Text(
                                        'SOL (Solana)',
                                        style: GoogleFonts.fredoka(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: selectedToken == 'SOL' ? AppTheme.solanaPurple : AppTheme.textPrimaryDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${totalSol.toStringAsFixed(3)} SOL',
                                    style: GoogleFonts.fredoka(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: selectedToken == 'SOL' ? AppTheme.solanaPurple : AppTheme.textMutedWarm,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // SKR Option
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => selectedToken = 'SKR'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              decoration: BoxDecoration(
                                color: selectedToken == 'SKR' ? AppTheme.emeraldGreen.withOpacity(0.15) : AppTheme.surfaceWarm,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selectedToken == 'SKR' ? AppTheme.emeraldGreen : AppTheme.borderWarm,
                                  width: selectedToken == 'SKR' ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('⚡ ', style: TextStyle(fontSize: 15)),
                                      Text(
                                        '\$SKR (Seeker)',
                                        style: GoogleFonts.fredoka(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: selectedToken == 'SKR' ? AppTheme.emeraldGreen : AppTheme.textPrimaryDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${totalSkr.toStringAsFixed(0)} \$SKR',
                                    style: GoogleFonts.fredoka(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: selectedToken == 'SKR' ? AppTheme.emeraldGreen : AppTheme.textMutedWarm,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Wallet Selection
                    Text(
                      'Selecciona tu Billetera de Solana:',
                      style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => selectedWallet = 'Phantom'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: selectedWallet == 'Phantom' ? AppTheme.emeraldGreen.withOpacity(0.15) : AppTheme.surfaceWarm,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selectedWallet == 'Phantom' ? AppTheme.emeraldGreen : AppTheme.borderWarm,
                                  width: selectedWallet == 'Phantom' ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('👻 ', style: TextStyle(fontSize: 16)),
                                  Text(
                                    'Phantom',
                                    style: GoogleFonts.fredoka(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: selectedWallet == 'Phantom' ? AppTheme.emeraldGreen : AppTheme.textPrimaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => selectedWallet = 'Solflare'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: selectedWallet == 'Solflare' ? AppTheme.accentOrange.withOpacity(0.15) : AppTheme.surfaceWarm,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selectedWallet == 'Solflare' ? AppTheme.accentOrange : AppTheme.borderWarm,
                                  width: selectedWallet == 'Solflare' ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🔥 ', style: TextStyle(fontSize: 16)),
                                  Text(
                                    'Solflare',
                                    style: GoogleFonts.fredoka(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: selectedWallet == 'Solflare' ? AppTheme.accentOrange : AppTheme.textPrimaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Order Summary Pill
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWarm,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderWarm),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total ($selectedQuantity ${selectedQuantity == 1 ? "unidad" : "unidades"}):',
                            style: GoogleFonts.fredoka(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark),
                          ),
                          Text(
                            selectedToken == 'SKR'
                                ? '\$${totalUsd.toStringAsFixed(2)} USD (${totalSkr.toStringAsFixed(0)} \$SKR)'
                                : '\$${totalUsd.toStringAsFixed(2)} USD (${totalSol.toStringAsFixed(3)} SOL)',
                            style: GoogleFonts.fredoka(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: selectedToken == 'SKR' ? AppTheme.emeraldGreen : AppTheme.primaryTerracotta,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Submit Payment Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: isProcessing
                            ? null
                            : () async {
                                setModalState(() => isProcessing = true);

                                final effectiveSol = selectedToken == 'SKR'
                                    ? (totalSkr * oracleController.priceSol > 0
                                        ? totalSkr * oracleController.priceSol
                                        : totalSol)
                                    : totalSol;

                                final res = await dynamicAuthService.sendWalletTransfer(
                                  walletType: selectedWallet,
                                  recipientAddress: recipientWallet,
                                  solAmount: effectiveSol,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                }

                                if (res.isSuccess) {
                                  // Deduct stock in real-time
                                  marketplaceController.purchaseProduct(item.id, selectedQuantity);

                                  if (context.mounted) {
                                    final tokenPaidStr = selectedToken == 'SKR'
                                        ? '${totalSkr.toStringAsFixed(0)} \$SKR'
                                        : '${totalSol.toStringAsFixed(3)} SOL';

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppTheme.emeraldGreen,
                                        duration: const Duration(seconds: 5),
                                        content: Row(
                                          children: [
                                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '⚡ ¡Pago exitoso de $tokenPaidStr ($selectedQuantity ${selectedQuantity == 1 ? "unidad" : "unidades"})! Tu ${item.name} está en camino.',
                                                style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                } else if (res.userCancelled) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppTheme.primaryTerracotta,
                                        duration: const Duration(seconds: 4),
                                        content: Text('ℹ️ Pago cancelado en tu wallet. No se realizó ningún cobro.', style: GoogleFonts.fredoka(color: Colors.white)),
                                      ),
                                    );
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppTheme.primaryTerracotta,
                                        duration: const Duration(seconds: 5),
                                        content: Text(
                                          '⚠️ Error al procesar el pago: ${res.errorMessage ?? "No se pudo conectar con la wallet."}',
                                          style: GoogleFonts.fredoka(color: Colors.white),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedToken == 'SKR' ? AppTheme.emeraldGreen : AppTheme.primaryTerracotta,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        icon: isProcessing
                            ? const SizedBox.shrink()
                            : Icon(selectedToken == 'SKR' ? Icons.bolt_rounded : Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
                        label: isProcessing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                selectedToken == 'SKR'
                                    ? 'Pagar \$${totalUsd.toStringAsFixed(2)} con \$SKR (${totalSkr.toStringAsFixed(0)} \$SKR)'
                                    : 'Pagar \$${totalUsd.toStringAsFixed(2)} con SOL (${totalSol.toStringAsFixed(3)} SOL)',
                                style: GoogleFonts.fredoka(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRedeemModal(
    BuildContext context,
    BandanaProductModel item,
    AuthController authController,
    MarketplaceController marketplaceController,
  ) {
    if (item.isSoldOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryTerracotta,
          content: Text('⚠️ Esta bandana está agotada.', style: GoogleFonts.fredoka(color: Colors.white)),
        ),
      );
      return;
    }

    int selectedQuantity = 1;
    final userScore = authController.currentProfile?.pawtScore ?? 100;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final int totalPoints = item.pricePoints * selectedQuantity;
            final bool canAfford = userScore >= totalPoints;

            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.bgWarmCream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.all(24),
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
                  const SizedBox(height: 16),
                  Text(
                    'Canjear con Puntos PawtScore 🐾',
                    style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(item.imageUrl, width: 56, height: 56, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('${item.pricePoints} pts c/u • Stock disp: ${item.stock}', style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Quantity picker
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Cantidad:', style: GoogleFonts.fredoka(fontSize: 14, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(
                            onPressed: selectedQuantity > 1 ? () => setModalState(() => selectedQuantity--) : null,
                            icon: const Icon(Icons.remove_circle_outline),
                            color: AppTheme.primaryTerracotta,
                          ),
                          Text('$selectedQuantity', style: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(
                            onPressed: selectedQuantity < item.stock ? () => setModalState(() => selectedQuantity++) : null,
                            icon: const Icon(Icons.add_circle_outline),
                            color: AppTheme.emeraldGreen,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: AppTheme.borderWarm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Costo Total:', style: GoogleFonts.fredoka(fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('$totalPoints pts (Tienes $userScore pts)', style: GoogleFonts.fredoka(fontSize: 14, color: canAfford ? AppTheme.emeraldGreen : AppTheme.primaryTerracotta, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: canAfford
                          ? () {
                              authController.deductPawtScore(totalPoints);
                              marketplaceController.purchaseProduct(item.id, selectedQuantity);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppTheme.emeraldGreen,
                                  content: Text('🎉 ¡Canjeaste $selectedQuantity de ${item.name} por $totalPoints pts!', style: GoogleFonts.fredoka()),
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        canAfford ? 'Confirmar Canje ($totalPoints pts)' : 'Puntos insuficientes',
                        style: GoogleFonts.fredoka(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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

  void _promptAdminPasswordDialog(
    BuildContext context,
    MarketplaceController marketplaceController,
    AuthController authController,
  ) {
    final currentUserEmail = authController.currentProfile?.email?.toLowerCase().trim() ?? '';
    if (currentUserEmail != AppConfig.adminEmail.toLowerCase().trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryTerracotta,
          content: Text('⚠️ Acceso restringido únicamente para ${AppConfig.adminEmail}', style: GoogleFonts.fredoka(color: Colors.white)),
        ),
      );
      return;
    }

    final passwordCtrl = TextEditingController();
    bool isObscured = true;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.bgWarmCream,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTerracotta.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock_person_rounded, color: AppTheme.primaryTerracotta, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Acceso Admin',
                      style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryTerracotta),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.emeraldGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, color: AppTheme.emeraldGreen, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sesión: ${AppConfig.adminEmail}',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.emeraldGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ingresa la contraseña de administrador:',
                    style: GoogleFonts.fredoka(fontSize: 13, color: AppTheme.textPrimaryDark),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: isObscured,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Contraseña',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      suffixIcon: IconButton(
                        icon: Icon(isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                        onPressed: () => setDialogState(() => isObscured = !isObscured),
                      ),
                    ),
                    onSubmitted: (val) {
                      if (val.trim() == AppConfig.adminPassword) {
                        Navigator.pop(context);
                        _showAdminDialog(context, marketplaceController);
                      } else {
                        setDialogState(() {
                          errorMessage = '❌ Contraseña incorrecta. Acceso denegado.';
                        });
                      }
                    },
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMessage!,
                      style: GoogleFonts.fredoka(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: GoogleFonts.fredoka(color: AppTheme.textMutedWarm)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (passwordCtrl.text.trim() == AppConfig.adminPassword) {
                      Navigator.pop(context);
                      _showAdminDialog(context, marketplaceController);
                    } else {
                      setDialogState(() {
                        errorMessage = '❌ Contraseña incorrecta. Acceso denegado.';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTerracotta,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Ingresar', style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAdminDialog(BuildContext context, MarketplaceController marketplaceController) {
    final nameCtrl = TextEditingController();
    final priceUsdCtrl = TextEditingController(text: '14.99');
    final pricePtsCtrl = TextEditingController(text: '220');
    final stockCtrl = TextEditingController(text: '2');
    final tagCtrl = TextEditingController(text: 'Nueva Colección');
    String selectedImageUrl = 'https://images.unsplash.com/photo-1548199973-03cce0bbc87b?w=600';
    bool isUploadingToR2 = false;

    final List<String> presetImages = [
      'https://images.unsplash.com/photo-1548199973-03cce0bbc87b?w=600',
      'https://images.unsplash.com/photo-1583337130417-3346a1be7dee?w=600',
      'https://images.unsplash.com/photo-1576201836106-db1758fd1c97?w=600',
      'https://images.unsplash.com/photo-1587300003388-59208cc962cb?w=600',
      'https://images.unsplash.com/photo-1560807707-8cc77767d783?w=600',
    ];

    Future<void> pickAndUploadBandanaPhoto(ImageSource source, StateSetter setAdminState) async {
      try {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: source,
          imageQuality: 90,
          maxWidth: 1080,
          maxHeight: 1080,
        );
        if (pickedFile == null) return;

        setAdminState(() => isUploadingToR2 = true);
        final bytes = await pickedFile.readAsBytes();
        final ext = pickedFile.name.contains('.') ? pickedFile.name.split('.').last : 'jpg';
        final filename = 'bandana_${DateTime.now().millisecondsSinceEpoch}.$ext';

        final renderBackend = RenderBackendService();
        final r2Storage = R2StorageService();

        final uploadRes = await renderBackend.requestUploadUrl(
          petId: 'bandana_admin_${const Uuid().v4().substring(0, 8)}',
          mediaType: 'image',
          filename: filename,
        );

        if (uploadRes['success'] == true) {
          final presignedPutUrl = uploadRes['presignedPutUrl'] as String;
          final publicUrl = uploadRes['publicUrl'] as String;

          final finalUrl = await r2Storage.uploadMediaWithPresignedUrl(
            presignedPutUrl: presignedPutUrl,
            publicUrl: publicUrl,
            bytes: bytes,
            contentType: 'image/jpeg',
          );

          setAdminState(() {
            selectedImageUrl = finalUrl;
            isUploadingToR2 = false;
          });

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.emeraldGreen,
                content: Text('☁️ ¡Foto de bandana guardada exitosamente en Cloudflare R2!', style: GoogleFonts.fredoka(color: Colors.white)),
              ),
            );
          }
        } else {
          setAdminState(() => isUploadingToR2 = false);
        }
      } catch (e) {
        setAdminState(() => isUploadingToR2 = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.primaryTerracotta,
              content: Text('Error al subir a Cloudflare R2: $e', style: GoogleFonts.fredoka(color: Colors.white)),
            ),
          );
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setAdminState) {
            final isR2Url = selectedImageUrl.startsWith('https://media.pawbooklife.com');

            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: const BoxDecoration(
                color: AppTheme.bgWarmCream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
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
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryTerracotta.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primaryTerracotta, size: 24),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Panel Admin: Bandanas & Stock',
                              style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // SECTION 1: ADD NEW PRODUCT
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderWarm),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.primaryTerracotta, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Añadir Nueva Bandana (Cloudflare & Supabase)',
                                style: GoogleFonts.fredoka(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Name
                          TextField(
                            controller: nameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Nombre de la Bandana',
                              hintText: 'Ej. Sunset Safari Bandana 🐾',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Prices & Stock Row
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: priceUsdCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Precio USD (\$)',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: pricePtsCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Puntos (pts)',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: stockCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Stock Inicial',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Tag
                          TextField(
                            controller: tagCtrl,
                            decoration: InputDecoration(
                              labelText: 'Etiqueta / Tag',
                              hintText: 'Ej. Solana Exclusive, Nuevo',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // DIMENSION SPECIFICATION CARD
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.bgWarmCream,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.accentOrange.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.aspect_ratio_rounded, color: AppTheme.accentOrange, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      '📐 Dimensiones Recomendadas para la Foto:',
                                      style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryTerracotta),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '• Óptima: 1080 x 1080 px (Relación 1:1 Cuadrada)\n• Mínima: 800 x 800 px\n• Formatos: JPG, PNG o WebP (Máx. 2 MB)',
                                  style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMutedWarm, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // IMAGE UPLOAD & PREVIEW SECTION
                          Text('Foto de la Bandana (Cloudflare R2):', style: GoogleFonts.fredoka(fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              // Preview box
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      width: 72,
                                      height: 72,
                                      color: AppTheme.surfaceWarm,
                                      child: isUploadingToR2
                                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primaryTerracotta))
                                          : Image.network(
                                              selectedImageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.pets, color: AppTheme.primaryTerracotta)),
                                            ),
                                    ),
                                  ),
                                  if (isR2Url)
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(color: AppTheme.emeraldGreen, shape: BoxShape.circle),
                                        child: const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 12),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      height: 36,
                                      child: ElevatedButton.icon(
                                        onPressed: isUploadingToR2 ? null : () => pickAndUploadBandanaPhoto(ImageSource.gallery, setAdminState),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.emeraldGreen,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 16),
                                        label: Text(
                                          isUploadingToR2 ? 'Subiendo...' : 'Subir a Cloudflare R2',
                                          style: GoogleFonts.fredoka(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 32,
                                      child: OutlinedButton.icon(
                                        onPressed: isUploadingToR2 ? null : () => pickAndUploadBandanaPhoto(ImageSource.camera, setAdminState),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: AppTheme.borderWarm),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        icon: const Icon(Icons.camera_alt_rounded, size: 14, color: AppTheme.textMutedWarm),
                                        label: Text('Tomar Foto', style: GoogleFonts.fredoka(fontSize: 11, color: AppTheme.textPrimaryDark)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Preset Images
                          Text('O elige una de las fotos predefinidas:', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMutedWarm)),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 50,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: presetImages.length,
                              itemBuilder: (ctx, idx) {
                                final img = presetImages[idx];
                                final isSelected = selectedImageUrl == img;
                                return GestureDetector(
                                  onTap: () => setAdminState(() => selectedImageUrl = img),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected ? AppTheme.emeraldGreen : AppTheme.borderWarm,
                                        width: isSelected ? 2.5 : 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(img, width: 48, height: 48, fit: BoxFit.cover),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: isUploadingToR2
                                  ? null
                                  : () {
                                      final name = nameCtrl.text.trim();
                                      if (name.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: AppTheme.primaryTerracotta,
                                            content: Text('Por favor ingresa un nombre para la bandana', style: GoogleFonts.fredoka()),
                                          ),
                                        );
                                        return;
                                      }

                                      final double usd = double.tryParse(priceUsdCtrl.text) ?? 14.99;
                                      final int pts = int.tryParse(pricePtsCtrl.text) ?? 200;
                                      final int stock = int.tryParse(stockCtrl.text) ?? 2;
                                      final tag = tagCtrl.text.trim().isEmpty ? 'Nuevo' : tagCtrl.text.trim();

                                      final newProduct = BandanaProductModel(
                                        id: 'bdn_${DateTime.now().millisecondsSinceEpoch}',
                                        name: name,
                                        priceUsd: usd,
                                        pricePoints: pts,
                                        imageUrl: selectedImageUrl,
                                        stock: stock,
                                        tag: tag,
                                        colorValue: AppTheme.accentOrange.value,
                                      );

                                      marketplaceController.addProduct(newProduct);
                                      nameCtrl.clear();
                                      setAdminState(() {});

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: AppTheme.emeraldGreen,
                                          content: Text('✅ ¡Bandana "$name" guardada en Supabase y publicada!', style: GoogleFonts.fredoka(color: Colors.white)),
                                        ),
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.emeraldGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.cloud_done_rounded, color: Colors.white),
                              label: Text('Guardar en Supabase y Publicar', style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // SECTION 2: LIVE STOCK MANAGEMENT OF ALL PRODUCTS
                    Text(
                      '📦 Inventario y Stock de Bandanas',
                      style: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark),
                    ),
                    const SizedBox(height: 10),

                    Consumer<MarketplaceController>(
                      builder: (ctx, mkt, _) {
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: mkt.products.length,
                          itemBuilder: (ctx, idx) {
                            final prod = mkt.products[idx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: prod.isSoldOut ? Colors.red.withOpacity(0.4) : AppTheme.borderWarm),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(prod.imageUrl, width: 48, height: 48, fit: BoxFit.cover),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prod.name,
                                          style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '\$${prod.priceUsd} USD • ${prod.pricePoints} pts',
                                          style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMutedWarm),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          prod.isSoldOut ? '🔴 AGOTADO (0 un.)' : '🟢 Stock: ${prod.stock} un.',
                                          style: GoogleFonts.fredoka(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: prod.isSoldOut ? Colors.red : AppTheme.emeraldGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Stock Steppers
                                  IconButton(
                                    onPressed: () => mkt.updateStock(prod.id, prod.stock - 1),
                                    icon: const Icon(Icons.remove_circle_outline, size: 22, color: AppTheme.primaryTerracotta),
                                    tooltip: '-1 unidad',
                                  ),
                                  IconButton(
                                    onPressed: () => mkt.updateStock(prod.id, prod.stock + 1),
                                    icon: const Icon(Icons.add_circle_outline, size: 22, color: AppTheme.emeraldGreen),
                                    tooltip: '+1 unidad',
                                  ),
                                  IconButton(
                                    onPressed: () => mkt.updateStock(prod.id, 2),
                                    icon: const Icon(Icons.replay_rounded, size: 20, color: AppTheme.solanaPurple),
                                    tooltip: 'Restablecer a 2',
                                  ),
                                  IconButton(
                                    onPressed: () => mkt.deleteProduct(prod.id),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.grey),
                                    tooltip: 'Eliminar bandana',
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
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
    final marketplaceController = Provider.of<MarketplaceController>(context);
    final oracleController = Provider.of<OracleController>(context);
    final userScore = authController.currentProfile?.pawtScore ?? 100;
    final products = marketplaceController.products;
    final currentUserEmail = authController.currentProfile?.email?.toLowerCase().trim() ?? '';
    final bool isAdmin = currentUserEmail == AppConfig.adminEmail.toLowerCase().trim();

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
          // Admin Panel Button (ONLY VISIBLE TO wernesto66@gmail.com)
          if (isAdmin)
            GestureDetector(
              onTap: () => _promptAdminPasswordDialog(context, marketplaceController, authController),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.solanaPurple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.solanaPurple.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.solanaPurple, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Admin Stock',
                      style: GoogleFonts.fredoka(color: AppTheme.solanaPurple, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              'Stock 2 un. c/u',
                              style: GoogleFonts.fredoka(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    langController.t('exclusiveBandanas'),
                    style: GoogleFonts.fredoka(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Compra con Puntos PawtScore o paga con tu Wallet de Solana (Solana Pay ⚡). Selecciona hasta el stock disponible.',
                    style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.9), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  langController.t('featuredCollection'),
                  style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${products.length} productos',
                  style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.60,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: products.length,
              itemBuilder: (ctx, idx) {
                final item = products[idx];
                final canAfford = userScore >= item.pricePoints;
                final isSoldOut = item.isSoldOut;

                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWarm,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSoldOut ? Colors.red.withOpacity(0.35) : AppTheme.borderWarm,
                      width: isSoldOut ? 1.5 : 1.2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Product Image (Dimmed / Opacity reduced when sold out)
                            Opacity(
                              opacity: isSoldOut ? 0.38 : 1.0,
                              child: Image.network(
                                item.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppTheme.surfaceWarm,
                                  child: const Center(
                                    child: Icon(Icons.pets, color: AppTheme.primaryTerracotta, size: 36),
                                  ),
                                ),
                              ),
                            ),

                            // Top Tag (e.g. Solana Exclusive)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSoldOut ? Colors.grey[700] : item.color,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  item.tag,
                                  style: GoogleFonts.fredoka(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                            // Stock Badge (Top Right)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isSoldOut ? Colors.red : Colors.black.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSoldOut ? Icons.block_rounded : Icons.inventory_rounded,
                                      color: Colors.white,
                                      size: 11,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      isSoldOut ? 'Agotado' : 'Stock: ${item.stock}',
                                      style: GoogleFonts.fredoka(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // OVERLAY STAMP: SOLD OUT / VENDIDO
                            if (isSoldOut)
                              Center(
                                child: Transform.rotate(
                                  angle: -0.15,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD32F2F).withOpacity(0.92),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 16),
                                        const SizedBox(width: 5),
                                        Text(
                                          'SOLD OUT / VENDIDO',
                                          style: GoogleFonts.fredoka(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
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
                              item.name,
                              style: GoogleFonts.fredoka(
                                color: isSoldOut ? AppTheme.textMutedWarm : AppTheme.textPrimaryDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
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
                                      onPressed: isSoldOut
                                          ? null
                                          : () => _showRedeemModal(context, item, authController, marketplaceController),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isSoldOut
                                            ? Colors.grey.shade300
                                            : (canAfford ? AppTheme.accentOrange : AppTheme.cardWarm),
                                        padding: EdgeInsets.zero,
                                        elevation: isSoldOut ? 0 : 1,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Text(
                                        isSoldOut ? 'Agotado' : '${item.pricePoints}pt',
                                        style: GoogleFonts.fredoka(
                                          color: isSoldOut
                                              ? Colors.grey.shade600
                                              : (canAfford ? Colors.white : AppTheme.textMutedWarm),
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
                                      onPressed: isSoldOut
                                          ? null
                                          : () => _showCheckoutModal(context, item, langController, authController, marketplaceController, oracleController),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isSoldOut ? Colors.grey.shade300 : AppTheme.primaryTerracotta,
                                        padding: EdgeInsets.zero,
                                        elevation: isSoldOut ? 0 : 1,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Text(
                                        isSoldOut ? 'Agotado' : '\$${item.priceUsd}',
                                        style: GoogleFonts.fredoka(
                                          color: isSoldOut ? Colors.grey.shade600 : Colors.white,
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
