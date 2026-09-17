import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/language_controller.dart';
import '../../controllers/oracle_controller.dart';
import '../../models/pet_model.dart';
import '../../services/dynamic_auth_service.dart';
import '../../services/render_backend_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import 'terms_and_conditions_modal.dart';

class SponsorshipModal extends StatefulWidget {
  final PetModel pet;
  final String userId;

  const SponsorshipModal({
    super.key,
    required this.pet,
    required this.userId,
  });

  static void show(BuildContext context, {required PetModel pet, required String userId}) {
    final auth = Provider.of<AuthController>(context, listen: false);
    final langController = Provider.of<LanguageController>(context, listen: false);

    if (!auth.isAuthenticated) {
      TermsAndConditionsModal.show(context);
      return;
    }

    final isOwnPet = (
      pet.ownerId == auth.currentProfile?.id ||
      pet.id == auth.activePet?.id ||
      auth.userPets.any((p) => p.id == pet.id)
    );

    if (isOwnPet) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryTerracotta,
          duration: const Duration(seconds: 3),
          content: Text(
            langController.t('sponsorSelfWarning').replaceAll('{name}', pet.name),
            style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SponsorshipModal(pet: pet, userId: userId),
    );
  }

  @override
  State<SponsorshipModal> createState() => _SponsorshipModalState();
}

class _SponsorshipModalState extends State<SponsorshipModal> {
  int _selectedSkrAmount = 100;
  String _selectedWallet = 'Dynamic'; // Default to Dynamic Embedded Wallet for instant payments
  String _selectedCurrency = 'SKR'; // 'SKR' (Tokens $SKR) or 'SOL' (Solana SOL via Oracle)
  bool _isProcessing = false;
  String _processingStep = '';

  final DynamicAuthService _dynamicAuthService = DynamicAuthService();
  final RenderBackendService _renderService = RenderBackendService();
  final SupabaseService _supabaseService = SupabaseService();

  double _calculateUsdPrice(OracleController oracle) =>
      double.parse(oracle.convertSkrToUsd(_selectedSkrAmount).toStringAsFixed(2));

