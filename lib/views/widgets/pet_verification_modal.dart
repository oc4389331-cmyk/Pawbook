import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/oracle_controller.dart';
import '../../controllers/language_controller.dart';
import '../../models/pet_model.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class PetVerificationModal extends StatefulWidget {
  final PetModel pet;
  final Function(PetModel updatedPet)? onVerified;

  const PetVerificationModal({
    super.key,
    required this.pet,
    this.onVerified,
  });

  static Future<void> show(
    BuildContext context, {
    required PetModel pet,
    Function(PetModel updatedPet)? onVerified,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PetVerificationModal(
        pet: pet,
        onVerified: onVerified,
      ),
    );
  }

  @override
  State<PetVerificationModal> createState() => _PetVerificationModalState();
}

class _PetVerificationModalState extends State<PetVerificationModal> {
  bool _isProcessing = false;
  String _selectedMethod = 'solana'; // 'solana', 'skr', 'card'

  final SupabaseService _supabaseService = SupabaseService();

  Future<void> _handlePayment(
    BuildContext context,
    AuthController authController,
    OracleController oracleController,
    LanguageController langController,
  ) async {
    setState(() => _isProcessing = true);

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      final double usdAmount = 10.00;
      final double solAmount = oracleController.convertUsdToSol(usdAmount);
      final num skrAmount = oracleController.convertUsdToSkr(usdAmount);

      // Simulate on-chain / payment gateway delay
      await Future.delayed(const Duration(milliseconds: 1400));

      final updatedPet = await _supabaseService.verifyPetBadge(
        widget.pet.id,
        paymentMethod: _selectedMethod,
        usdAmount: usdAmount,
        solAmount: solAmount,
        skrAmount: skrAmount,
        txHash: 'tx_verif_${widget.pet.id.substring(0, 6)}_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        nav.pop();

        if (updatedPet != null && widget.onVerified != null) {
          widget.onVerified!(updatedPet);
        }

        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0284C7),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '🌟 ¡Felicidades! ${widget.pet.name} ahora tiene su estrellita azul de Cuenta Verificada Oficial.',
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              '❌ No se pudo completar la verificación: $e',
              style: GoogleFonts.fredoka(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final oracle = Provider.of<OracleController>(context);
    final auth = Provider.of<AuthController>(context);
    final lang = Provider.of<LanguageController>(context);

    const double usdAmount = 10.00;
    final double solAmount = oracle.convertUsdToSol(usdAmount);
    final int skrAmount = oracle.convertUsdToSkr(usdAmount).toInt();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFFBFBFB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 6),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_rounded, color: Color(0xFF0284C7), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Verificación Oficial',
                      style: GoogleFonts.fredoka(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryDark,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  color: AppTheme.textMutedWarm,
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  // Blue Star Badge Hero Graphic
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFE0F2FE),
                          Color(0xFFBAE6FD),
                          Color(0xFFF0F9FF),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFF7DD3FC), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            Container(
                              width: 70,
                              height: 70,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF0284C7),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF0284C7),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.pet.name,
                              style: GoogleFonts.fredoka(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryDark,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, color: Color(0xFF0284C7), size: 22),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Insignia de Cuenta Verificada Oficial 🌟',
                          style: GoogleFonts.fredoka(
                            fontSize: 14,
                            color: const Color(0xFF0369A1),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Real-time Dynamic Pricing Card (Oráculo Solana DEX)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: AppTheme.softCardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'VALOR DE VERIFICACIÓN',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textMutedWarm,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.emeraldGreen.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.emeraldGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Oráculo en vivo',
                                    style: GoogleFonts.fredoka(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.emeraldGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Main $10 USD Price
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '\$10.00',
                              style: GoogleFonts.fredoka(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryDark,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'USD (Pago único)',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMutedWarm,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 12),

                        // Real-time Conversions Row (SOL & SKR)
                        Row(
                          children: [
                            // Solana Conversion
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9945FF).withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF9945FF).withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF9945FF)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Equivalente SOL',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF7E22CE),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '≈ ${solAmount.toStringAsFixed(4)} SOL',
                                      style: GoogleFonts.fredoka(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // SKR Token Conversion
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.brandCoral.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.brandCoral.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.pets_rounded, size: 14, color: AppTheme.brandCoral),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Equivalente \$SKR',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.brandCoral,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '≈ $skrAmount SKR',
                                      style: GoogleFonts.fredoka(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            '1 SOL ≈ ${oracle.formattedSolPriceUsd}  •  1 SKR ≈ ${oracle.formattedPriceUsd}',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppTheme.textMutedWarm,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Benefits Checklist
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: AppTheme.softCardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BENEFICIOS DE LA VERIFICACIÓN',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMutedWarm,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildBenefitItem(
                          Icons.verified_rounded,
                          const Color(0xFF0284C7),
                          'Estrellita azul oficial permanente',
                          'Visible en tu perfil, en el feed global y en todos tus comentarios.',
                        ),
                        const SizedBox(height: 10),
                        _buildBenefitItem(
                          Icons.rocket_launch_rounded,
                          const Color(0xFF9945FF),
                          'Mayor prioridad en el Feed y Explorador',
                          'Tus videos reciben hasta un 300% más de visibilidad en el algoritmo.',
                        ),
                        const SizedBox(height: 10),
                        _buildBenefitItem(
                          Icons.token_rounded,
                          AppTheme.accentOrange,
                          'Certificación NFT en la red Solana',
                          'Acreditación oficial grabada de forma inmutable en la blockchain.',
                        ),
                        const SizedBox(height: 10),
                        _buildBenefitItem(
                          Icons.security_rounded,
                          AppTheme.emeraldGreen,
                          'Protección anti-suplantación',
                          'Garantiza que nadie pueda crear un perfil duplicado de ${widget.pet.name}.',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Payment Method Selector
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: AppTheme.softCardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ELIGE MÉTODO DE PAGO',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMutedWarm,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildPaymentTile(
                          id: 'solana',
                          icon: Icons.account_balance_wallet_rounded,
                          iconColor: const Color(0xFF9945FF),
                          title: 'Solana Wallet (Phantom / Solflare)',
                          subtitle: 'Pagar ≈ ${solAmount.toStringAsFixed(4)} SOL',
                          selected: _selectedMethod == 'solana',
                          onTap: () => setState(() => _selectedMethod = 'solana'),
                        ),
                        const SizedBox(height: 8),
                        _buildPaymentTile(
                          id: 'skr',
                          icon: Icons.pets_rounded,
                          iconColor: AppTheme.brandCoral,
                          title: 'Saldo en Tokens \$SKR',
                          subtitle: 'Pagar ≈ $skrAmount SKR',
                          selected: _selectedMethod == 'skr',
                          onTap: () => setState(() => _selectedMethod = 'skr'),
                        ),
                        const SizedBox(height: 8),
                        _buildPaymentTile(
                          id: 'card',
                          icon: Icons.credit_card_rounded,
                          iconColor: const Color(0xFF0284C7),
                          title: 'Tarjeta de Crédito / Débito (Stripe)',
                          subtitle: 'Pagar \$10.00 USD exactos',
                          selected: _selectedMethod == 'card',
                          onTap: () => setState(() => _selectedMethod = 'card'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Confirm & Verify Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                      onPressed: _isProcessing ? null : () => _handlePayment(context, auth, oracle, lang),
                      child: _isProcessing
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Activando certificación...',
                                  style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Verificar a ${widget.pet.name} por \$10 USD',
                                  style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, Color color, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.fredoka(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: AppTheme.textMutedWarm,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentTile({
    required String id,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.fredoka(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppTheme.textMutedWarm,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? const Color(0xFF0284C7) : Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
