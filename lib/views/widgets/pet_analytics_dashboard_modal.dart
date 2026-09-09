import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/pet_model.dart';
import '../../models/pet_analytics_model.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class PetAnalyticsDashboardModal extends StatefulWidget {
  final PetModel pet;

  const PetAnalyticsDashboardModal({
    super.key,
    required this.pet,
  });

  static Future<void> show(BuildContext context, {required PetModel pet}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PetAnalyticsDashboardModal(pet: pet),
    );
  }

  @override
  State<PetAnalyticsDashboardModal> createState() => _PetAnalyticsDashboardModalState();
}

class _PetAnalyticsDashboardModalState extends State<PetAnalyticsDashboardModal> {
  final SupabaseService _supabaseService = SupabaseService();
  late Future<PetAnalyticsModel> _analyticsFuture;
  int _selectedChartTab = 0; // 0: Vistas, 1: Me Gustas, 2: Comentarios, 3: Tiempo de Vista
  String _selectedRange = '7D'; // '7D', '30D', 'Todo'

  @override
  void initState() {
    super.initState();
    _analyticsFuture = _supabaseService.getPetAnalytics(widget.pet.id, petName: widget.pet.name);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.88,
      decoration: const BoxDecoration(
        color: AppTheme.bgWarmCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: AppTheme.borderWarm,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 12),

          // Modal Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.cardWarm,
                  backgroundImage: NetworkImage(
                    widget.pet.avatarUrl.isNotEmpty
                        ? widget.pet.avatarUrl
                        : 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=200',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Métricas de @${widget.pet.name}',
                              style: GoogleFonts.fredoka(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryTerracotta,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.emeraldGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'En Vivo',
                              style: GoogleFonts.fredoka(
                                color: AppTheme.emeraldGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Rendimiento, Retención (>=15s) e Interacción',
                        style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textMutedWarm),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.borderWarm, height: 16),

          // Main Scrollable Content
          Expanded(
            child: FutureBuilder<PetAnalyticsModel>(
              future: _analyticsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryTerracotta),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return Center(
                    child: Text(
                      'No se pudieron cargar las estadísticas.',
                      style: GoogleFonts.outfit(color: AppTheme.textMutedWarm),
                    ),
                  );
                }

                final data = snapshot.data!;
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time Range Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '📊 Resumen General',
                            style: GoogleFonts.fredoka(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryDark,
                            ),
                          ),
                          Row(
                            children: ['7D', '30D', 'Todo'].map((range) {
                              final isSel = _selectedRange == range;
                              return Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: ChoiceChip(
                                  label: Text(
                                    range,
                                    style: GoogleFonts.fredoka(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSel ? Colors.white : AppTheme.textPrimaryDark,
                                    ),
                                  ),
                                  selected: isSel,
                                  selectedColor: AppTheme.primaryTerracotta,
                                  backgroundColor: AppTheme.surfaceWarm,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  onSelected: (_) => setState(() => _selectedRange = range),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 4 KPI Cards Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildKpiCard(
                              title: 'Vistas (>=15s)',
                              value: '${data.totalViews}',
                              subtitle: 'Calificadas',
                              icon: Icons.remove_red_eye_rounded,
                              color: const Color(0xFF3B82F6),
                              badge: 'Regla 15s',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildKpiCard(
                              title: 'Me Gustas',
                              value: '${data.totalLikes}',
                              subtitle: 'Reacciones',
                              icon: Icons.favorite_rounded,
                              color: const Color(0xFFEF4444),
                              badge: 'Interacción',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildKpiCard(
                              title: 'Comentarios',
                              value: '${data.totalComments}',
                              subtitle: 'Conversaciones',
                              icon: Icons.chat_bubble_rounded,
                              color: const Color(0xFF10B981),
                              badge: 'Comunidad',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildKpiCard(
                              title: 'Tiempo Reproducido',
                              value: data.formattedTotalWatchTime,
                              subtitle: 'Prom: ${data.formattedAvgWatchTime}/vid',
                              icon: Icons.timer_rounded,
                              color: AppTheme.accentOrange,
                              badge: 'Retención',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 15s Watch Time Rule Info Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryTerracotta.withOpacity(0.08),
                              AppTheme.accentOrange.withOpacity(0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primaryTerracotta.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryTerracotta.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified_rounded, color: AppTheme.primaryTerracotta, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '⏱️ Regla de Validación de Vistas (15 Segundos)',
                                    style: GoogleFonts.fredoka(
                                      color: AppTheme.primaryTerracotta,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Para garantizar autenticidad y recompensas justas en Solana, una vista solo se contabiliza cuando el usuario reproduce el video por al menos 15 segundos.',
                                    style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark, fontSize: 12),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        'Tasa de Retención: ',
                                        style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12),
                                      ),
                                      Text(
                                        '${data.retentionRatePercentage}% de audiencia calificada',
                                        style: GoogleFonts.fredoka(
                                          color: AppTheme.emeraldGreen,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Chart Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '📈 Gráficas de Tendencia',
                            style: GoogleFonts.fredoka(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryDark,
                            ),
                          ),
                          Text(
                            'Últimos 7 días',
                            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMutedWarm),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Chart Tabs Selector
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildChartTabButton(0, 'Vistas', Icons.remove_red_eye_rounded, const Color(0xFF3B82F6)),
                            const SizedBox(width: 8),
                            _buildChartTabButton(1, 'Me Gustas', Icons.favorite_rounded, const Color(0xFFEF4444)),
                            const SizedBox(width: 8),
                            _buildChartTabButton(2, 'Comentarios', Icons.chat_bubble_rounded, const Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            _buildChartTabButton(3, 'Tiempo (Min)', Icons.timer_rounded, AppTheme.accentOrange),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Interactive Chart Canvas Container
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.borderWarm),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryTerracotta.withOpacity(0.06),
                              blurRadius: 12,
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
                                Text(
                                  _getChartTitle(),
                                  style: GoogleFonts.fredoka(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _getChartColor(),
                                  ),
                                ),
                                Text(
                                  'Total periodo: ${_getChartPeriodTotal(data)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textMutedWarm,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 180,
                              child: _buildBarChart(data.weeklyHistory),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Detailed Table / Day-by-Day Breakdown
                      Text(
                        '📋 Detalle Día por Día',
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.borderWarm),
                        ),
                        child: Column(
                          children: [
                            // Table Header
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(flex: 3, child: Text('Día', style: GoogleFonts.fredoka(fontSize: 12, color: AppTheme.textMutedWarm, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 2, child: Text('Vistas', textAlign: TextAlign.center, style: GoogleFonts.fredoka(fontSize: 12, color: AppTheme.textMutedWarm, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 2, child: Text('Likes', textAlign: TextAlign.center, style: GoogleFonts.fredoka(fontSize: 12, color: AppTheme.textMutedWarm, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 2, child: Text('Cmts', textAlign: TextAlign.center, style: GoogleFonts.fredoka(fontSize: 12, color: AppTheme.textMutedWarm, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 3, child: Text('Tiempo', textAlign: TextAlign.end, style: GoogleFonts.fredoka(fontSize: 12, color: AppTheme.textMutedWarm, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: AppTheme.borderWarm),
                            ...data.weeklyHistory.map((point) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(flex: 3, child: Text(point.label, style: GoogleFonts.fredoka(fontSize: 12, color: AppTheme.textPrimaryDark, fontWeight: FontWeight.bold))),
                                    Expanded(flex: 2, child: Text('${point.views}', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF3B82F6), fontWeight: FontWeight.w600))),
                                    Expanded(flex: 2, child: Text('${point.likes}', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFFEF4444), fontWeight: FontWeight.w600))),
                                    Expanded(flex: 2, child: Text('${point.comments}', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF10B981), fontWeight: FontWeight.w600))),
                                    Expanded(flex: 3, child: Text('${point.watchMinutes} min', textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.accentOrange, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderWarm),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.fredoka(color: color, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.fredoka(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMutedWarm, fontWeight: FontWeight.w500),
          ),
          Text(
            subtitle,
            style: GoogleFonts.outfit(fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTabButton(int index, String title, IconData icon, Color color) {
    final isSelected = _selectedChartTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedChartTab = index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : AppTheme.surfaceWarm,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : AppTheme.borderWarm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : color, size: 14),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.fredoka(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.textPrimaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getChartTitle() {
    switch (_selectedChartTab) {
      case 0:
        return '👁️ Vistas Calificadas (>=15s)';
      case 1:
        return '❤️ Me Gustas Obtenidos';
      case 2:
        return '💬 Comentarios en Publicaciones';
      case 3:
        return '⏱️ Minutos de Retención';
      default:
        return 'Métricas';
    }
  }

  Color _getChartColor() {
    switch (_selectedChartTab) {
      case 0:
        return const Color(0xFF3B82F6);
      case 1:
        return const Color(0xFFEF4444);
      case 2:
        return const Color(0xFF10B981);
      case 3:
        return AppTheme.accentOrange;
      default:
        return AppTheme.primaryTerracotta;
    }
  }

  String _getChartPeriodTotal(PetAnalyticsModel data) {
    switch (_selectedChartTab) {
      case 0:
        return '${data.weeklyHistory.fold<int>(0, (s, p) => s + p.views)} vistas';
      case 1:
        return '${data.weeklyHistory.fold<int>(0, (s, p) => s + p.likes)} likes';
      case 2:
        return '${data.weeklyHistory.fold<int>(0, (s, p) => s + p.comments)} comentarios';
      case 3:
        final mins = data.weeklyHistory.fold<double>(0.0, (s, p) => s + p.watchMinutes);
        return '${mins.toStringAsFixed(1)} min';
      default:
        return '';
    }
  }

  Widget _buildBarChart(List<DailyMetricPoint> history) {
    if (history.isEmpty) {
      return const Center(child: Text('Sin datos'));
    }

    double maxValue = 1.0;
    for (final p in history) {
      double v = 0;
      if (_selectedChartTab == 0) v = p.views.toDouble();
      if (_selectedChartTab == 1) v = p.likes.toDouble();
      if (_selectedChartTab == 2) v = p.comments.toDouble();
      if (_selectedChartTab == 3) v = p.watchMinutes;
      if (v > maxValue) maxValue = v;
    }

    final color = _getChartColor();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: history.map((point) {
        double val = 0;
        if (_selectedChartTab == 0) val = point.views.toDouble();
        if (_selectedChartTab == 1) val = point.likes.toDouble();
        if (_selectedChartTab == 2) val = point.comments.toDouble();
        if (_selectedChartTab == 3) val = point.watchMinutes;

        final heightFraction = (val / maxValue).clamp(0.08, 1.0);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _selectedChartTab == 3 ? val.toStringAsFixed(1) : '${val.toInt()}',
                  style: GoogleFonts.fredoka(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 130 * heightFraction,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        color.withOpacity(0.4),
                        color,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  point.label.split(' ').first,
                  style: GoogleFonts.fredoka(
                    fontSize: 10,
                    color: AppTheme.textMutedWarm,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
