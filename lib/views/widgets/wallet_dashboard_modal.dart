import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/language_controller.dart';
import '../../controllers/oracle_controller.dart';
import '../../models/sponsorship_model.dart';
import '../../models/withdrawal_model.dart';
import '../../services/dynamic_auth_service.dart';
import '../../services/supabase_service.dart';
import '../../services/url_launcher_service.dart';
import '../../theme/app_theme.dart';

class WalletDashboardModal extends StatefulWidget {
  final String walletAddress;
  final String userId;

  const WalletDashboardModal({
    super.key,
    required this.walletAddress,
    required this.userId,
  });

  static Future<void> show(BuildContext context, {required String walletAddress, required String userId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WalletDashboardModal(walletAddress: walletAddress, userId: userId),
    );
  }

  @override
  State<WalletDashboardModal> createState() => _WalletDashboardModalState();
}

class _WalletDashboardModalState extends State<WalletDashboardModal> {
  final DynamicAuthService _dynamicAuthService = DynamicAuthService();
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _destinationWalletController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  List<SponsorshipModel> _sponsorships = [];
  List<WithdrawalModel> _withdrawals = [];
  int _unclaimedSkr = 0;
  int _totalLifetimeSkr = 0;
  int _totalWithdrawnSkr = 0;

  bool _isLoading = true;
  bool _isWithdrawing = false;
  String _selectedTargetWallet = 'Seeker';
  bool _showWithdrawForm = false;

  @override
  void initState() {
    super.initState();
    _destinationWalletController.text = widget.walletAddress;
    _loadDashboardData();
  }

