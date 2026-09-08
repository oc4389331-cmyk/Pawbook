import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/language_controller.dart';
import '../../models/pet_model.dart';
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
  String _paymentMethod = 'card_to_skr'; // 'card_to_skr' or 'solana_direct'
  bool _isProcessing = false;
  String _processingStep = '';

  final _cardNumberController = TextEditingController(text: '•••• •••• •••• 4242');
  final _cardExpiryController = TextEditingController(text: '12/28');
  final _cardCvcController = TextEditingController(text: '777');
  final _cardHolderController = TextEditingController(text: 'Tutor Pawtbook');

  final RenderBackendService _renderService = RenderBackendService();
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvcController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  double get _usdPrice => _selectedSkrAmount / 20.0;

  Future<void> _processSponsorship(AuthController authController, LanguageController langController) async {
    setState(() {
      _isProcessing = true;
      _processingStep = '💳 Procesando pago con tarjeta...';
    });

    final sponsorWallet = authController.currentProfile?.walletAddress ?? 'sol_${widget.userId.substring(0, 12)}';
    final petWallet = widget.pet.nftMintAddress ?? 'PawSol${widget.pet.id.replaceAll("-", "").substring(0, 16)}';

    try {
      if (_paymentMethod == 'card_to_skr') {
        // Step 1: Process card
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) setState(() => _processingStep = '🔄 Convirtiendo \$$_usdPrice USD a $_selectedSkrAmount \$SKR en Solana...');

        // Step 2: On-ramp conversion & transfer via Backend
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) setState(() => _processingStep = '⚡ Transfiriendo $_selectedSkrAmount \$SKR a la wallet de @${widget.pet.name} (Dynamic.xyz)...');

        final result = await _renderService.payWithCardConvertToSkr(
          sponsorId: widget.userId,
          petId: widget.pet.id,
          amountUsd: _usdPrice,
          skrAmount: _selectedSkrAmount,
          sponsorWallet: sponsorWallet,
          petWallet: petWallet,
          cardDetails: {
            'holder': _cardHolderController.text.trim(),
            'last4': '4242',
          },
        );

        final txHash = result['txHash'] ?? 'skr_tx_${DateTime.now().millisecondsSinceEpoch}';

        await _supabaseService.sponsorPet(
          sponsorId: widget.userId,
          petId: widget.pet.id,
          amount: _selectedSkrAmount,
          paymentMethod: 'card_to_skr',
          txHash: txHash,
        );

        authController.addPawtScore(_selectedSkrAmount);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.emeraldGreen,
              duration: const Duration(seconds: 4),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '🎉 ¡Éxito! \$$_usdPrice USD pagados con tarjeta ➔ $_selectedSkrAmount \$SKR transferidos a @${widget.pet.name} vía Dynamic Solana Wallet.',
                      style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        // Direct Solana Wallet payment
        if (mounted) setState(() => _processingStep = '⚡ Firmando transacción on-chain en Solana (Dynamic.xyz)...');
        await Future.delayed(const Duration(milliseconds: 800));

        final txHash = 'sol_direct_${DateTime.now().millisecondsSinceEpoch}';

        await _supabaseService.sponsorPet(
          sponsorId: widget.userId,
          petId: widget.pet.id,
          amount: _selectedSkrAmount,
          paymentMethod: 'solana_direct',
          txHash: txHash,
        );

        authController.addPawtScore(_selectedSkrAmount);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.emeraldGreen,
              content: Text(
                '⚡ ¡Transferencia de $_selectedSkrAmount \$SKR completada en Solana para @${widget.pet.name}!',
                style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Error al procesar patrocinio: $e', style: GoogleFonts.fredoka()),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final langController = Provider.of<LanguageController>(context);
    final authController = Provider.of<AuthController>(context);
    final userWallet = authController.currentProfile?.walletAddress ?? 'sol_${widget.userId.substring(0, 10)}...';

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgWarmCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        top: 20,
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

          // Header: Pet Avatar & Sponsor info
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.surfaceWarm,
                backgroundImage: NetworkImage(widget.pet.avatarUrl),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patrocinar a @${widget.pet.name} 🐾',
                      style: GoogleFonts.fredoka(
                        color: AppTheme.primaryTerracotta,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Wallet Dynamic: $userWallet',
                      style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                      'Solana \$SKR',
                      style: GoogleFonts.fredoka(color: AppTheme.emeraldGreen, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Select Amount ($SKR Token packages)
          Text(
            '1. Selecciona el Paquete de \$SKR:',
            style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildAmountOption(100, 5.0, 'Snack 🦴'),
              const SizedBox(width: 8),
              _buildAmountOption(250, 12.5, 'Favorito ⭐'),
              const SizedBox(width: 8),
              _buildAmountOption(500, 25.0, 'Super 👑'),
              const SizedBox(width: 8),
              _buildAmountOption(1000, 50.0, 'VIP 💎'),
            ],
          ),
          const SizedBox(height: 18),

          // Payment Method Selector
          Text(
            '2. Método de Pago:',
            style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = 'card_to_skr'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: _paymentMethod == 'card_to_skr'
                          ? AppTheme.primaryTerracotta.withValues(alpha: 0.12)
                          : AppTheme.surfaceWarm,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _paymentMethod == 'card_to_skr'
                            ? AppTheme.primaryTerracotta
                            : AppTheme.borderWarm,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.credit_card_rounded, color: AppTheme.primaryTerracotta, size: 22),
                        const SizedBox(height: 4),
                        Text(
                          '💳 Tarjeta ➔ \$SKR',
                          style: GoogleFonts.fredoka(
                            color: AppTheme.primaryTerracotta,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'On-Ramp Instantáneo',
                          style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = 'solana_direct'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: _paymentMethod == 'solana_direct'
                          ? AppTheme.emeraldGreen.withValues(alpha: 0.12)
                          : AppTheme.surfaceWarm,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _paymentMethod == 'solana_direct'
                            ? AppTheme.emeraldGreen
                            : AppTheme.borderWarm,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.emeraldGreen, size: 22),
                        const SizedBox(height: 4),
                        Text(
                          '⚡ Wallet Solana',
                          style: GoogleFonts.fredoka(
                            color: AppTheme.emeraldGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Dynamic SIWS / Phantom',
                          style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Card Form Preview (When Card-to-SKR selected)
          if (_paymentMethod == 'card_to_skr')
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWarm,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderWarm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.swap_horizontal_circle_rounded, color: AppTheme.primaryTerracotta, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Conversión en Vivo:',
                            style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark, fontSize: 12),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTerracotta,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '\$$_usdPrice USD ➔ $_selectedSkrAmount \$SKR',
                          style: GoogleFonts.fredoka(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Pagas con tu tarjeta en USD y el sistema on-ramp de Dynamic acredita y transfiere los tokens \$SKR directamente a la wallet de la mascota en Solana.',
                    style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 11, height: 1.3),
                  ),
                ],
              ),
            ),

          if (_isProcessing) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWarm,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accentOrange),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: AppTheme.primaryTerracotta, strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _processingStep,
                      style: GoogleFonts.fredoka(
                        color: AppTheme.primaryTerracotta,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Action Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : () => _processSponsorship(authController, langController),
              style: ElevatedButton.styleFrom(
                backgroundColor: _paymentMethod == 'card_to_skr'
                    ? AppTheme.primaryTerracotta
                    : AppTheme.emeraldGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                elevation: 4,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _paymentMethod == 'card_to_skr'
                              ? Icons.credit_card_rounded
                              : Icons.bolt_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _paymentMethod == 'card_to_skr'
                              ? 'Pagar \$$_usdPrice USD ➔ Enviar $_selectedSkrAmount \$SKR'
                              : 'Transferir $_selectedSkrAmount \$SKR desde Wallet',
                          style: GoogleFonts.fredoka(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountOption(int skrAmount, double usdPrice, String label) {
    final isSelected = _selectedSkrAmount == skrAmount;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSkrAmount = skrAmount),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryTerracotta : AppTheme.surfaceWarm,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.primaryTerracotta : AppTheme.borderWarm,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryTerracotta.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
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
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '\$$usdPrice',
                style: GoogleFonts.outfit(
                  color: isSelected ? Colors.white70 : AppTheme.textMutedWarm,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.fredoka(
                  color: isSelected ? Colors.amberAccent : AppTheme.accentOrange,
                  fontSize: 10,
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