  void _showWalletNotInstalledDialog(
    BuildContext context,
    String walletName,
    AuthController authController,
    OracleController oracleController,
    LanguageController langController,
  ) {
    final downloadUrl = walletName.toLowerCase().contains('solflare')
        ? 'https://solflare.com'
        : 'https://phantom.app';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgWarmCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryTerracotta.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primaryTerracotta, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Wallet $walletName',
                style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryTerracotta),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              langController.t('walletNotInstalledDesc').replaceAll('{wallet}', walletName),
              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textPrimaryDark, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              try {
                js.context.callMethod('open', [downloadUrl, '_blank']);
              } catch (_) {}
            },
            child: Text(langController.t('installWalletBtn').replaceAll('{wallet}', walletName), style: GoogleFonts.fredoka(color: AppTheme.textMutedWarm)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emeraldGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: Text(langController.t('payWithDynamicWallet'), style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedWallet = 'Dynamic');
              _processWalletSponsorship(authController, oracleController, langController);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _processWalletSponsorship(
    AuthController authController,
    OracleController oracleController,
    LanguageController langController,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final usdPrice = _calculateUsdPrice(oracleController);
    final totalSkr = _selectedSkrAmount;
    final totalSol = oracleController.priceSol > 0
        ? totalSkr * oracleController.priceSol
        : (usdPrice / 155.0);

    final isDynamic = _selectedWallet.toLowerCase().contains('dynamic');
    final isSkr = _selectedCurrency == 'SKR';

    // 1. Dynamic In-App Balance Verification for $SKR
    if (isDynamic && isSkr) {
      final userSkrBalance = authController.currentProfile?.pawtScore ?? 0;
      if (userSkrBalance < totalSkr) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryTerracotta,
            duration: const Duration(seconds: 5),
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    langController.t('insufficientDynamicBalance')
                        .replaceAll('{balance}', userSkrBalance.toString())
                        .replaceAll('{total}', totalSkr.toString()),
                    style: GoogleFonts.fredoka(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
        return;
      }
    }

    // 10% Platform Fee Calculation
    final feePercent = AppConfig.sponsorshipPlatformFeePercent; // 10%
    final feeSkr = (totalSkr * (feePercent / 100.0)).round();
    final netSkr = totalSkr - feeSkr;
    final feeSol = totalSol * (feePercent / 100.0);
    final netSol = totalSol - feeSol;

    setState(() {
      _isProcessing = true;
      _processingStep = isDynamic
          ? langController.t('processingDynamicSponsorship').replaceAll('{total}', totalSkr.toString())
          : langController.t('confirmInWallet')
              .replaceAll('{wallet}', _selectedWallet)
              .replaceAll('{amount}', isSkr ? "$totalSkr \$SKR" : "${totalSol.toStringAsFixed(4)} SOL");
    });

    try {
      final payerWallet = authController.currentProfile?.walletAddress ??
          'sol_${widget.userId.length > 12 ? widget.userId.substring(0, 12) : widget.userId}';
      final petWallet = widget.pet.dynamicWalletAddress;

      // Execute transfer directly via Solana Wallet Adapter
      final txResult = await _dynamicAuthService.sendWalletTransfer(
        walletType: _selectedWallet,
        recipientAddress: AppConfig.marketplaceTreasuryWallet,
        tokenType: _selectedCurrency,
        skrAmount: totalSkr.toDouble(),
        solAmount: totalSol,
        fromAddress: payerWallet,
      );

      if (!txResult.isSuccess) {
        if (txResult.userCancelled) {
          if (mounted) {
            setState(() => _isProcessing = false);
            messenger.showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.primaryTerracotta,
                duration: const Duration(seconds: 4),
                content: Text(
                  langController.t('txCancelledInWallet').replaceAll('{wallet}', _selectedWallet),
                  style: GoogleFonts.fredoka(color: Colors.white),
                ),
              ),
            );
          }
          return;
        }

        final errStr = txResult.errorMessage ?? '';
        final isMissing = txResult.isNotInstalled || errStr.toLowerCase().contains('no está instalada') || errStr.toLowerCase().contains('not installed');
        if (isMissing && !isDynamic) {
          if (mounted) {
            setState(() => _isProcessing = false);
            _showWalletNotInstalledDialog(context, _selectedWallet, authController, oracleController, langController);
          }
          return;
        }

        throw Exception(errStr.isNotEmpty ? errStr : 'Error: $_selectedWallet');
      }

      // Step 2: Transaction broadcasted successfully on Solana
      if (mounted) {
        setState(() => _processingStep = langController.t('confirmingOnSolana'));
      }

      final txHash = txResult.signature ?? 'sol_${_selectedWallet.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
      final solscanUrl = txResult.solscanUrl;

      // If paid via Dynamic in-app balance, deduct from user's account
      if (isDynamic && isSkr) {
        authController.deductPawtScore(totalSkr);
      }

      // If paying with Card, invoke Card-to-SKR on-ramp backend
      if (_selectedWallet.toLowerCase() == 'tarjeta' || _selectedWallet.toLowerCase() == 'card') {
        await _renderService.payWithCardConvertToSkr(
          sponsorId: widget.userId,
          petId: widget.pet.id,
          amountUsd: usdPrice,
          skrAmount: totalSkr,
          sponsorWallet: txResult.fromAddress ?? payerWallet,
          petWallet: petWallet,
        );
      } else {
        // Register in Supabase with 10% fee deducted and genuine Solana tx hash
        await _supabaseService.sponsorPet(
          sponsorId: widget.userId,
          petId: widget.pet.id,
          amount: totalSkr,
          paymentMethod: 'solana_${_selectedCurrency.toLowerCase()}_${_selectedWallet.toLowerCase()}',
          txHash: txHash,
          feePercent: feePercent,
          feeAmount: feeSkr,
          netAmount: netSkr,
        ).timeout(const Duration(seconds: 4), onTimeout: () {});
      }

      if (mounted) {
        nav.pop();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.emeraldGreen,
            duration: const Duration(seconds: 8),
            action: (solscanUrl != null && kIsWeb)
                ? SnackBarAction(
                    label: 'SOLSCAN',
                    textColor: Colors.white,
                    onPressed: () {
                      try {
                        js.context.callMethod('open', [solscanUrl, '_blank']);
                      } catch (_) {}
                    },
                  )
                : null,
            content: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        langController.t('sponsorshipConfirmed').replaceAll('{wallet}', _selectedWallet),
                        style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        '• ${langController.t("creatorLabel")} (@${widget.pet.name}): $netSkr \$SKR (~${netSol.toStringAsFixed(5)} SOL)\n• ${langController.t("platformFeeLabel")} (10%): $feeSkr \$SKR (~${feeSol.toStringAsFixed(5)} SOL)\nTx: ${txHash.length > 20 ? "${txHash.substring(0, 16)}..." : txHash}',
                        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
            content: Text('⚠️ $e', style: GoogleFonts.fredoka()),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final langController = Provider.of<LanguageController>(context);
    final authController = Provider.of<AuthController>(context);
    final oracleController = Provider.of<OracleController>(context);
    final currentUsdPrice = _calculateUsdPrice(oracleController);
    final currentSolPrice = (oracleController.priceSol > 0
            ? (_selectedSkrAmount * oracleController.priceSol)
            : (currentUsdPrice / 155.0))
        .toStringAsFixed(5);

    final userSkrBalance = authController.currentProfile?.pawtScore ?? 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.bgWarmCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            top: 14,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
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
              const SizedBox(height: 14),

              // Header: Pet Avatar & Sponsor info
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppTheme.surfaceWarm,
                    backgroundImage: NetworkImage(widget.pet.avatarUrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          langController.t('sponsorPetModalTitle').replaceAll('{name}', widget.pet.name),
                          style: GoogleFonts.fredoka(
                            color: AppTheme.primaryTerracotta,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded, size: 12, color: AppTheme.emeraldGreen),
                            const SizedBox(width: 4),
                            Text(
                              langController.t('verifiedCreatorSolana'),
                              style: GoogleFonts.outfit(color: AppTheme.emeraldGreen, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.emeraldGreen),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, color: AppTheme.emeraldGreen, size: 14),
                        const SizedBox(width: 3),
                        Text(
                          '${oracleController.formattedPriceUsd} / \$SKR',
                          style: GoogleFonts.fredoka(color: AppTheme.emeraldGreen, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Currency / Token Selection: $SKR Token vs SOL
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    langController.t('paymentMethodStep'),
                    style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _selectedWallet == 'Dynamic'
                        ? '${langController.t("availableBalance")} $userSkrBalance \$SKR'
                        : 'SPL Token / SOL',
                    style: GoogleFonts.outfit(color: AppTheme.emeraldGreen, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCurrency = 'SKR'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                        decoration: BoxDecoration(
                          color: _selectedCurrency == 'SKR'
                              ? AppTheme.pastelMint
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedCurrency == 'SKR' ? AppTheme.emeraldGreen : AppTheme.borderWarm,
                            width: _selectedCurrency == 'SKR' ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('💎 ', style: TextStyle(fontSize: 16)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  langController.t('skrTokensSpl'),
                                  style: GoogleFonts.fredoka(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedCurrency == 'SKR' ? AppTheme.emeraldGreen : AppTheme.textPrimaryDark,
                                  ),
                                ),
                                Text(
                                  langController.t('nativeSplToken'),
                                  style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.textMutedWarm),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCurrency = 'SOL'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                        decoration: BoxDecoration(
                          color: _selectedCurrency == 'SOL'
                              ? AppTheme.pastelPeach
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedCurrency == 'SOL' ? AppTheme.brandCoral : AppTheme.borderWarm,
                            width: _selectedCurrency == 'SOL' ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('⚡ ', style: TextStyle(fontSize: 16)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  langController.t('solanaSol'),
                                  style: GoogleFonts.fredoka(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedCurrency == 'SOL' ? AppTheme.brandCoral : AppTheme.textPrimaryDark,
                                  ),
                                ),
                                Text(
                                  langController.t('oracleConversion'),
                                  style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.textMutedWarm),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Select Amount ($SKR Token packages)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    langController.t('selectSkrPackage'),
                    style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    langController.t('dexOracle'),
                    style: GoogleFonts.outfit(color: AppTheme.emeraldGreen, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildAmountOption(100, oracleController.convertSkrToUsd(100), langController.t('packageSnack')),
                  const SizedBox(width: 8),
                  _buildAmountOption(250, oracleController.convertSkrToUsd(250), langController.t('packageFavorite')),
                  const SizedBox(width: 8),
                  _buildAmountOption(500, oracleController.convertSkrToUsd(500), langController.t('packageSuper')),
                  const SizedBox(width: 8),
                  _buildAmountOption(1000, oracleController.convertSkrToUsd(1000), langController.t('packageVip')),
                ],
              ),
              const SizedBox(height: 14),

              // Select Solana Wallet Provider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    langController.t('selectSolanaWalletStep'),
                    style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '⚡ ${langController.t("solanaNetwork")}',
                      style: GoogleFonts.outfit(color: AppTheme.emeraldGreen, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Grid / List of Wallet Options
              Column(
                children: [
                  Row(
                    children: [
                      _buildWalletOption(
                        id: 'Dynamic',
                        title: 'Dynamic SIWS',
                        subtitle: 'Pawtbook Wallet',
                        iconData: Icons.account_balance_wallet_rounded,
                        color: AppTheme.emeraldGreen,
                        badge: langController.t('directBadge'),
                      ),
                      const SizedBox(width: 8),
                      _buildWalletOption(
                        id: 'Phantom',
                        title: 'Phantom',
                        subtitle: langController.t('extensionWeb3'),
                        iconData: Icons.shield_rounded,
                        color: const Color(0xFFAB9FF2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildWalletOption(
                        id: 'Solflare',
                        title: 'Solflare',
                        subtitle: langController.t('webExtension'),
                        iconData: Icons.wb_sunny_rounded,
                        color: const Color(0xFFFC8C03),
                      ),
                      const SizedBox(width: 8),
                      _buildWalletOption(
                        id: 'Seeker',
                        title: 'Solana Seeker',
                        subtitle: 'Seed Vault 📱',
                        iconData: Icons.phone_android_rounded,
                        color: const Color(0xFF14F195),
                        badge: 'Mobile',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Live Oracle Conversion & 10% Fee Breakdown Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.pastelMint.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.swap_horizontal_circle_rounded, color: AppTheme.emeraldGreen, size: 18),
                            const SizedBox(width: 6),
                            Text(langController.t('totalSponsorship'), style: GoogleFonts.fredoka(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: _selectedCurrency == 'SKR' ? AppTheme.emeraldGreen : AppTheme.brandCoral,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _selectedCurrency == 'SKR'
                                ? '$_selectedSkrAmount \$SKR ≈ \$$currentUsdPrice USD'
                                : '$currentSolPrice SOL (≈ $_selectedSkrAmount \$SKR)',
                            style: GoogleFonts.fredoka(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: AppTheme.borderWarm),
                    const SizedBox(height: 8),

                    // Net Creator Share (90%)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.pets_rounded, size: 14, color: AppTheme.primaryTerracotta),
                            const SizedBox(width: 4),
                            Text(langController.t('creatorReceives'), style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text(
                          '${(_selectedSkrAmount * 0.90).round()} \$SKR (~${((double.tryParse(currentSolPrice) ?? 0.0) * 0.90).toStringAsFixed(5)} SOL)',
                          style: GoogleFonts.fredoka(color: AppTheme.brandCoral, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Platform Fee (10%)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_rounded, size: 14, color: AppTheme.accentOrange),
                            const SizedBox(width: 4),
                            Text(langController.t('platformFeePercent'), style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 11)),
                          ],
                        ),
                        Text(
                          '${(_selectedSkrAmount * 0.10).round()} \$SKR (~${((double.tryParse(currentSolPrice) ?? 0.0) * 0.10).toStringAsFixed(5)} SOL)',
                          style: GoogleFonts.fredoka(color: AppTheme.textMutedWarm, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (_isProcessing) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWarm,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.accentOrange),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: AppTheme.emeraldGreen, strokeWidth: 2.5),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _processingStep,
                          style: GoogleFonts.fredoka(
                            color: AppTheme.emeraldGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Action Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : () => _processWalletSponsorship(authController, oracleController, langController),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedCurrency == 'SKR' ? AppTheme.emeraldGreen : AppTheme.primaryTerracotta,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    elevation: 4,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedCurrency == 'SKR' ? Icons.bolt_rounded : Icons.account_balance_wallet_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              langController.t('payWithWallet')
                                  .replaceAll('{amount}', _selectedCurrency == 'SKR' ? '$_selectedSkrAmount \$SKR' : '$currentSolPrice SOL')
                                  .replaceAll('{wallet}', _selectedWallet),
                              style: GoogleFonts.fredoka(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData iconData,
    required Color color,
    String? badge,
  }) {
    final isSelected = _selectedWallet == id;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedWallet = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : AppTheme.surfaceWarm,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : AppTheme.borderWarm,
              width: isSelected ? 2 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(iconData, color: color, size: 20),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.outfit(color: color, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: GoogleFonts.fredoka(
                  color: isSelected ? color : AppTheme.textPrimaryDark,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountOption(int skrAmount, double usdPrice, String label) {
    final isSelected = _selectedSkrAmount == skrAmount;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSkrAmount = skrAmount),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.emeraldGreen : AppTheme.pastelPeach.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.emeraldGreen : AppTheme.borderWarm,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.emeraldGreen.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$skrAmount \$SKR',
                style: GoogleFonts.fredoka(
                  color: isSelected ? Colors.white : AppTheme.textPrimaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '\$${usdPrice.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(
                  color: isSelected ? Colors.white70 : AppTheme.textMutedWarm,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: GoogleFonts.fredoka(
                  color: isSelected ? Colors.amberAccent : AppTheme.brandCoral,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
