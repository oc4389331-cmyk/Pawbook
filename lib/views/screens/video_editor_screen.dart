import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/sound_track_model.dart';

// ── Overlay Item Model (Stickers, Emojis, Text) ──────────────────────────────
enum OverlayType { sticker, emoji, text }

class VideoOverlayItem {
  final String id;
  final OverlayType type;
  String content;
  Offset offset;
  double scale;
  double rotation;
  Color textColor;
  Color backgroundColor;

  VideoOverlayItem({
    required this.id,
    required this.type,
    required this.content,
    required this.offset,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.textColor = Colors.white,
    this.backgroundColor = Colors.black54,
  });
}

// ── Color Filter Matrix Presets ──────────────────────────────────────────────
class VideoFilterPreset {
  final String name;
  final String emoji;
  final List<double>? matrix;

  const VideoFilterPreset({
    required this.name,
    required this.emoji,
    this.matrix,
  });
}

const List<VideoFilterPreset> videoFilterPresets = [
  VideoFilterPreset(name: 'Normal', emoji: '✨', matrix: null),
  VideoFilterPreset(
    name: 'Warm Golden',
    emoji: '🌅',
    matrix: [
      1.2, 0.0, 0.0, 0.0, 10.0,
      0.0, 1.1, 0.0, 0.0, 5.0,
      0.0, 0.0, 0.8, 0.0, 0.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
  ),
  VideoFilterPreset(
    name: 'Cyber Solana',
    emoji: '⚡',
    matrix: [
      1.1, 0.0, 0.3, 0.0, 15.0,
      0.0, 1.3, 0.1, 0.0, 10.0,
      0.2, 0.0, 1.4, 0.0, 20.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
  ),
  VideoFilterPreset(
    name: 'Vintage Film',
    emoji: '🎞️',
    matrix: [
      0.9, 0.1, 0.1, 0.0, 20.0,
      0.1, 0.8, 0.1, 0.0, 15.0,
      0.1, 0.1, 0.6, 0.0, 10.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
  ),
  VideoFilterPreset(
    name: 'Vibrant Pop',
    emoji: '🐾',
    matrix: [
      1.3, -0.1, -0.1, 0.0, 0.0,
      -0.1, 1.3, -0.1, 0.0, 0.0,
      -0.1, -0.1, 1.3, 0.0, 0.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
  ),
  VideoFilterPreset(
    name: 'Monochrome',
    emoji: '🖤',
    matrix: [
      0.33, 0.59, 0.11, 0.0, 0.0,
      0.33, 0.59, 0.11, 0.0, 0.0,
      0.33, 0.59, 0.11, 0.0, 0.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
  ),
  VideoFilterPreset(
    name: 'Sunset Glow',
    emoji: '🌆',
    matrix: [
      1.3, 0.1, 0.0, 0.0, 25.0,
      0.1, 0.9, 0.2, 0.0, 5.0,
      0.1, 0.0, 1.2, 0.0, 15.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
  ),
];

// ── Studio Result Output ─────────────────────────────────────────────────────
class VideoEditorResult {
  final Uint8List videoBytes;
  final String filename;
  final double startSeconds;
  final double endSeconds;
  final String filterName;
  final List<VideoOverlayItem> overlays;
  final SoundTrack? selectedSound;
  final double originalVolume;
  final double musicVolume;

  const VideoEditorResult({
    required this.videoBytes,
    required this.filename,
    required this.startSeconds,
    required this.endSeconds,
    required this.filterName,
    required this.overlays,
    this.selectedSound,
    this.originalVolume = 1.0,
    this.musicVolume = 0.8,
  });

  double get duration => endSeconds - startSeconds;
}

class VideoEditorScreen extends StatefulWidget {
  final Uint8List videoBytes;
  final String filename;
  final SoundTrack? initialSound;

  const VideoEditorScreen({
    super.key,
    required this.videoBytes,
    required this.filename,
    this.initialSound,
  });

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> with SingleTickerProviderStateMixin {
  // Trimming
  double _totalVideoDuration = 30.0;
  RangeValues _trimRange = const RangeValues(0.0, 15.0);
  bool _isPlaying = true;

  // Filters
  int _selectedFilterIndex = 0;

  // Overlays (Stickers, Emojis, Text)
  final List<VideoOverlayItem> _overlays = [];
  String? _selectedOverlayId;

  // Audio / Sound
  SoundTrack? _selectedSound;
  double _originalVolume = 1.0;
  double _musicVolume = 0.8;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Active Tool Panel
  String _activeTool = 'none'; // 'none', 'trim', 'filter', 'stickers', 'text', 'audio'

  // Scrub animation
  late AnimationController _playheadController;

  @override
  void initState() {
    super.initState();
    _selectedSound = widget.initialSound;

    _playheadController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_trimRange.end - _trimRange.start).toInt() * 1000),
    )..repeat();

    if (_selectedSound != null) {
      _initAudio();
    }
  }

  Future<void> _initAudio() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(_musicVolume);
      if (_selectedSound != null) {
        await _audioPlayer.play(UrlSource(_selectedSound!.url));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _playheadController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _addOverlay(OverlayType type, String content, {Color? textColor, Color? bgColor}) {
    final newId = 'ov_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _overlays.add(VideoOverlayItem(
        id: newId,
        type: type,
        content: content,
        offset: const Offset(120, 200),
        textColor: textColor ?? Colors.white,
        backgroundColor: bgColor ?? Colors.black54,
      ));
      _selectedOverlayId = newId;
    });
  }

  void _removeSelectedOverlay() {
    if (_selectedOverlayId != null) {
      setState(() {
        _overlays.removeWhere((o) => o.id == _selectedOverlayId);
        _selectedOverlayId = null;
      });
    }
  }

  void _openTextEditorModal() {
    final textController = TextEditingController();
    Color selectedColor = Colors.white;
    Color selectedBg = Colors.black87;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF18181B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Agregar Texto al Video', style: GoogleFonts.fredoka(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  autofocus: true,
                  style: GoogleFonts.fredoka(color: selectedColor, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Escribe algo divertido...',
                    hintStyle: GoogleFonts.fredoka(color: Colors.white38),
                    filled: true,
                    fillColor: selectedBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Color de texto:', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                    const SizedBox(width: 10),
                    ...[Colors.white, AppTheme.accentOrange, AppTheme.solanaGreen, AppTheme.solanaPurple, Colors.yellowAccent].map((c) => GestureDetector(
                      onTap: () => setModalState(() => selectedColor = c),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: selectedColor == c ? Colors.white : Colors.transparent, width: 2),
                        ),
                      ),
                    )),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTerracotta,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: Text('Agregar al Video', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 15)),
                    onPressed: () {
                      final text = textController.text.trim();
                      if (text.isNotEmpty) {
                        _addOverlay(OverlayType.text, text, textColor: selectedColor, bgColor: selectedBg);
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _finishEditing() {
    final result = VideoEditorResult(
      videoBytes: widget.videoBytes,
      filename: widget.filename,
      startSeconds: _trimRange.start,
      endSeconds: _trimRange.end,
      filterName: videoFilterPresets[_selectedFilterIndex].name,
      overlays: List.unmodifiable(_overlays),
      selectedSound: _selectedSound,
      originalVolume: _originalVolume,
      musicVolume: _musicVolume,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final currentFilter = videoFilterPresets[_selectedFilterIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Center Video Canvas Preview with Applied Filter & Overlays
            Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121214),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Video simulation / preview
                        currentFilter.matrix != null
                            ? ColorFiltered(
                                colorFilter: ColorFilter.matrix(currentFilter.matrix!),
                                child: _buildVideoCanvasContent(),
                              )
                            : _buildVideoCanvasContent(),

                        // Overlays layer (Stickers, Emojis, Text)
                        ..._overlays.map((item) => _buildDraggableOverlay(item)),

                        // Watermark / Filter indicator
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(currentFilter.emoji, style: const TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Text(
                                  currentFilter.name,
                                  style: GoogleFonts.fredoka(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Audio track indicator
                        if (_selectedSound != null)
                          Positioned(
                            bottom: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.music_note_rounded, color: AppTheme.accentOrange, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    _selectedSound!.title,
                                    style: GoogleFonts.fredoka(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 2. Top Header Action Bar
            Positioned(
              top: 10,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.movie_filter_rounded, color: AppTheme.accentOrange, size: 16),
                        const SizedBox(width: 6),
                        Text('Pawtbook Video Studio 🎬', style: GoogleFonts.fredoka(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTerracotta,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: _finishEditing,
                    child: Text('Listo ✅', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            ),

            // 3. Right Floating Tools Sidebar (TikTok Style)
            Positioned(
              right: 20,
              top: 80,
              child: Column(
                children: [
                  _buildStudioToolButton(icon: Icons.content_cut_rounded, label: 'Cortar', toolId: 'trim'),
                  const SizedBox(height: 12),
                  _buildStudioToolButton(icon: Icons.filter_vintage_rounded, label: 'Filtros', toolId: 'filter'),
                  const SizedBox(height: 12),
                  _buildStudioToolButton(icon: Icons.emoji_emotions_rounded, label: 'Stickers', toolId: 'stickers'),
                  const SizedBox(height: 12),
                  _buildStudioToolButton(icon: Icons.title_rounded, label: 'Texto', toolId: 'text', onTap: _openTextEditorModal),
                  const SizedBox(height: 12),
                  _buildStudioToolButton(icon: Icons.music_note_rounded, label: 'Música', toolId: 'audio'),
                  if (_selectedOverlayId != null) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _removeSelectedOverlay,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 4. Bottom Dynamic Drawer / Panel based on active tool
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildActiveToolBottomPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCanvasContent() {
    return Container(
      color: const Color(0xFF18181B),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryTerracotta.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_circle_fill_rounded, size: 64, color: AppTheme.primaryTerracotta),
            ),
            const SizedBox(height: 12),
            Text(widget.filename, style: GoogleFonts.fredoka(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              '${(_trimRange.end - _trimRange.start).toStringAsFixed(1)}s de video',
              style: GoogleFonts.outfit(color: AppTheme.accentOrange, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableOverlay(VideoOverlayItem item) {
    final isSelected = item.id == _selectedOverlayId;

    return Positioned(
      left: item.offset.dx,
      top: item.offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            item.offset = Offset(
              item.offset.dx + details.delta.dx,
              item.offset.dy + details.delta.dy,
            );
            _selectedOverlayId = item.id;
          });
        },
        onTap: () {
          setState(() => _selectedOverlayId = item.id);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: item.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.accentOrange : Colors.transparent,
              width: 2,
            ),
          ),
          child: item.type == OverlayType.text
              ? Text(
                  item.content,
                  style: GoogleFonts.fredoka(
                    color: item.textColor,
                    fontSize: 18 * item.scale,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Text(
                  item.content,
                  style: TextStyle(fontSize: 32 * item.scale),
                ),
        ),
      ),
    );
  }

  Widget _buildStudioToolButton({
    required IconData icon,
    required String label,
    required String toolId,
    VoidCallback? onTap,
  }) {
    final isActive = _activeTool == toolId;

    return GestureDetector(
      onTap: onTap ?? () {
        setState(() {
          _activeTool = _activeTool == toolId ? 'none' : toolId;
        });
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primaryTerracotta : Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(color: isActive ? Colors.white : Colors.white24),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.fredoka(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Bottom Active Tool Drawers ─────────────────────────────────────────────
  Widget _buildActiveToolBottomPanel() {
    if (_activeTool == 'trim') {
      return _buildTrimPanel();
    } else if (_activeTool == 'filter') {
      return _buildFilterPanel();
    } else if (_activeTool == 'stickers') {
      return _buildStickersPanel();
    } else if (_activeTool == 'audio') {
      return _buildAudioPanel();
    }
    return const SizedBox.shrink();
  }

  Widget _buildTrimPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF18181B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('✂️ Recortar Video', style: GoogleFonts.fredoka(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              Text(
                'Duración: ${(_trimRange.end - _trimRange.start).toStringAsFixed(1)}s (Máx 30s)',
                style: GoogleFonts.outfit(color: AppTheme.solanaGreen, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                onPressed: () => setState(() => _activeTool = 'none'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RangeSlider(
            values: _trimRange,
            min: 0.0,
            max: _totalVideoDuration,
            divisions: 30,
            activeColor: AppTheme.primaryTerracotta,
            inactiveColor: Colors.white24,
            labels: RangeLabels(
              '${_trimRange.start.toStringAsFixed(1)}s',
              '${_trimRange.end.toStringAsFixed(1)}s',
            ),
            onChanged: (values) {
              if (values.end - values.start >= 3.0) {
                setState(() => _trimRange = values);
              }
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Inicio: ${_trimRange.start.toStringAsFixed(1)}s', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11)),
              Text('Fin: ${_trimRange.end.toStringAsFixed(1)}s', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF18181B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: videoFilterPresets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final preset = videoFilterPresets[i];
          final isSelected = _selectedFilterIndex == i;

          return GestureDetector(
            onTap: () => setState(() => _selectedFilterIndex = i),
            child: Container(
              width: 76,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryTerracotta.withOpacity(0.2) : Colors.black45,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryTerracotta : Colors.white24,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(preset.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(
                    preset.name,
                    style: GoogleFonts.fredoka(
                      color: isSelected ? AppTheme.primaryTerracotta : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStickersPanel() {
    final petStickers = ['🐾', '👑', '😎', '🦴', '🐶', '🐱', '💖', '⚡', '🔥', '🏆', '✨', '🏖️', '🐕', '🐈', '🧶', '🍖', '🎀', '🕶️', '🌟', '🎉'];

    return Container(
      height: 160,
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFF18181B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🐾 Stickers y Emojis para Mascotas', style: GoogleFonts.fredoka(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                onPressed: () => setState(() => _activeTool = 'none'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: petStickers.length,
              itemBuilder: (context, i) {
                final emoji = petStickers[i];
                return GestureDetector(
                  onTap: () {
                    _addOverlay(OverlayType.emoji, emoji);
                    setState(() => _activeTool = 'none');
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPanel() {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF18181B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🎵 Mezclador de Audio & Música', style: GoogleFonts.fredoka(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                onPressed: () => setState(() => _activeTool = 'none'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Volume sliders
          Row(
            children: [
              const Icon(Icons.videocam_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text('Video:', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11)),
              Expanded(
                child: Slider(
                  value: _originalVolume,
                  min: 0.0,
                  max: 1.0,
                  activeColor: AppTheme.accentOrange,
                  onChanged: (v) => setState(() => _originalVolume = v),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.music_note_rounded, color: AppTheme.solanaGreen, size: 16),
              const SizedBox(width: 6),
              Text('Música:', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11)),
              Expanded(
                child: Slider(
                  value: _musicVolume,
                  min: 0.0,
                  max: 1.0,
                  activeColor: AppTheme.solanaGreen,
                  onChanged: (v) {
                    setState(() => _musicVolume = v);
                    _audioPlayer.setVolume(v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Canciones Royalty-Free:', style: GoogleFonts.fredoka(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.separated(
              itemCount: royaltyFreeSoundsCatalog.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
              itemBuilder: (context, i) {
                final track = royaltyFreeSoundsCatalog[i];
                final isSelected = _selectedSound?.id == track.id;

                return ListTile(
                  dense: true,
                  leading: Text(track.emoji, style: const TextStyle(fontSize: 20)),
                  title: Text(track.title, style: GoogleFonts.fredoka(color: isSelected ? AppTheme.accentOrange : Colors.white, fontSize: 12)),
                  subtitle: Text('${track.artist} • ${track.duration}', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10)),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: AppTheme.accentOrange, size: 18)
                      : null,
                  onTap: () async {
                    setState(() => _selectedSound = track);
                    await _audioPlayer.stop();
                    await _audioPlayer.play(UrlSource(track.url));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
