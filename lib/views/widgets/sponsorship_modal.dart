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
    final isOwnPet = auth.isAuthenticated && (
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
            '🐾 No puedes auto-patrocinar a tu propia mascota (${pet.name}). Los patrocinios son otorgados por otros tutores y miembros de la comunidad.',
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
  String _selectedWallet = 'Phantom'; // 'Phantom', 'Solflare', 'Seeker', 'Dynamic'
  bool _isProcessing = false;
  String _processingStep = '';

  final DynamicAuthService _dynamicAuthService = DynamicAuthService();
  final RenderBackendService _renderService = RenderBackendService();
  final SupabaseService _supabaseService = SupabaseService();

  double _calculateUsdPrice(OracleController oracle) =>
      double.parse(oracle.convertSkrToUsd(_selectedSkrAmount).toStringAsFixed(2));

  Future<void> _processWalletSponsorship(
    AuthController authController,
    OracleController oracleController,
    LanguageController langController,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final usdPrice = _calculateUsdPrice(oracleController);
    final solPrice = (usdPrice / 155.0).toStringAsFixed(5);

    // 10% Platform Fee Calculation
    final totalSkr = _selectedSkrAmount;
    final feePercent = AppConfig.sponsorshipPlatformFeePercent; // 10%
    final feeSkr = (totalSkr * (feePercent / 100.0)).round();
    final netSkr = totalSkr - feeSkr;
    final totalSol = double.tryParse(solPrice) ?? 0.001;
    final feeSol = totalSol * (feePercent / 100.0);
    final netSol = totalSol - feeSol;

    setState(() {
      _isProcessing = true;
      _processingStep = '⚡ Abriendo y conectando con $_selectedWallet...';
    });

    try {
      // Step 1: Connect specific Solana Wallet (Phantom / Solflare / Seeker / Dynamic)
      await Future.delayed(const Duration(milliseconds: 400));
      final walletResult = await _dynamicAuthService.connectSpecificWallet(_selectedWallet);

      if (!walletResult.isSuccess && walletResult.errorMessage != null) {
        throw Exception(walletResult.errorMessage);
      }

      final payerWallet = walletResult.walletAddress ??
          authController.currentProfile?.walletAddress ??
          'sol_${widget.userId.substring(0, 12)}';
      final petWallet = widget.pet.dynamicWalletAddress;

      // Step 2: Request user approval & sign transaction on Solflare / Phantom popup
      if (mounted) {
        setState(() => _processingStep = '✍️ Autoriza la transacción en la ventana emergente de $_selectedWallet...');
      }

      // Execute transfer to Platform Treasury Custody Wallet
      final txResult = await _dynamicAuthService.sendWalletTransfer(
        walletType: _selectedWallet,
        recipientAddress: AppConfig.marketplaceTreasuryWallet,
        solAmount: totalSol > 0 ? totalSol : 0.001,
      );

      if (!txResult.isSuccess) {
        if (txResult.userCancelled) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.primaryTerracotta,
                duration: const Duration(seconds: 4),
                content: Text(
                  'ℹ️ Cancelaste la transacción en $_selectedWallet. No se realizó ningún cargo.',
                  style: GoogleFonts.fredoka(),
                ),
              ),
            );
          }
          return;
        }
        throw Exception(txResult.errorMessage ?? 'Error desconocido al transferir con $_selectedWallet');
      }

      // Step 3: Transaction broadcasted successfully on Solana
      if (mounted) {
        setState(() => _processingStep = '🚀 Confirmando \$SKR en la blockchain de Solana...');
      }

      final txHash = txResult.signature ?? 'sol_${_selectedWallet.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
      final solscanUrl = txResult.solscanUrl;

      // Register on Backend with Fee breakdown
      await _renderService.payWithCardConvertToSkr(
        sponsorId: widget.userId,
        petId: widget.pet.id,
        amountUsd: usdPrice,
        skrAmount: totalSkr,
        sponsorWallet: txResult.fromAddress ?? payerWallet,
        petWallet: petWallet,
      );

      // Register in Supabase with 10% fee deducted
      await _supabaseService.sponsorPet(
        sponsorId: widget.userId,
        petId: widget.pet.id,
        amount: totalSkr,
        paymentMethod: 'solana_${_selectedWallet.toLowerCase()}',
        txHash: txHash,
        feePercent: feePercent,
        feeAmount: feeSkr,
        netAmount: netSkr,
      ).timeout(const Duration(seconds: 4), onTimeout: () {});

      authController.addPawtScore(totalSkr);

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
                        '⚡ ¡Patrocinio Confirmado en $_selectedWallet!',
                        style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        '• Creador (@${widget.pet.name}): $netSkr \$SKR (~${netSol.toStringAsFixed(5)} SOL)\n• Comisión (10%): $feeSkr \$SKR (~${feeSol.toStringAsFixed(5)} SOL)\nTx: ${txHash.length > 20 ? "${txHash.substring(0, 16)}..." : txHash}',
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
    final currentSolPrice = (currentUsdPrice / 155.0).toStringAsFixed(5);

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
                          'Patrocinar a @${widget.pet.name} 🐾',
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
                              'Creador Verificado en Solana 🐾',
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
              const SizedBox(height: 16),

              // Select Amount ($SKR Token packages)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '1. Selecciona el Paquete de \$SKR:',
                    style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Oráculo DEX ⚡',
                    style: GoogleFonts.outfit(color: AppTheme.emeraldGreen, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildAmountOption(100, oracleController.convertSkrToUsd(100), 'Snack 🦴'),
                  const SizedBox(width: 8),
                  _buildAmountOption(250, oracleController.convertSkrToUsd(250), 'Favorito ⭐'),
                  const SizedBox(width: 8),
                  _buildAmountOption(500, oracleController.convertSkrToUsd(500), 'Super 👑'),
                  const SizedBox(width: 8),
                  _buildAmountOption(1000, oracleController.convertSkrToUsd(1000), 'VIP 💎'),
                ],
              ),
              const SizedBox(height: 16),

              // Select Solana Wallet Provider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '2. Selecciona tu Wallet de Solana:',
                    style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.emeraldGreen.withOpacity(0.3)),
                    ),
                    child: Text(
                      '⚡ Red Solana',
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
                        id: 'Phantom',
                        title: 'Phantom',
                        subtitle: 'Extensión / Móvil',
                        iconData: Icons.shield_rounded,
                        color: const Color(0xFFAB9FF2),
                      ),
                      const SizedBox(width: 8),
                      _buildWalletOption(
                        id: 'Solflare',
                        title: 'Solflare',
                        subtitle: 'Web / Extensión',
                        iconData: Icons.wb_sunny_rounded,
                        color: const Color(0xFFFC8C03),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildWalletOption(
                        id: 'Seeker',
                        title: 'Solana Seeker',
                        subtitle: 'Seed Vault Nativo 📱',
                        iconData: Icons.phone_android_rounded,
                        color: const Color(0xFF14F195),
                        badge: 'Nativo Mobile',
                      ),
                      const SizedBox(width: 8),
                      _buildWalletOption(
                        id: 'Dynamic',
                        title: 'Dynamic SIWS',
                        subtitle: 'Pawtbook Wallet',
                        iconData: Icons.account_balance_wallet_rounded,
                        color: AppTheme.emeraldGreen,
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
                  color: AppTheme.surfaceWarm,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderWarm),
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
                            Text('Patrocinio Total:', style: GoogleFonts.fredoka(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppTheme.emeraldGreen,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$_selectedSkrAmount \$SKR ≈ \$$currentUsdPrice USD',
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
                            Text('Recibe Creador (90%):', style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text(
                          '${(_selectedSkrAmount * 0.90).round()} \$SKR (~${((double.tryParse(currentSolPrice) ?? 0.0) * 0.90).toStringAsFixed(5)} SOL)',
                          style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontSize: 12, fontWeight: FontWeight.bold),
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
                            Text('Comisión Plataforma (10%):', style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 11)),
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
                    backgroundColor: AppTheme.emeraldGreen,
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
                            const Icon(
                              Icons.bolt_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pagar $_selectedSkrAmount \$SKR con $_selectedWallet',
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
            color: isSelected ? AppTheme.emeraldGreen : AppTheme.surfaceWarm,
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
                  color: isSelected ? Colors.amberAccent : AppTheme.accentOrange,
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
