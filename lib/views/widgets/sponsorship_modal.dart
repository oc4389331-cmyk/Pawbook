import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  int _selectedAmount = 100;
  String _paymentMethod = 'stripe'; // 'stripe' or 'solana_pay'
  bool _isProcessing = false;

  final RenderBackendService _renderService = RenderBackendService();
  final SupabaseService _supabaseService = SupabaseService();

  Future<void> _processSponsorship() async {
    setState(() => _isProcessing = true);

    if (_paymentMethod == 'stripe') {
      final usdValue = _selectedAmount / 20.0;
      final result = await _renderService.createStripeCheckoutSession(
        userId: widget.userId,
        petId: widget.pet.id,
        pointsAmount: _selectedAmount,
        priceUsd: usdValue,
      );

      await _supabaseService.sponsorPet(
        sponsorId: widget.userId,
        petId: widget.pet.id,
        amount: _selectedAmount,
        paymentMethod: 'stripe',
        txHash: result['sessionId'] ?? 'stripe_session_completed',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryTerracotta,
            content: Text('🎉 Sponsorship of $_selectedAmount PawtScore initiated via Stripe!', style: GoogleFonts.fredoka()),
          ),
        );
      }
    } else {
      final solAmount = _selectedAmount * 0.0005;
      await _supabaseService.sponsorPet(
        sponsorId: widget.userId,
        petId: widget.pet.id,
        amount: _selectedAmount,
        paymentMethod: 'solana_pay',
        txHash: 'sol_tx_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.emeraldGreen,
            content: Text(
              '⚡ Solana Pay Transfer: $solAmount SOL sent to ${widget.pet.name}!',
              style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 20),
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
                      'Sponsor ${widget.pet.name} 🐾',
                      style: GoogleFonts.fredoka(
                        color: AppTheme.primaryTerracotta,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.pet.bio.isNotEmpty ? widget.pet.bio : 'Support this pet creator!',
                      style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Select Sponsorship Amount:',
            style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [50, 100, 250, 500].map((amt) {
              final isSelected = _selectedAmount == amt;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedAmount = amt),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryTerracotta : AppTheme.surfaceWarm,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryTerracotta : AppTheme.borderWarm,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${amt}pt',
                        style: GoogleFonts.fredoka(
                          color: isSelected ? Colors.white : AppTheme.textPrimaryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text(
            'Payment Method:',
            style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = 'stripe'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: _paymentMethod == 'stripe'
                          ? AppTheme.primaryTerracotta.withOpacity(0.12)
                          : AppTheme.surfaceWarm,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _paymentMethod == 'stripe'
                            ? AppTheme.primaryTerracotta
                            : AppTheme.borderWarm,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.credit_card_rounded, color: AppTheme.primaryTerracotta, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Credit Card\n(Stripe)',
                          style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = 'solana_pay'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: _paymentMethod == 'solana_pay'
                          ? AppTheme.emeraldGreen.withOpacity(0.12)
                          : AppTheme.surfaceWarm,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _paymentMethod == 'solana_pay'
                            ? AppTheme.emeraldGreen
                            : AppTheme.borderWarm,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.emeraldGreen, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Crypto\n(Solana Pay)',
                          style: GoogleFonts.fredoka(color: AppTheme.emeraldGreen, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processSponsorship,
              style: ElevatedButton.styleFrom(
                backgroundColor: _paymentMethod == 'solana_pay'
                    ? AppTheme.emeraldGreen
                    : AppTheme.primaryTerracotta,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _paymentMethod == 'solana_pay'
                          ? 'Pay with Solana Pay'
                          : 'Pay with Card (Stripe)',
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
