import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/oracle_controller.dart';
import '../../theme/app_theme.dart';

class LiveOracleTicker extends StatelessWidget {
  final bool compact;

  const LiveOracleTicker({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final oracleController = Provider.of<OracleController>(context);

    return GestureDetector(
      onTap: () => _showOracleDetailsModal(context, oracleController),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.8), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.emeraldGreen.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsating Green Beacon
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF10B981),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '1 \$SKR = ',
              style: GoogleFonts.fredoka(color: Colors.white70, fontSize: compact ? 11 : 12, fontWeight: FontWeight.w600),
            ),
            Text(
              oracleController.formattedPriceUsd,
              style: GoogleFonts.fredoka(
                color: const Color(0xFF10B981),
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFF065F46),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                oracleController.formattedChange,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOracleDetailsModal(BuildContext context, OracleController oracle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.bgWarmCream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                    color: AppTheme.borderWarm,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt_rounded, color: AppTheme.emeraldGreen, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔮 Oráculo Solana \$SKR en Vivo',
                          style: GoogleFonts.fredoka(
                            color: AppTheme.primaryTerracotta,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Alimentado por ${oracle.oracleProvider}',
                          style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWarm,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderWarm),
                ),
                child: Column(
                  children: [
                    _buildRow('Precio en USD:', oracle.formattedPriceUsd, isHighlight: true),
                    const Divider(height: 16),
                    _buildRow('Precio en SOL:', '${oracle.priceSol.toStringAsFixed(6)} SOL'),
                    const Divider(height: 16),
                    _buildRow('Variación 24h:', oracle.formattedChange, isPositive: oracle.change24h >= 0),
                    const Divider(height: 16),
                    _buildRow('Actualización:', '${DateTime.now().difference(oracle.lastUpdated).inSeconds}s atrás (Auto 10s)'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTerracotta,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: Text('Actualizar Oráculo Ahora', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    oracle.fetchLiveSkrPrice();
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(String label, String value, {bool isHighlight = false, bool? isPositive}) {
    Color valColor = AppTheme.textPrimaryDark;
    if (isHighlight) valColor = AppTheme.emeraldGreen;
    if (isPositive != null) valColor = isPositive ? const Color(0xFF10B981) : Colors.redAccent;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 13)),
        Text(
          value,
          style: GoogleFonts.fredoka(
            color: valColor,
            fontWeight: FontWeight.bold,
            fontSize: isHighlight ? 16 : 14,
          ),
        ),
      ],
    );
  }
}
