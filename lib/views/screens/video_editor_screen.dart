import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../controllers/language_controller.dart';
import '../../theme/app_theme.dart';
import '../../models/sound_track_model.dart';
import '../../services/video_metadata_service.dart';
import '../../services/app_audio_player.dart';

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

const List<String> petStickersCatalog = [
  '🐾', '👑', '😎', '🦴', '🐶', '🐱', '💖', '⚡', '🔥', '🏆',
  '✨', '🏖️', '🐕', '🐈', '🧶', '🍖', '🎀', '🕶️', '🌟', '🎉',
  '🥇', '🐕‍🦺', '🐩', '🦜', '🥳', '😻', '❤️', '🎈', '🤩', '🎯',
  '🌈', '🍦', '🍕', '🍰',
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
  final Uint8List? overlayPngBytes;

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
    this.overlayPngBytes,
  });

  double get duration => endSeconds - startSeconds;

  VideoEditorResult copyWith({
    Uint8List? videoBytes,
    String? filename,
    double? startSeconds,
    double? endSeconds,
    String? filterName,
    List<VideoOverlayItem>? overlays,
    SoundTrack? selectedSound,
    bool clearSound = false,
    double? originalVolume,
    double? musicVolume,
    Uint8List? overlayPngBytes,
  }) {
    return VideoEditorResult(
      videoBytes: videoBytes ?? this.videoBytes,
      filename: filename ?? this.filename,
      startSeconds: startSeconds ?? this.startSeconds,
      endSeconds: endSeconds ?? this.endSeconds,
      filterName: filterName ?? this.filterName,
      overlays: overlays ?? this.overlays,
      selectedSound: clearSound ? null : (selectedSound ?? this.selectedSound),
      originalVolume: originalVolume ?? this.originalVolume,
      musicVolume: musicVolume ?? this.musicVolume,
      overlayPngBytes: overlayPngBytes ?? this.overlayPngBytes,
    );
  }
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

  // Video Info & Aspect Ratio
  VideoInfo? _videoInfo;
  double _aspectRatio = 9 / 16;
  String _aspectRatioMode = '9:16'; // '9:16', '16:9', '1:1'
  BoxFit _videoFit = BoxFit.contain;
  late final String _viewKey;

  // Filters
  int _selectedFilterIndex = 0;

  // Overlays (Stickers, Emojis, Text)
  final List<VideoOverlayItem> _overlays = [];
  String? _selectedOverlayId;
  final GlobalKey _overlaysBoundaryKey = GlobalKey();

  // Audio / Sound
  SoundTrack? _selectedSound;
  double _originalVolume = 1.0;
  double _musicVolume = 0.8;
  final AppAudioPlayer _audioPlayer = AppAudioPlayer();

  // Active Tool Panel
  String _activeTool = 'none'; // 'none', 'ratio', 'trim', 'filter', 'stickers', 'text', 'audio'

  // Scrub animation
  late AnimationController _playheadController;

  @override
  void initState() {
    super.initState();
    _viewKey = 'studio_vid_${DateTime.now().millisecondsSinceEpoch}_${widget.filename.hashCode.abs()}';
    _selectedSound = widget.initialSound;

    _playheadController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_trimRange.end - _trimRange.start).toInt() * 1000),
    )..repeat();

    _loadVideoMetadata();

    if (_selectedSound != null) {
      _initAudio();
    }
  }

  Future<void> _loadVideoMetadata() async {
    try {
      final info = await VideoMetadataService.instance.extractMetadata(widget.videoBytes);
      if (mounted) {
        setState(() {
          _videoInfo = info;
          if (info.durationSeconds > 0) {
            _totalVideoDuration = info.durationSeconds;
            final maxTrim = info.durationSeconds > AppConfig.maxVideoDurationSeconds
                ? AppConfig.maxVideoDurationSeconds
                : info.durationSeconds;
            _trimRange = RangeValues(0.0, maxTrim.clamp(1.0, AppConfig.maxVideoDurationSeconds));
          }
          if (info.isLandscape) {
            _aspectRatio = 16 / 9;
            _aspectRatioMode = '16:9';
          } else if (info.isSquare) {
            _aspectRatio = 1.0;
            _aspectRatioMode = '1:1';
          } else {
            _aspectRatio = 9 / 16;
            _aspectRatioMode = '9:16';
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _initAudio() async {
    try {
      if (_selectedSound != null) {
        await _audioPlayer.play(_selectedSound!.url, loop: true, volume: _musicVolume);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _playheadController.dispose();
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

  Future<void> _finishEditing() async {
    // 1. Deseleccionar overlay para que no aparezca el borde ni la 'X' en la captura
    setState(() => _selectedOverlayId = null);
    await Future.delayed(const Duration(milliseconds: 60));

    // 2. Capturar capa de overlays a PNG transparente si hay stickers o texto
    Uint8List? overlayBytes;
    if (_overlays.isNotEmpty) {
      try {
        final boundary = _overlaysBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 2.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            overlayBytes = byteData.buffer.asUint8List();
          }
        }
      } catch (e) {
        debugPrint('[VideoEditor] Error capturing overlays PNG: $e');
      }
    }

    // 3. Salvaguarda estricta de tiempo máximo (30s)
    double start = _trimRange.start;
    double end = _trimRange.end;
    if (end - start > AppConfig.maxVideoDurationSeconds) {
      end = start + AppConfig.maxVideoDurationSeconds;
    }

    final result = VideoEditorResult(
      videoBytes: widget.videoBytes,
      filename: widget.filename,
      startSeconds: start,
      endSeconds: end,
      filterName: videoFilterPresets[_selectedFilterIndex].name,
      overlays: List.unmodifiable(_overlays),
      selectedSound: _selectedSound,
      originalVolume: _originalVolume,
      musicVolume: _musicVolume,
      overlayPngBytes: overlayBytes,
    );

    if (mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageController>(context);
    final currentFilter = videoFilterPresets[_selectedFilterIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Center Video Canvas Preview with Applied Filter & Overlays
            Center(
              child: AspectRatio(
                aspectRatio: _aspectRatio,
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

                        // Overlays layer (Stickers, Emojis, Text) wrapped in RepaintBoundary for PNG export
                        RepaintBoundary(
                          key: _overlaysBoundaryKey,
                          child: Stack(
                            fit: StackFit.expand,
                            children: _overlays.map((item) => _buildDraggableOverlay(item)).toList(),
                          ),
                        ),

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
                    child: Text(lang.t('studioDoneBtn'), style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 14)),
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
                  _buildStudioToolButton(icon: Icons.aspect_ratio_rounded, label: _aspectRatioMode, toolId: 'ratio'),
                  const SizedBox(height: 12),
                  _buildStudioToolButton(icon: Icons.content_cut_rounded, label: lang.t('studioTrimTool'), toolId: 'trim'),
                  const SizedBox(height: 12),
                  _buildStudioToolButton(icon: Icons.filter_vintage_rounded, label: lang.t('studioFilterTool'), toolId: 'filter'),
                  const SizedBox(height: 12),
                  _buildStudioToolButton(icon: Icons.emoji_emotions_rounded, label: lang.t('studioStickersTool'), toolId: 'stickers'),
                  const SizedBox(height: 12),
                  _buildStudioToolButton(icon: Icons.title_rounded, label: lang.t('studioTextTool'), toolId: 'text', onTap: _openTextEditorModal),
                  const SizedBox(height: 12),
                  _buildStudioToolButton(icon: Icons.music_note_rounded, label: lang.t('studioAudioTool'), toolId: 'audio'),
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
      color: Colors.black,
      child: VideoMetadataService.instance.buildVideoPlayerView(
        bytes: widget.videoBytes,
        viewKey: _viewKey,
        objectUrl: _videoInfo?.objectUrl,
        autoPlay: true,
        loop: true,
        muted: _originalVolume == 0.0,
        volume: _originalVolume,
        fit: _videoFit,
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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: item.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.accentOrange : Colors.white24,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: AppTheme.accentOrange.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                ],
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

            // Top-right 'X' delete button directly on the overlay
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _overlays.removeWhere((o) => o.id == item.id);
                    if (_selectedOverlayId == item.id) {
                      _selectedOverlayId = null;
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
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
    if (_activeTool == 'ratio') {
      return _buildRatioPanel();
    } else if (_activeTool == 'trim') {
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

  Widget _buildRatioPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF18181B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('📐 Formato & Adaptación de Video', style: GoogleFonts.fredoka(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                onPressed: () => setState(() => _activeTool = 'none'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildRatioOption('📱 Vertical', '9:16', 9 / 16),
              const SizedBox(width: 8),
              _buildRatioOption('🖥️ Horizontal', '16:9', 16 / 9),
              const SizedBox(width: 8),
              _buildRatioOption('⏹️ Cuadrado', '1:1', 1.0),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('Modo de encuadre:', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              ChoiceChip(
                label: Text('Ajustar (Sin cortes)', style: GoogleFonts.fredoka(fontSize: 11)),
                selected: _videoFit == BoxFit.contain,
                selectedColor: AppTheme.primaryTerracotta,
                onSelected: (s) => setState(() => _videoFit = BoxFit.contain),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Rellenar', style: GoogleFonts.fredoka(fontSize: 11)),
                selected: _videoFit == BoxFit.cover,
                selectedColor: AppTheme.accentOrange,
                onSelected: (s) => setState(() => _videoFit = BoxFit.cover),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatioOption(String title, String mode, double ratio) {
    final isSelected = _aspectRatioMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _aspectRatio = ratio;
            _aspectRatioMode = mode;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryTerracotta.withOpacity(0.25) : Colors.black45,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primaryTerracotta : Colors.white24,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  color: isSelected ? AppTheme.accentOrange : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                mode,
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
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
            max: _totalVideoDuration > 0 ? _totalVideoDuration : AppConfig.maxVideoDurationSeconds,
            activeColor: AppTheme.primaryTerracotta,
            inactiveColor: Colors.white24,
            labels: RangeLabels(
              '${_trimRange.start.toStringAsFixed(1)}s',
              '${_trimRange.end.toStringAsFixed(1)}s',
            ),
            onChanged: (values) {
              double start = values.start;
              double end = values.end;
              if (end - start > AppConfig.maxVideoDurationSeconds) {
                if ((end - _trimRange.end).abs() > (start - _trimRange.start).abs()) {
                  start = (end - AppConfig.maxVideoDurationSeconds).clamp(0.0, _totalVideoDuration);
                } else {
                  end = (start + AppConfig.maxVideoDurationSeconds).clamp(0.0, _totalVideoDuration);
                }
              }
              if (end - start >= 1.0) {
                setState(() => _trimRange = RangeValues(start, end));
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
    return Container(
      height: 220,
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
              Text('😀 Stickers & Emojis para Mascotas', style: GoogleFonts.fredoka(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                onPressed: () => setState(() => _activeTool = 'none'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: petStickersCatalog.length,
              itemBuilder: (context, i) {
                final sticker = petStickersCatalog[i];
                return GestureDetector(
                  onTap: () => _addOverlay(OverlayType.sticker, sticker),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Center(
                      child: Text(sticker, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearSound() async {
    await _audioPlayer.stop();
    setState(() => _selectedSound = null);
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedSound != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _clearSound,
                      icon: const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
                      label: Text('Quitar sonido', style: GoogleFonts.fredoka(color: Colors.redAccent, fontSize: 11)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                    onPressed: () => setState(() => _activeTool = 'none'),
                  ),
                ],
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
              itemCount: royaltyFreeSoundsCatalog.length + 1,
              separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
              itemBuilder: (context, i) {
                if (i == 0) {
                  final isNoSound = _selectedSound == null;
                  return ListTile(
                    dense: true,
                    leading: const Text('🚫', style: TextStyle(fontSize: 20)),
                    title: Text(
                      'Sin Música (Audio Original)',
                      style: GoogleFonts.fredoka(
                        color: isNoSound ? AppTheme.accentOrange : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text('Usar solo el audio del video', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10)),
                    trailing: isNoSound
                        ? const Icon(Icons.check_circle_rounded, color: AppTheme.accentOrange, size: 18)
                        : null,
                    onTap: _clearSound,
                  );
                }

                final track = royaltyFreeSoundsCatalog[i - 1];
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
                    if (isSelected) {
                      await _clearSound();
                    } else {
                      setState(() => _selectedSound = track);
                      await _audioPlayer.play(track.url, loop: true, volume: _musicVolume);
                    }
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
