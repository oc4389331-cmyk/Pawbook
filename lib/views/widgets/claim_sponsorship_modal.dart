import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/language_controller.dart';
import '../../controllers/oracle_controller.dart';
import '../../models/pet_model.dart';
import '../../services/dynamic_auth_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class ClaimSponsorshipModal extends StatefulWidget {
  final PetModel pet;
  final String userId;
  final int? unclaimedSkr;

  const ClaimSponsorshipModal({
    super.key,
    required this.pet,
    required this.userId,
    this.unclaimedSkr,
  });

  static Future<void> show(BuildContext context, {required PetModel pet, required String userId, int? unclaimedSkr}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClaimSponsorshipModal(pet: pet, userId: userId, unclaimedSkr: unclaimedSkr),
    );
  }

  @override
  State<ClaimSponsorshipModal> createState() => _ClaimSponsorshipModalState();
}

class _ClaimSponsorshipModalState extends State<ClaimSponsorshipModal> {
  final DynamicAuthService _dynamicAuthService = DynamicAuthService();
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _destinationWalletController = TextEditingController();

  bool _isProcessing = false;
  String _processingStep = '';
  final String _selectedTargetWallet = 'Phantom';

  @override
  void initState() {
    super.initState();
    _destinationWalletController.text = widget.pet.dynamicWalletAddress;
  }

  @override
  void dispose() {
    _destinationWalletController.dispose();
    super.dispose();
  }

