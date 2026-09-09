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
  String? _selectedPostId; // null = Global (todos los videos), otherwise specific video ID

  @override
  void initState() {
    super.initState();
    _analyticsFuture = _supabaseService.getPetAnalytics(widget.pet.id, petName: widget.pet.name);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.90,
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
                        'Métricas Globales y por Video Individual',
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
                final isGlobal = _selectedPostId == null;
                
                // Find currently selected video item if any
                VideoAnalyticsItem? currentVideo;
                if (!isGlobal) {
                  try {
                    currentVideo = data.videoBreakdown.firstWhere((v) => v.postId == _selectedPostId);
                  } catch (_) {
                    currentVideo = data.videoBreakdown.isNotEmpty ? data.videoBreakdown.first : null;
                  }
                }

                // Active metrics based on selection
                final displayViews = isGlobal ? data.totalViews : (currentVideo?.viewsCount ?? 0);
                final displayLikes = isGlobal ? data.totalLikes : (currentVideo?.likesCount ?? 0);
                final displayComments = isGlobal ? data.totalComments : (currentVideo?.commentsCount ?? 0);
                final displayWatchTime = isGlobal ? data.formattedTotalWatchTime : (currentVideo?.formattedTotalWatchTime ?? '0s');
                final displayAvgTime = isGlobal ? data.formattedAvgWatchTime : (currentVideo?.formattedAvgWatchTime ?? '0s');
                final displayRetention = isGlobal ? data.retentionRatePercentage : (currentVideo?.retentionRatePercentage ?? 0.0);
                final displayHistory = isGlobal ? data.globalHistory : (currentVideo?.history ?? data.globalHistory);

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Video Mode Selector Carousel (Global vs Individual Video)
                      _buildVideoFilterSelector(data),
                      const SizedBox(height: 16),

                      // Selected View Banner
                      if (!isGlobal && currentVideo != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accentOrange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.accentOrange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  color: AppTheme.surfaceWarm,
                                  child: currentVideo.mediaUrl.isNotEmpty
                                      ? Image.network(
                                          currentVideo.mediaUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.movie_rounded, color: AppTheme.accentOrange),
                                        )
                                      : const Icon(Icons.movie_rounded, color: AppTheme.accentOrange),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentOrange,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '🎬 Métrica Individual',
                                            style: GoogleFonts.fredoka(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      currentVideo.caption.isNotEmpty ? currentVideo.caption : 'Video #${currentVideo.postId.substring(max(0, currentVideo.postId.length - 4))}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimaryDark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => setState(() => _selectedPostId = null),
                                icon: const Icon(Icons.public_rounded, size: 14, color: AppTheme.primaryTerracotta),
                                label: Text('Ver Global', style: GoogleFonts.fredoka(fontSize: 11, color: AppTheme.primaryTerracotta, fontWeight: FontWeight.bold)),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Section Title & Range Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isGlobal ? '🌐 Resumen Global (${data.totalPosts} videos)' : '🎬 Rendimiento del Video',
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
                              title: 'Vistas Totales',
                              value: '$displayViews',
                              subtitle: isGlobal ? 'Total acumulado' : 'Este video',
                              icon: Icons.remove_red_eye_rounded,
                              color: const Color(0xFF3B82F6),
                              badge: 'Alcance',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildKpiCard(
                              title: 'Me Gustas',
                              value: '$displayLikes',
                              subtitle: isGlobal ? 'En todos los videos' : 'Reacciones',
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
                              value: '$displayComments',
                              subtitle: isGlobal ? 'Comunidad global' : 'En este video',
                              icon: Icons.chat_bubble_rounded,
                              color: const Color(0xFF10B981),
                              badge: 'Comunidad',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildKpiCard(
                              title: 'Tiempo de Vista',
                              value: displayWatchTime,
                              subtitle: isGlobal ? 'Prom: $displayAvgTime/vid' : 'Prom: $displayAvgTime',
                              icon: Icons.timer_rounded,
                              color: AppTheme.accentOrange,
                              badge: 'Retención',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Engagement Info Banner
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
                              child: const Icon(Icons.insights_rounded, color: AppTheme.primaryTerracotta, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '📊 Estadísticas en Tiempo Real',
                                    style: GoogleFonts.fredoka(
                                      color: AppTheme.primaryTerracotta,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Visualiza las reproducciones, reacciones de la comunidad y el tiempo total de retención para medir el impacto de tu mascota creadora.',
                                    style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark, fontSize: 12),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        'Tasa de Retención Promedio: ',
                                        style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12),
                                      ),
                                      Text(
                                        '${displayRetention.toStringAsFixed(1)}%',
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

                      // Chart Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isGlobal ? '📈 Tendencia Global (7 Días)' : '📈 Tendencia del Video (7 Días)',
                            style: GoogleFonts.fredoka(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryDark,
                            ),
                          ),
                          Text(
                            _selectedRange,
                            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMutedWarm, fontWeight: FontWeight.w600),
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
                                  'Total periodo: ${_getChartPeriodTotal(displayHistory)}',
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
                              child: _buildBarChart(displayHistory),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Detailed Table / Day-by-Day Breakdown
                      Text(
                        '📋 Historial por Día',
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
                            ...displayHistory.map((point) {
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
                      const SizedBox(height: 24),

                      // SECTION: Video-by-Video Breakdown List
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.video_library_rounded, color: AppTheme.primaryTerracotta, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '🎬 Desglose por Video (${data.videoBreakdown.length})',
                                style: GoogleFonts.fredoka(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryDark,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Toca para filtrar',
                            style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMutedWarm),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (data.videoBreakdown.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.borderWarm),
                          ),
                          child: Center(
                            child: Text(
                              'Aún no hay videos publicados para este perro.',
                              style: GoogleFonts.outfit(color: AppTheme.textMutedWarm),
                            ),
                          ),
                        )
                      else
                        ...data.videoBreakdown.map((video) {
                          final isSelected = _selectedPostId == video.postId;
                          return _buildVideoBreakdownCard(video, isSelected: isSelected);
                        }),

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

  // Top Video Filter Selector: "🌐 Global" chip + individual video chips
  Widget _buildVideoFilterSelector(PetAnalyticsModel data) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Global Option Chip
          InkWell(
            onTap: () => setState(() => _selectedPostId = null),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedPostId == null ? AppTheme.primaryTerracotta : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedPostId == null ? AppTheme.primaryTerracotta : AppTheme.borderWarm,
                  width: 1.5,
                ),
                boxShadow: _selectedPostId == null
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryTerracotta.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.public_rounded,
                    size: 16,
                    color: _selectedPostId == null ? Colors.white : AppTheme.primaryTerracotta,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '🌐 Todos los Videos (${data.totalPosts})',
                    style: GoogleFonts.fredoka(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _selectedPostId == null ? Colors.white : AppTheme.textPrimaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Individual Video Chips
          ...data.videoBreakdown.asMap().entries.map((entry) {
            final idx = entry.key;
            final video = entry.value;
            final isSelected = _selectedPostId == video.postId;
            final shortCaption = video.caption.isNotEmpty
                ? (video.caption.length > 18 ? '${video.caption.substring(0, 18)}...' : video.caption)
                : 'Video #${idx + 1}';

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => setState(() => _selectedPostId = video.postId),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.accentOrange : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppTheme.accentOrange : AppTheme.borderWarm,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.accentOrange.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.movie_rounded,
                        size: 14,
                        color: isSelected ? Colors.white : AppTheme.accentOrange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '🎬 $shortCaption',
                        style: GoogleFonts.fredoka(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppTheme.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withOpacity(0.25) : AppTheme.surfaceWarm,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${video.viewsCount}v',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppTheme.primaryTerracotta,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Individual Video Card in the Breakdown List
  Widget _buildVideoBreakdownCard(VideoAnalyticsItem video, {required bool isSelected}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppTheme.accentOrange : AppTheme.borderWarm,
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected ? AppTheme.accentOrange.withOpacity(0.12) : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedPostId = isSelected ? null : video.postId),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Video Thumbnail
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 64,
                            height: 64,
                            color: AppTheme.surfaceWarm,
                            child: video.mediaUrl.isNotEmpty
                                ? Image.network(
                                    video.mediaUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.movie_rounded, color: AppTheme.primaryTerracotta, size: 28),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(Icons.movie_rounded, color: AppTheme.primaryTerracotta, size: 28),
                                  ),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Video Info & Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  video.caption.isNotEmpty ? video.caption : 'Publicación de video #Pawtbook',
                                  style: GoogleFonts.fredoka(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentOrange,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Seleccionado',
                                    style: GoogleFonts.fredoka(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Publicado el ${video.createdAt.day}/${video.createdAt.month}/${video.createdAt.year}',
                            style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMutedWarm),
                          ),
                          const SizedBox(height: 8),

                          // Badges Row for this Video
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildMetricBadge('👁️ ${video.viewsCount} vistas', const Color(0xFF3B82F6)),
                              _buildMetricBadge('❤️ ${video.likesCount}', const Color(0xFFEF4444)),
                              _buildMetricBadge('💬 ${video.commentsCount}', const Color(0xFF10B981)),
                              _buildMetricBadge('⏱️ ${video.formattedTotalWatchTime}', AppTheme.accentOrange),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppTheme.borderWarm),
                const SizedBox(height: 8),

                // Footer with Retention and Action Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: AppTheme.textMutedWarm),
                        const SizedBox(width: 4),
                        Text(
                          'Retención: ',
                          style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMutedWarm),
                        ),
                        Text(
                          '${video.retentionRatePercentage.toStringAsFixed(1)}%',
                          style: GoogleFonts.fredoka(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.emeraldGreen,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      isSelected ? '👈 Ver métricas arriba' : 'Ver gráfica de este video →',
                      style: GoogleFonts.fredoka(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppTheme.accentOrange : AppTheme.primaryTerracotta,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.fredoka(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
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
        return '👁️ Vistas Totales';
      case 1:
        return '❤️ Me Gustas Obtenidos';
      case 2:
        return '💬 Comentarios';
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

  String _getChartPeriodTotal(List<DailyMetricPoint> history) {
    switch (_selectedChartTab) {
      case 0:
        return '${history.fold<int>(0, (s, p) => s + p.views)} vistas';
      case 1:
        return '${history.fold<int>(0, (s, p) => s + p.likes)} likes';
      case 2:
        return '${history.fold<int>(0, (s, p) => s + p.comments)} comentarios';
      case 3:
        final mins = history.fold<double>(0.0, (s, p) => s + p.watchMinutes);
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