  @override
  void dispose() {
    _destinationWalletController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final spns = await _supabaseService.getSponsorshipsForOwner(widget.userId);
      final wdrs = await _supabaseService.getWithdrawalsForOwner(widget.userId);

      int unclaimed = 0;
      int lifetime = 0;
      for (final s in spns) {
        lifetime += s.netAmount;
        if (!s.isClaimed && s.status != 'withdrawn') {
          unclaimed += s.netAmount;
        }
      }

      int withdrawn = 0;
      for (final w in wdrs) {
        withdrawn += w.amountSkr;
      }

      if (mounted) {
        setState(() {
          _sponsorships = spns;
          _withdrawals = wdrs;
          _unclaimedSkr = unclaimed;
          _totalLifetimeSkr = lifetime;
          _totalWithdrawnSkr = withdrawn;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading wallet dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _detectExternalWallet(String walletType) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await _dynamicAuthService.connectSpecificWallet(walletType);
      if (res.isSuccess && res.walletAddress != null) {
        setState(() {
          _destinationWalletController.text = res.walletAddress!;
        });
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.emeraldGreen,
            content: Text('✅ $walletType: ${res.walletAddress!.substring(0, 8)}...', style: GoogleFonts.fredoka()),
          ),
        );
      } else if (res.errorMessage != null) {
        messenger.showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('⚠️ ${res.errorMessage}', style: GoogleFonts.fredoka())),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('⚠️ $e', style: GoogleFonts.fredoka())),
      );
    }
  }

  Future<void> _processWithdrawal(
    AuthController authController,
    OracleController oracleController,
    LanguageController langController,
  ) async {
    final dest = _destinationWalletController.text.trim();
    final amountText = _amountController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (_unclaimedSkr <= 0) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryTerracotta,
          content: Text('🔒 No tienes saldo de patrocinios acumulado para retirar.', style: GoogleFonts.fredoka()),
        ),
      );
      return;
    }

    if (dest.isEmpty || dest.length < 32) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(langController.t('enterValidSolanaAddress'), style: GoogleFonts.fredoka()),
        ),
      );
      return;
    }

    final amountSkr = int.tryParse(amountText);
    if (amountSkr == null || amountSkr <= 0 || amountSkr > _unclaimedSkr) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('⚠️ Ingresa un monto de \$SKR válido (máximo: $_unclaimedSkr \$SKR)', style: GoogleFonts.fredoka()),
        ),
      );
      return;
    }

    setState(() => _isWithdrawing = true);

    try {
      final amountSol = oracleController.convertSkrToSol(amountSkr);
      final amountUsd = double.parse(oracleController.convertSkrToUsd(amountSkr).toStringAsFixed(2));

      // Execute transfer via Solana Wallet Adapter
      final txResult = await _dynamicAuthService.sendWalletTransfer(
        walletType: _selectedTargetWallet,
        recipientAddress: dest,
        tokenType: 'SKR',
        skrAmount: amountSkr.toDouble(),
        solAmount: amountSol,
      );

      if (!txResult.isSuccess && txResult.userCancelled) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.primaryTerracotta,
              content: Text(langController.t('txCancelledMsg'), style: GoogleFonts.fredoka()),
            ),
          );
        }
        return;
      }

      final txHash = txResult.signature ?? 'wdr_sol_${DateTime.now().millisecondsSinceEpoch}';

      // Register withdrawal in database and lock claimed sponsorships
      await _supabaseService.processOwnerWithdrawal(
        userId: widget.userId,
        destinationWallet: dest,
        amountSkr: amountSkr,
        amountSol: amountSol,
        amountUsd: amountUsd,
        txHash: txHash,
      );

      _amountController.clear();
      setState(() => _showWithdrawForm = false);

      await _loadDashboardData();

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.emeraldGreen,
            duration: const Duration(seconds: 8),
            action: (txResult.solscanUrl != null)
                ? SnackBarAction(
                    label: 'SOLSCAN',
                    textColor: Colors.white,
                    onPressed: () {
                      try {
                        UrlLauncherService.instance.openUrl(txResult.solscanUrl!);
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
                        '🚀 $amountSkr \$SKR transferidos con éxito',
                        style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Destino: ${dest.substring(0, 8)}...${dest.substring(dest.length - 4)}',
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
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('⚠️ $e', style: GoogleFonts.fredoka())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isWithdrawing = false);
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.surfaceDark,
        duration: const Duration(seconds: 2),
        content: Text('📋 $label', style: GoogleFonts.fredoka()),
      ),
    );
  }

  void _openSolscan(String address) {
    final url = 'https://solscan.io/account/$address';
    try {
      UrlLauncherService.instance.openUrl(url);
    } catch (_) {}
  }

  void _openSolscanTx(String txHash) {
    final url = 'https://solscan.io/tx/$txHash';
    try {
      UrlLauncherService.instance.openUrl(url);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final oracle = Provider.of<OracleController>(context);
    final langController = Provider.of<LanguageController>(context);

    final claimableUsd = double.parse(oracle.convertSkrToUsd(_unclaimedSkr).toStringAsFixed(2));
    final claimableSol = oracle.convertSkrToSol(_unclaimedSkr);
    final pawtScore = auth.currentProfile?.pawtScore ?? 100;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
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
              // Handle superior
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

              // Encabezado
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
                        child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.emeraldGreen, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mi Billetera & Patrocinios',
                            style: GoogleFonts.fredoka(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTerracotta,
                            ),
                          ),
                          Text(
                            'Ganancias exclusivamente por patrocinios recibidos',
                            style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.emeraldGreen),
                          )
                        : const Icon(Icons.refresh_rounded, color: AppTheme.emeraldGreen),
                    tooltip: 'Actualizar',
                    onPressed: _isLoading ? null : _loadDashboardData,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- TARJETA PRINCIPAL: GANANCIAS POR PATROCINIOS ---
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14F195).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF14F195).withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'PATROCINIOS VERIFICADOS',
                                style: GoogleFonts.fredoka(color: const Color(0xFF14F195), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9945FF).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF9945FF).withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'Solana Ledger ⚡',
                                style: GoogleFonts.fredoka(color: const Color(0xFF9945FF), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => _openSolscan(widget.walletAddress),
                          child: Row(
                            children: [
                              Text('Solscan', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11)),
                              const SizedBox(width: 4),
                              const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 13),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text('Saldo de Patrocinios para Retirar:', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$_unclaimedSkr \$SKR',
                          style: GoogleFonts.fredoka(
                            color: _unclaimedSkr > 0 ? const Color(0xFF14F195) : Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '≈ \$$claimableUsd USD • ${claimableSol.toStringAsFixed(4)} SOL',
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Estado del Saldo
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _unclaimedSkr > 0
                            ? const Color(0xFF14F195).withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _unclaimedSkr > 0
                              ? const Color(0xFF14F195).withValues(alpha: 0.3)
                              : Colors.white12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _unclaimedSkr > 0 ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                            color: _unclaimedSkr > 0 ? const Color(0xFF14F195) : Colors.white54,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _unclaimedSkr > 0
                                  ? '✓ Fondos listos para transferir a tu wallet.'
                                  : '🔒 Sin patrocinios pendientes de cobro.',
                              style: GoogleFonts.outfit(
                                color: _unclaimedSkr > 0 ? const Color(0xFF14F195) : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Desglose de Métricas de Patrocinios
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Recaudado', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text('$_totalLifetimeSkr \$SKR', style: GoogleFonts.fredoka(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(width: 1, height: 24, color: Colors.white12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Retirado', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text('$_totalWithdrawnSkr \$SKR', style: GoogleFonts.fredoka(color: const Color(0xFFFC8C03), fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(width: 1, height: 24, color: Colors.white12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PawtScore', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text('$pawtScore pts', style: GoogleFonts.fredoka(color: const Color(0xFF9945FF), fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // --- TARJETA DE BILLETERA CONECTADA (INFORMACIÓN DE VINCULACIÓN) ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderWarm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_rounded, color: AppTheme.solanaPurple, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Billetera Conectada de Retiro',
                          style: GoogleFonts.fredoka(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.walletAddress,
                            style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          icon: const Icon(Icons.copy_rounded, color: AppTheme.primaryTerracotta, size: 16),
                          tooltip: 'Copiar',
                          onPressed: () => _copyToClipboard(widget.walletAddress, 'Billetera copiada al portapapeles'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '📌 Los fondos retirables mostrados arriba corresponden exclusivamente a los patrocinios recibidos por tus mascotas registradas.',
                      style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 11, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // --- BOTÓN PRINCIPAL DE RETIRO ---
              if (_unclaimedSkr <= 0) ...[
                // Botón deshabilitado cuando no hay patrocinios para retirar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, color: Colors.grey.shade600, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '🔒 Sin patrocinios pendientes de retiro',
                        style: GoogleFonts.fredoka(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'No tienes patrocinios acumulados. Cuando otros usuarios apoyen a tus mascotas, las transacciones quedarán registradas aquí para tu cobro.',
                    style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 11, height: 1.3),
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else ...[
                // Botón activo cuando sí hay patrocinios acumulados
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showWithdrawForm ? AppTheme.pastelPeach : AppTheme.emeraldGreen,
                      foregroundColor: _showWithdrawForm ? AppTheme.brandCoral : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: _showWithdrawForm ? AppTheme.brandCoral.withValues(alpha: 0.3) : Colors.transparent),
                      ),
                      elevation: _showWithdrawForm ? 0 : 2,
                    ),
                    icon: Icon(_showWithdrawForm ? Icons.visibility_rounded : Icons.file_upload_outlined, size: 20),
                    label: Text(
                      _showWithdrawForm ? 'Ocultar Formulario' : '💸 Retirar Patrocinios ($_unclaimedSkr \$SKR)',
                      style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: () {
                      setState(() {
                        _showWithdrawForm = !_showWithdrawForm;
                        if (_showWithdrawForm && _amountController.text.isEmpty) {
                          _amountController.text = _unclaimedSkr.toString();
                        }
                      });
                    },
                  ),
                ),
              ],

              // --- FORMULARIO DE RETIRO DE PATROCINIOS ---
              if (_showWithdrawForm && _unclaimedSkr > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.pastelPeach.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.brandCoral.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.file_upload_outlined, color: AppTheme.primaryTerracotta, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Retirar Patrocinios Acumulados',
                                style: GoogleFonts.fredoka(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppTheme.emeraldGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                            child: Text('Solana MWA', style: GoogleFonts.outfit(color: AppTheme.emeraldGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Selector de Billetera de Destino
                      Row(
                        children: [
                          _buildTargetWalletChip('Seeker', Icons.phone_android_rounded, Colors.deepPurple),
                          const SizedBox(width: 8),
                          _buildTargetWalletChip('Solflare', Icons.wb_sunny_rounded, const Color(0xFFFC8C03)),
                          const SizedBox(width: 8),
                          _buildTargetWalletChip('Phantom', Icons.shield_rounded, const Color(0xFFAB9FF2)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Dirección de Destino
                      Text('Dirección de Destino en Solana:', style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _destinationWalletController,
                        style: GoogleFonts.outfit(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Dirección Base58 de Solana...',
                          hintStyle: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.paste_rounded, size: 18, color: AppTheme.primaryTerracotta),
                            onPressed: () async {
                              final data = await Clipboard.getData('text/plain');
                              if (data?.text != null) {
                                _destinationWalletController.text = data!.text!.trim();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Monto a Retirar ($SKR)
                      Text('Monto a Retirar en \$SKR (Máximo: $_unclaimedSkr):', style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: '0',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                          suffixIcon: TextButton(
                            onPressed: () {
                              _amountController.text = _unclaimedSkr.toString();
                            },
                            child: Text('MÁX', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.emeraldGreen)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Botón Confirmar
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTerracotta,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _isWithdrawing ? null : () => _processWithdrawal(auth, oracle, langController),
                          child: _isWithdrawing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('Confirmar Retiro de Patrocinios 🚀', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // --- REGISTRO DE TRANSACCIONES GUARDADAS (TX HASHES) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryTerracotta, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Registro de Patrocinios (TX)',
                        style: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppTheme.pastelPeach, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '${_sponsorships.length} recibidas',
                      style: GoogleFonts.fredoka(fontSize: 11, color: AppTheme.brandCoral, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_sponsorships.isEmpty && _withdrawals.isEmpty) ...[
                // Estado vacío elegante
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderWarm),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppTheme.pastelVanilla, shape: BoxShape.circle),
                        child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryTerracotta, size: 30),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Sin transacciones registradas aún',
                        style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cada patrocinio que tus mascotas reciban quedará guardado aquí con su hash de Solana y enlace directo a Solscan.',
                        style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Listado de Patrocinios Recibidos
                ..._sponsorships.map((s) {
                  final dateFormatted = '${s.createdAt.day}/${s.createdAt.month}/${s.createdAt.year}';
                  final txHash = s.txHash;
                  final isPending = !s.isClaimed && s.status != 'withdrawn';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
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
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF14F195).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.favorite_rounded, color: AppTheme.brandCoral, size: 16),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Patrocinio Recibido',
                                  style: GoogleFonts.fredoka(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isPending ? const Color(0xFF14F195).withValues(alpha: 0.15) : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isPending ? '✓ Pendiente de retiro' : 'Retirado',
                                style: GoogleFonts.outfit(
                                  color: isPending ? AppTheme.emeraldGreen : Colors.grey.shade600,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '+${s.netAmount} \$SKR (Neto)',
                              style: GoogleFonts.fredoka(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.emeraldGreen),
                            ),
                            Text(
                              dateFormatted,
                              style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMutedWarm),
                            ),
                          ],
                        ),
                        if (txHash != null && txHash.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _openSolscanTx(txHash),
                            child: Row(
                              children: [
                                const Icon(Icons.link_rounded, size: 14, color: AppTheme.solanaPurple),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'TX: ${txHash.length > 24 ? "${txHash.substring(0, 12)}...${txHash.substring(txHash.length - 8)}" : txHash}',
                                    style: GoogleFonts.outfit(color: AppTheme.solanaPurple, fontSize: 11, decoration: TextDecoration.underline),
                                  ),
                                ),
                                const Icon(Icons.open_in_new_rounded, size: 12, color: AppTheme.solanaPurple),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                // Listado de Retiros Realizados
                ..._withdrawals.map((w) {
                  final dateFormatted = '${w.createdAt.day}/${w.createdAt.month}/${w.createdAt.year}';
                  final txHash = w.txHash;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWarm,
                      borderRadius: BorderRadius.circular(18),
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
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_upward_rounded, color: Colors.orange, size: 16),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Retiro Procesado',
                                  style: GoogleFonts.fredoka(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppTheme.pastelPeach, borderRadius: BorderRadius.circular(8)),
                              child: Text('Completado', style: GoogleFonts.outfit(color: AppTheme.brandCoral, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '-${w.amountSkr} \$SKR',
                              style: GoogleFonts.fredoka(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
                            ),
                            Text(
                              dateFormatted,
                              style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMutedWarm),
                            ),
                          ],
                        ),
                        if (txHash != null && txHash.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _openSolscanTx(txHash),
                            child: Row(
                              children: [
                                const Icon(Icons.link_rounded, size: 14, color: AppTheme.solanaPurple),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'TX: ${txHash.length > 24 ? "${txHash.substring(0, 12)}...${txHash.substring(txHash.length - 8)}" : txHash}',
                                    style: GoogleFonts.outfit(color: AppTheme.solanaPurple, fontSize: 11, decoration: TextDecoration.underline),
                                  ),
                                ),
                                const Icon(Icons.open_in_new_rounded, size: 12, color: AppTheme.solanaPurple),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetWalletChip(String name, IconData icon, Color color) {
    final isSelected = _selectedTargetWallet == name;
    return InkWell(
      onTap: () {
        setState(() => _selectedTargetWallet = name);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : AppTheme.borderWarm, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              name,
              style: GoogleFonts.fredoka(
                color: isSelected ? color : AppTheme.textPrimaryDark,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