  Future<void> _processClaimPayout(
    AuthController authController,
    OracleController oracleController,
    LanguageController langController,
    double claimableUsd,
    double claimableSol,
    int claimableSkr,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final targetWallet = _destinationWalletController.text.trim();

    if (claimableSkr <= 0) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryTerracotta,
          content: Text(langController.t('claimButtonLocked'), style: GoogleFonts.fredoka(color: Colors.white)),
        ),
      );
      return;
    }

    if (targetWallet.isEmpty || targetWallet.length < 32) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryTerracotta,
          content: Text(langController.t('enterValidSolanaAddress'), style: GoogleFonts.fredoka(color: Colors.white)),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingStep = '${langController.t("transferringSkrProgress")} ($claimableSkr \$SKR)';
    });

    try {
      // 1. Send strictly $SKR tokens from platform escrow/treasury to creator's wallet
      final txResult = await _dynamicAuthService.sendWalletTransfer(
        walletType: _selectedTargetWallet,
        recipientAddress: targetWallet,
        tokenType: 'SKR',
        skrAmount: claimableSkr.toDouble(),
      );

      if (!txResult.isSuccess && txResult.userCancelled) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.primaryTerracotta,
              content: Text(langController.t('txCancelledMsg'), style: GoogleFonts.fredoka(color: Colors.white)),
            ),
          );
        }
        return;
      }

      final txHash = txResult.signature ?? 'claim_skr_${DateTime.now().millisecondsSinceEpoch}';

      // 2. Lock sponsorships and register withdrawal in Supabase / Local Ledger
      await _supabaseService.processPetWithdrawal(
        petId: widget.pet.id,
        userId: widget.userId,
        destinationWallet: targetWallet,
        amountSkr: claimableSkr,
        amountSol: claimableSol,
        amountUsd: claimableUsd,
        txHash: txHash,
      );

      if (mounted) {
        nav.pop();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.emeraldGreen,
            duration: const Duration(seconds: 8),
            action: (txResult.solscanUrl != null && kIsWeb)
                ? SnackBarAction(
                    label: 'SOLSCAN',
                    textColor: Colors.white,
                    onPressed: () {
                      try {
                        js.context.callMethod('open', [txResult.solscanUrl!, '_blank']);
                      } catch (_) {}
                    },
                  )
                : null,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${langController.t("claimSuccessTitle")} ($claimableSkr \$SKR)',
                        style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        '${langController.t("claimSuccessDesc")}: ${targetWallet.substring(0, 6)}...${targetWallet.substring(targetWallet.length - 4)}\nTx: ${txHash.length > 20 ? "${txHash.substring(0, 16)}..." : txHash}',
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
            content: Text('${langController.t("payErrorMsg")} $e', style: GoogleFonts.fredoka(color: Colors.white)),
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
    final oracleController = Provider.of<OracleController>(context);
    final authController = Provider.of<AuthController>(context);
    final langController = Provider.of<LanguageController>(context);

    final totalSkr = widget.unclaimedSkr ?? 0;
    final claimableUsd = double.parse(oracleController.convertSkrToUsd(totalSkr).toStringAsFixed(2));
    final claimableSol = oracleController.convertSkrToSol(totalSkr);

    final nowUtc = DateTime.now().toUtc();
    final isMonday = nowUtc.weekday == AppConfig.claimDayOfWeek;
    final hasMinBalance = claimableUsd >= 100.0;
    final canClaim = totalSkr > 0 && hasMinBalance && isMonday;

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
            top: 16,
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
              const SizedBox(height: 16),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.emeraldGreen, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            langController.t('claimModalHeader'),
                            style: GoogleFonts.fredoka(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTerracotta,
                            ),
                          ),
                          Text(
                            '${langController.t("earningsInTreasury")}: @${widget.pet.name}',
                            style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWarm,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderWarm),
                    ),
                    child: Text(
                      'Solana Pay ⚡',
                      style: GoogleFonts.fredoka(color: AppTheme.emeraldGreen, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Balance Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(langController.t('unclaimedEarnings'), style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14F195).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF14F195).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            langController.t('treasuryBadge'),
                            style: GoogleFonts.fredoka(color: const Color(0xFF14F195), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '\$${claimableUsd.toStringAsFixed(2)} USD',
                          style: GoogleFonts.fredoka(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '≈ ${claimableSol.toStringAsFixed(4)} SOL',
                          style: GoogleFonts.outfit(color: const Color(0xFF14F195), fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$totalSkr \$SKR ${langController.t("accumulatedCommunitySponsorships")}',
                      style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Conditions Checklist Card
              Text(
                langController.t('mandatoryClaimConditions'),
                style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // Condition 1: Min $100 USD
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: hasMinBalance ? AppTheme.emeraldGreen.withValues(alpha: 0.1) : AppTheme.surfaceWarm,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasMinBalance ? AppTheme.emeraldGreen : AppTheme.borderWarm,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasMinBalance ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                      color: hasMinBalance ? AppTheme.emeraldGreen : AppTheme.accentOrange,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            langController.t('condition1Title'),
                            style: GoogleFonts.fredoka(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: hasMinBalance ? AppTheme.emeraldGreen : AppTheme.textPrimaryDark,
                            ),
                          ),
                          Text(
                            hasMinBalance
                                ? '✓ (\$${claimableUsd.toStringAsFixed(2)} USD)'
                                : '✗ (\$${claimableUsd.toStringAsFixed(2)} / \$100.00 USD. Needed: \$${(100.0 - claimableUsd).toStringAsFixed(2)} USD)',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: hasMinBalance ? AppTheme.emeraldGreen : AppTheme.textMutedWarm,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Condition 2: Mondays only
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMonday ? AppTheme.emeraldGreen.withValues(alpha: 0.1) : AppTheme.surfaceWarm,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMonday ? AppTheme.emeraldGreen : AppTheme.borderWarm,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isMonday ? Icons.check_circle_rounded : Icons.calendar_month_rounded,
                      color: isMonday ? AppTheme.emeraldGreen : AppTheme.accentOrange,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            langController.t('condition2Title'),
                            style: GoogleFonts.fredoka(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isMonday ? AppTheme.emeraldGreen : AppTheme.textPrimaryDark,
                            ),
                          ),
                          Text(
                            isMonday
                                ? '${langController.t("condition2Met")} (${nowUtc.hour.toString().padLeft(2, '0')}:${nowUtc.minute.toString().padLeft(2, '0')} UTC)'
                                : '${langController.t("condition2NotMet")} (${nowUtc.hour.toString().padLeft(2, '0')}:${nowUtc.minute.toString().padLeft(2, '0')} UTC)',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: isMonday ? AppTheme.emeraldGreen : AppTheme.textMutedWarm,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Destination Wallet Input (Visible when canClaim or for preview)
              if (canClaim) ...[
                Text(
                  langController.t('destinationWalletPrompt'),
                  style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWarm,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderWarm),
                  ),
                  child: TextField(
                    controller: _destinationWalletController,
                    style: GoogleFonts.sourceCodePro(fontSize: 12, color: AppTheme.textPrimaryDark),
                    decoration: InputDecoration(
                      hintText: langController.t('walletInputHint'),
                      hintStyle: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste_rounded, color: AppTheme.primaryTerracotta, size: 20),
                        onPressed: () async {
                          final clip = await Clipboard.getData(Clipboard.kTextPlain);
                          if (clip?.text != null) {
                            setState(() => _destinationWalletController.text = clip!.text!.trim());
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              if (_isProcessing) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWarm,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.emeraldGreen),
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
                          style: GoogleFonts.fredoka(color: AppTheme.emeraldGreen, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Main Claim Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (!canClaim || _isProcessing)
                      ? null
                      : () => _processClaimPayout(
                            authController,
                            oracleController,
                            langController,
                            claimableUsd,
                            claimableSol,
                            totalSkr,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canClaim ? AppTheme.emeraldGreen : AppTheme.cardWarm,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.borderWarm.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    elevation: canClaim ? 3 : 0,
                  ),
                  icon: Icon(
                    canClaim ? Icons.diamond_rounded : Icons.lock_rounded,
                    color: canClaim ? Colors.white : AppTheme.textMutedWarm,
                    size: 20,
                  ),
                  label: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          canClaim
                              ? '${langController.t("claimButtonReady")}: $totalSkr \$SKR (≈ \$${claimableUsd.toStringAsFixed(2)} USD)'
                              : langController.t('claimButtonLocked'),
                          style: GoogleFonts.fredoka(
                            color: canClaim ? Colors.white : AppTheme.textMutedWarm,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
