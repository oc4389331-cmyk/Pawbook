import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/oracle_controller.dart';
import '../../services/dynamic_auth_service.dart';
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
  final TextEditingController _destinationWalletController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  double _solBalance = 0.0;
  bool _isLoadingBalance = true;
  bool _isWithdrawing = false;
  String _selectedTargetWallet = 'Solflare';
  bool _showWithdrawForm = false;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _destinationWalletController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    setState(() => _isLoadingBalance = true);
    final res = await _dynamicAuthService.getSolanaBalance(widget.walletAddress);
    if (mounted) {
      setState(() {
        _solBalance = res.sol;
        _isLoadingBalance = false;
      });
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
            content: Text('✅ Dirección de $walletType conectada y completada.', style: GoogleFonts.fredoka()),
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

  Future<void> _processWithdrawal(AuthController authController, OracleController oracleController) async {
    final dest = _destinationWalletController.text.trim();
    final amountText = _amountController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (dest.isEmpty || dest.length < 32) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('⚠️ Por favor ingresa una dirección válida de Solana Base58 (ej. tu wallet de Solflare).', style: GoogleFonts.fredoka()),
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('⚠️ Ingresa un monto de SOL válido mayor a 0.', style: GoogleFonts.fredoka()),
        ),
      );
      return;
    }

    setState(() => _isWithdrawing = true);

    try {
      final res = await _dynamicAuthService.withdrawFundsToExternalWallet(
        fromWallet: widget.walletAddress,
        destinationAddress: dest,
        amountSol: amount,
        walletType: _selectedTargetWallet,
      );

      if (!res.isSuccess) {
        if (res.userCancelled) {
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.primaryTerracotta,
              content: Text('ℹ️ Cancelaste la transacción en $_selectedTargetWallet.', style: GoogleFonts.fredoka()),
            ),
          );
          return;
        }
        throw Exception(res.errorMessage ?? 'Error procesando el retiro a $dest');
      }

      _destinationWalletController.clear();
      _amountController.clear();
      setState(() => _showWithdrawForm = false);

      await _loadBalance();

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.emeraldGreen,
            duration: const Duration(seconds: 7),
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
                        '🚀 ¡Retiro a $_selectedTargetWallet enviado!',
                        style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        '$amount SOL transferidos hacia: ${dest.substring(0, 10)}...',
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
        content: Text('📋 $label copiado al portapapeles', style: GoogleFonts.fredoka()),
      ),
    );
  }

  void _openSolscan(String address) {
    final url = 'https://solscan.io/account/$address';
    if (kIsWeb) {
      try {
        js.context.callMethod('open', [url, '_blank']);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final oracle = Provider.of<OracleController>(context);
    final usdSolEstimate = (_solBalance * 155.0).toStringAsFixed(2);
    final pawtScore = auth.currentProfile?.pawtScore ?? 100;
    final skrTokenEstimate = (pawtScore * 1.0).toStringAsFixed(0);

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
              // Handle
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
                        child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.emeraldGreen, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mi Billetera Solana & Dynamic',
                            style: GoogleFonts.fredoka(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTerracotta,
                            ),
                          ),
                          Text(
                            'Cuentas Web3 y Saldo en Tiempo Real',
                            style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: _isLoadingBalance
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.emeraldGreen),
                          )
                        : const Icon(Icons.refresh_rounded, color: AppTheme.emeraldGreen),
                    tooltip: 'Actualizar Saldo',
                    onPressed: _isLoadingBalance ? null : _loadBalance,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Main Balance Card
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
                                'SOLANA MAINNET',
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
                                'Dynamic SIWS ⚡',
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

                    Text('Saldo Disponible:', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${_solBalance.toStringAsFixed(4)} SOL',
                          style: GoogleFonts.fredoka(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '≈ \$$usdSolEstimate USD',
                          style: GoogleFonts.outfit(color: const Color(0xFF14F195), fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Tokens breakdown row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt_rounded, color: Color(0xFF14F195), size: 18),
                              const SizedBox(width: 6),
                              Text('Tokens \$SKR / PawtScore:', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                          Text(
                            '$skrTokenEstimate \$SKR ($pawtScore pts)',
                            style: GoogleFonts.fredoka(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Wallet Address copy row
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.key_rounded, color: Colors.white54, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.walletAddress,
                              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            icon: const Icon(Icons.copy_rounded, color: Color(0xFF14F195), size: 16),
                            tooltip: 'Copiar Dirección',
                            onPressed: () => _copyToClipboard(widget.walletAddress, 'Dirección de Wallet'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons Row: Deposit / Withdraw
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _showWithdrawForm ? AppTheme.surfaceWarm : AppTheme.emeraldGreen,
                        foregroundColor: _showWithdrawForm ? AppTheme.primaryTerracotta : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: _showWithdrawForm ? AppTheme.borderWarm : Colors.transparent),
                        ),
                        elevation: _showWithdrawForm ? 0 : 2,
                      ),
                      icon: Icon(_showWithdrawForm ? Icons.visibility_rounded : Icons.send_rounded, size: 18),
                      label: Text(
                        _showWithdrawForm ? 'Ver Resumen' : '💸 Retirar a Solflare',
                        style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () {
                        setState(() => _showWithdrawForm = !_showWithdrawForm);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceWarm,
                      foregroundColor: AppTheme.primaryTerracotta,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppTheme.borderWarm),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.qr_code_rounded, size: 18),
                    label: Text('Recibir SOL', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () {
                      _copyToClipboard(widget.walletAddress, 'Dirección pública para recibir SOL');
                    },
                  ),
                ],
              ),

              // Withdraw Section
              if (_showWithdrawForm) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWarm,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.4)),
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
                                'Retirar Fondos a Wallet Externa',
                                style: GoogleFonts.fredoka(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.emeraldGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                            child: Text('Red Solana', style: GoogleFonts.outfit(color: AppTheme.emeraldGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Select Destination Wallet Type Quick Options
                      Row(
                        children: [
                          _buildTargetWalletChip('Solflare', Icons.wb_sunny_rounded, const Color(0xFFFC8C03)),
                          const SizedBox(width: 8),
                          _buildTargetWalletChip('Phantom', Icons.shield_rounded, const Color(0xFFAB9FF2)),
                          const SizedBox(width: 8),
                          _buildTargetWalletChip('Otra', Icons.account_balance_wallet_outlined, AppTheme.textMutedWarm),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Auto-detect wallet button
                      if (_selectedTargetWallet != 'Otra')
                        InkWell(
                          onTap: () => _detectExternalWallet(_selectedTargetWallet),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.bgWarmCream,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderWarm),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded, color: AppTheme.emeraldGreen, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '⚡ Detectar y rellenar mi $_selectedTargetWallet',
                                  style: GoogleFonts.fredoka(color: AppTheme.emeraldGreen, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Destination Address Input
                      Text('Dirección de destino de Solana:', style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _destinationWalletController,
                        style: GoogleFonts.outfit(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Pega tu dirección pública de Solflare (Base58)...',
                          hintStyle: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12),
                          filled: true,
                          fillColor: AppTheme.bgWarmCream,
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

                      // Amount Input
                      Text('Monto a retirar en SOL:', style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.fredoka(fontSize: 15, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          filled: true,
                          fillColor: AppTheme.bgWarmCream,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                          suffixIcon: TextButton(
                            onPressed: () {
                              final maxAmount = (_solBalance > 0.001) ? (_solBalance - 0.0005) : _solBalance;
                              _amountController.text = maxAmount.toStringAsFixed(4);
                            },
                            child: Text('MÁX', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.emeraldGreen)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Submit Withdraw Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTerracotta,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _isWithdrawing ? null : () => _processWithdrawal(auth, oracle),
                          child: _isWithdrawing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('Confirmar Retiro a $_selectedTargetWallet 🚀', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
          color: isSelected ? color.withValues(alpha: 0.2) : AppTheme.bgWarmCream,
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
