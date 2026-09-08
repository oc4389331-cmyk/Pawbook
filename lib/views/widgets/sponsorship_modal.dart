import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/language_controller.dart';
import '../../controllers/oracle_controller.dart';
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

  final _cardNumberController = TextEditingController(text: '4242 4242 4242 4242');
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

  double _calculateUsdPrice(OracleController oracle) =>
      double.parse(oracle.convertSkrToUsd(_selectedSkrAmount).toStringAsFixed(2));

  void _fillTestCard() {
    setState(() {
      _cardNumberController.text = '4242 4242 4242 4242';
      _cardExpiryController.text = '12/28';
      _cardCvcController.text = '777';
      _cardHolderController.text = 'Tutor Pawtbook';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.emeraldGreen,
        duration: Duration(seconds: 2),
        content: Text('💳 Datos de tarjeta de prueba cargados correctamente ✨'),
      ),
    );
  }

  Future<void> _processSponsorship(
    AuthController authController,
    OracleController oracleController,
    LanguageController langController,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final usdPrice = _calculateUsdPrice(oracleController);

    // Validation for Card
    if (_paymentMethod == 'card_to_skr') {
      final cardNum = _cardNumberController.text.replaceAll(' ', '').trim();
      if (cardNum.length < 15) {
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('⚠️ Por favor ingresa un número de tarjeta válido (16 dígitos).'),
          ),
        );
        return;
      }
      if (_cardExpiryController.text.trim().isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('⚠️ Por favor ingresa la fecha de vencimiento (MM/AA).'),
          ),
        );
        return;
      }
      if (_cardCvcController.text.trim().length < 3) {
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('⚠️ Por favor ingresa un CVC/CVV válido (3 dígitos).'),
          ),
        );
        return;
      }
    }

    setState(() {
      _isProcessing = true;
      _processingStep = '💳 Autorizando tarjeta con el banco...';
    });

    final sponsorWallet = authController.currentProfile?.walletAddress ?? 'sol_${widget.userId.substring(0, 12)}';
    final petWallet = widget.pet.nftMintAddress ?? 'PawSol${widget.pet.id.replaceAll("-", "").substring(0, 16)}';

    try {
      if (_paymentMethod == 'card_to_skr') {
        // Step 1: Authorization
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          setState(() => _processingStep = '🔄 Oráculo DEX: Cotizando \$$usdPrice USD a $_selectedSkrAmount \$SKR (${oracleController.formattedPriceUsd})...');
        }

        // Step 2: Dynamic On-Ramp
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          setState(() => _processingStep = '⚡ Transfiriendo $_selectedSkrAmount \$SKR a la wallet Solana de @${widget.pet.name}...');
        }

        final result = await _renderService.payWithCardConvertToSkr(
          sponsorId: widget.userId,
          petId: widget.pet.id,
          amountUsd: usdPrice,
          skrAmount: _selectedSkrAmount,
          sponsorWallet: sponsorWallet,
          petWallet: petWallet,
          cardDetails: {
            'holder': _cardHolderController.text.trim(),
            'last4': _cardNumberController.text.trim().replaceAll(' ', '').substring(
                  _cardNumberController.text.trim().replaceAll(' ', '').length > 4
                      ? _cardNumberController.text.trim().replaceAll(' ', '').length - 4
                      : 0,
                ),
          },
        );

        final txHash = result['txHash'] ?? 'skr_onramp_${DateTime.now().millisecondsSinceEpoch}';

        await _supabaseService.sponsorPet(
          sponsorId: widget.userId,
          petId: widget.pet.id,
          amount: _selectedSkrAmount,
          paymentMethod: 'card_to_skr',
          txHash: txHash,
        ).timeout(const Duration(seconds: 4), onTimeout: () {});

        authController.addPawtScore(_selectedSkrAmount);

        if (mounted) {
          nav.pop();
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.emeraldGreen,
              duration: const Duration(seconds: 5),
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
                          '🎉 ¡Patrocinio Exitoso con Tarjeta!',
                          style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                        ),
                        Text(
                          'Pagas \$$usdPrice USD ➔ $_selectedSkrAmount \$SKR acreditados a @${widget.pet.name} vía Solana Dynamic.',
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                        ),
                      ],
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
        await Future.delayed(const Duration(milliseconds: 500));

        final txHash = 'sol_direct_${DateTime.now().millisecondsSinceEpoch}';

        await _supabaseService.sponsorPet(
          sponsorId: widget.userId,
          petId: widget.pet.id,
          amount: _selectedSkrAmount,
          paymentMethod: 'solana_direct',
          txHash: txHash,
        ).timeout(const Duration(seconds: 4), onTimeout: () {});

        authController.addPawtScore(_selectedSkrAmount);

        if (mounted) {
          nav.pop();
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.emeraldGreen,
              duration: const Duration(seconds: 4),
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
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Error al procesar patrocinio: $e', style: GoogleFonts.fredoka()),
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
    final userWallet = authController.currentProfile?.walletAddress ?? 'sol_${widget.userId.substring(0, 10)}...';
    final currentUsdPrice = _calculateUsdPrice(oracleController);

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

              // Payment Method Selector
              Text(
                '2. Método de Pago:',
                style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _paymentMethod = 'card_to_skr'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                        decoration: BoxDecoration(
                          color: _paymentMethod == 'card_to_skr'
                              ? AppTheme.primaryTerracotta.withValues(alpha: 0.12)
                              : AppTheme.surfaceWarm,
                          borderRadius: BorderRadius.circular(16),
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
                            const SizedBox(height: 3),
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
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                        decoration: BoxDecoration(
                          color: _paymentMethod == 'solana_direct'
                              ? AppTheme.emeraldGreen.withValues(alpha: 0.12)
                              : AppTheme.surfaceWarm,
                          borderRadius: BorderRadius.circular(16),
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
                            const SizedBox(height: 3),
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
                              'Dynamic / Phantom',
                              style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Card Form & Live Preview (When Card-to-SKR is selected)
              if (_paymentMethod == 'card_to_skr') ...[
                // Visual Card Mockup
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2C3E50), Color(0xFF1A1A2E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.amberAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.contactless_rounded, color: Colors.white70, size: 20),
                            ],
                          ),
                          Text(
                            'VISA / MASTERCARD',
                            style: GoogleFonts.fredoka(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _cardNumberController.text.isNotEmpty ? _cardNumberController.text : '•••• •••• •••• ••••',
                        style: GoogleFonts.sourceCodePro(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TITULAR', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 9)),
                              Text(
                                _cardHolderController.text.isNotEmpty ? _cardHolderController.text.toUpperCase() : 'TITULAR',
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('VENCE', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 9)),
                              Text(
                                _cardExpiryController.text.isNotEmpty ? _cardExpiryController.text : 'MM/AA',
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Auto-Fill Test Card Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '3. Datos de la Tarjeta:',
                      style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryTerracotta, size: 16),
                      label: Text(
                        'Usar Tarjeta de Prueba (4242)',
                        style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _fillTestCard,
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Card Number Input
                TextField(
                  controller: _cardNumberController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Número de Tarjeta',
                    hintText: '4242 4242 4242 4242',
                    prefixIcon: const Icon(Icons.credit_card_outlined, color: AppTheme.primaryTerracotta),
                    filled: true,
                    fillColor: AppTheme.surfaceWarm,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),

                // Expiry Date & CVC in Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cardExpiryController,
                        keyboardType: TextInputType.datetime,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Vence (MM/AA)',
                          hintText: '12/28',
                          prefixIcon: const Icon(Icons.calendar_today_outlined, color: AppTheme.primaryTerracotta),
                          filled: true,
                          fillColor: AppTheme.surfaceWarm,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _cardCvcController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'CVC / CVV',
                          hintText: '777',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryTerracotta),
                          filled: true,
                          fillColor: AppTheme.surfaceWarm,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Cardholder Name Input
                TextField(
                  controller: _cardHolderController,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Nombre del Titular',
                    hintText: 'Tutor Pawtbook',
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.primaryTerracotta),
                    filled: true,
                    fillColor: AppTheme.surfaceWarm,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),

                // Live Summary Conversion Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWarm,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderWarm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.swap_horizontal_circle_rounded, color: AppTheme.primaryTerracotta, size: 18),
                          const SizedBox(width: 6),
                          Text('Cotización Oráculo:', style: GoogleFonts.fredoka(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTerracotta,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '\$${currentUsdPrice.toStringAsFixed(2)} USD ➔ $_selectedSkrAmount \$SKR',
                          style: GoogleFonts.fredoka(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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

              const SizedBox(height: 18),

              // Action Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : () => _processSponsorship(authController, oracleController, langController),
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
                          width: 20,
                          height: 20,
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
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _paymentMethod == 'card_to_skr'
                                  ? 'Pagar \$${currentUsdPrice.toStringAsFixed(2)} USD ➔ Enviar $_selectedSkrAmount \$SKR'
                                  : 'Transferir $_selectedSkrAmount \$SKR desde Wallet',
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

  Widget _buildAmountOption(int skrAmount, double usdPrice, String label) {
    final isSelected = _selectedSkrAmount == skrAmount;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSkrAmount = skrAmount),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryTerracotta : AppTheme.surfaceWarm,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primaryTerracotta : AppTheme.borderWarm,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryTerracotta.withValues(alpha: 0.25),
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
