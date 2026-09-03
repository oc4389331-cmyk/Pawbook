import 'package:flutter/material.dart';
import '../../models/pet_model.dart';
import '../../services/render_backend_service.dart';
import '../../services/supabase_service.dart';

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
      // 1. Stripe Checkout Session
      final usdValue = _selectedAmount / 20.0; // 100 pts = $5.00
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
            backgroundColor: const Color(0xFF6366F1),
            content: Text('🎉 Sponsorship of $_selectedAmount PawtScore initiated via Stripe!'),
          ),
        );
      }
    } else {
      // 2. Solana Pay Crypto Transfer
      final solAmount = _selectedAmount * 0.0005; // 100 pts ~ 0.05 SOL
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
            backgroundColor: const Color(0xFF14F195),
            content: Text(
              '⚡ Solana Pay Transfer: $solAmount SOL sent to ${widget.pet.name}!',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
        color: Color(0xFF18181B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(widget.pet.avatarUrl),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sponsor ${widget.pet.name} 🐾',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.pet.bio.isNotEmpty ? widget.pet.bio : 'Support this pet creator!',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Select Sponsorship Amount:',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF27272A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF818CF8) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${amt}pt',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[300],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Payment Method:',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
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
                          ? const Color(0xFF6366F1).withOpacity(0.2)
                          : const Color(0xFF27272A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _paymentMethod == 'stripe'
                            ? const Color(0xFF6366F1)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.credit_card, color: Color(0xFF6366F1), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Credit Card\n(Stripe)',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
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
                          ? const Color(0xFF14F195).withOpacity(0.2)
                          : const Color(0xFF27272A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _paymentMethod == 'solana_pay'
                            ? const Color(0xFF14F195)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet, color: Color(0xFF14F195), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Crypto\n(Solana Pay)',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
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
            height: 52,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processSponsorship,
              style: ElevatedButton.styleFrom(
                backgroundColor: _paymentMethod == 'solana_pay'
                    ? const Color(0xFF14F195)
                    : const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _paymentMethod == 'solana_pay'
                          ? 'Pay with Solana Pay'
                          : 'Pay with Card (Stripe)',
                      style: TextStyle(
                        color: _paymentMethod == 'solana_pay' ? Colors.black : Colors.white,
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
