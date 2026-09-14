import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../models/pet_model.dart';
import '../../services/profanity_filter_service.dart';
import '../../theme/app_theme.dart';
import 'create_pet_screen.dart';
import 'video_editor_screen.dart';
import '../../services/video_metadata_service.dart';
import '../../services/app_audio_player.dart';

import '../../models/sound_track_model.dart';

// ── Picked Media Model with Dimensions ───────────────────────────────────────
class _PickedMedia {
  final Uint8List bytes;
  final String filename;
  final int? width;
  final int? height;

  _PickedMedia({
    required this.bytes,
    required this.filename,
    this.width,
    this.height,
  });

  String get dimensionsText {
    if (width != null && height != null) {
      return '$width × $height px';
    }
    return 'Procesando...';
  }
}

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionController = TextEditingController();
  PetModel? _selectedPet;
  String _mediaType = 'image';
  bool _isUploading = false;

  // Multi-image / video support
  final List<_PickedMedia> _pickedMedia = [];
  static const int _maxImages = 5;

  // Video studio editor result
  VideoEditorResult? _videoEditorResult;

  // Sound / music selection
  SoundTrack? _selectedSound;
  final AppAudioPlayer _audioPlayer = AppAudioPlayer();
  String? _playingId;
  bool _isAudioPlaying = false;

  @override
  void initState() {
    super.initState();
    final authController = Provider.of<AuthController>(context, listen: false);
    if (authController.userPets.isNotEmpty) {
      _selectedPet = authController.activePet ?? authController.userPets.first;
    }

    _audioPlayer.onPlayingChanged.listen((isPlaying) {
      if (mounted) {
        setState(() => _isAudioPlaying = isPlaying);
      }
    });

    _audioPlayer.onComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isAudioPlaying = false;
          _playingId = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Decode Image Dimensions in px ──────────────────────────────────────────
  Future<Map<String, int>> _getImageDimensions(Uint8List bytes) async {
    try {
      final decoded = await decodeImageFromList(bytes);
      return {'width': decoded.width, 'height': decoded.height};
    } catch (_) {
      return {'width': 0, 'height': 0};
    }
  }

  // ── Pick multiple images ──────────────────────────────────────────────────
  Future<void> _pickImages() async {
    try {
      final remaining = _maxImages - _pickedMedia.length;
      if (remaining <= 0) {
        _showSnack('Ya tienes el máximo de $_maxImages imágenes 📸', isError: true);
        return;
      }

      final picker = ImagePicker();
      List<XFile> files = [];

      try {
        files = await picker.pickMultiImage();
      } catch (_) {
        // Fallback to single image picker on platforms where pickMultiImage fails
        final single = await picker.pickImage(source: ImageSource.gallery);
        if (single != null) {
          files = [single];
        }
      }

      if (files.isEmpty) {
        // Additional fallback: prompt single image if pickMultiImage returned empty
        final single = await picker.pickImage(source: ImageSource.gallery);
        if (single != null) {
          files = [single];
        }
      }

      if (files.isEmpty) return;

      for (final file in files) {
        if (_pickedMedia.length >= _maxImages) break;
        final bytes = await file.readAsBytes();
        final dims = await _getImageDimensions(bytes);
        _pickedMedia.add(_PickedMedia(
          bytes: bytes,
          filename: file.name,
          width: dims['width']! > 0 ? dims['width'] : null,
          height: dims['height']! > 0 ? dims['height'] : null,
        ));
      }

      setState(() {});
    } catch (e) {
      _showSnack('Error al seleccionar imágenes: $e', isError: true);
    }
  }

  // ── Pick single video ─────────────────────────────────────────────────────
  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        final info = await VideoMetadataService.instance.extractMetadata(bytes);
        setState(() {
          _pickedMedia.clear();
          _videoEditorResult = null;
          _pickedMedia.add(_PickedMedia(
            bytes: bytes,
            filename: file.name,
            width: info.width,
            height: info.height,
          ));
        });

        // Automatically open Video Studio for the user after picking video
        await _openVideoEditor();
      }
    } catch (e) {
      _showSnack('Error al seleccionar video: $e', isError: true);
    }
  }

  // ── Open Pawtbook Video Studio ────────────────────────────────────────────
  Future<void> _openVideoEditor() async {
    try {
      Uint8List bytes;
      String filename;

      if (_pickedMedia.isEmpty) {
        final picker = ImagePicker();
        final XFile? file = await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(seconds: 30),
        );
        if (file == null) return;
        bytes = await file.readAsBytes();
        filename = file.name;
        final info = await VideoMetadataService.instance.extractMetadata(bytes);
        if (mounted) {
          setState(() {
            _pickedMedia.clear();
            _pickedMedia.add(_PickedMedia(
              bytes: bytes,
              filename: filename,
              width: info.width,
              height: info.height,
            ));
          });
        }
      } else {
        bytes = _pickedMedia.first.bytes;
        filename = _pickedMedia.first.filename;
      }

      await _audioPlayer.stop();
      if (!mounted) return;

      final result = await Navigator.of(context).push<VideoEditorResult>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => VideoEditorScreen(
            videoBytes: bytes,
            filename: filename,
            initialSound: _selectedSound,
          ),
        ),
      );

      if (result != null && mounted) {
        setState(() {
          _videoEditorResult = result;
          _selectedSound = result.selectedSound;
        });
        _showSnack('✨ Video editado en Studio: Filtro ${result.filterName} • ${result.overlays.length} stickers');
      }
    } catch (e) {
      _showSnack('Error al abrir Studio: $e', isError: true);
    }
  }

  void _removeMedia(int index) {
    setState(() => _pickedMedia.removeAt(index));
  }

  // ── Sound preview / selection ─────────────────────────────────────────────
  Future<void> _toggleSoundPreview(SoundTrack track) async {
    if (_playingId == track.id && _isAudioPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(track.url);
      setState(() => _playingId = track.id);
    }
  }

  Future<void> _selectSound(SoundTrack track) async {
    if (_selectedSound?.id == track.id) {
      await _clearSound();
    } else {
      setState(() {
        _selectedSound = track;
        if (_videoEditorResult != null) {
          _videoEditorResult = _videoEditorResult!.copyWith(selectedSound: track);
        }
      });
    }
  }

  Future<void> _clearSound() async {
    await _audioPlayer.stop();
    setState(() {
      _selectedSound = null;
      _playingId = null;
      _isAudioPlaying = false;
      if (_videoEditorResult != null) {
        _videoEditorResult = _videoEditorResult!.copyWith(clearSound: true);
      }
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: isError ? Colors.redAccent : AppTheme.emeraldGreen,
      content: Text(msg, style: GoogleFonts.fredoka(color: Colors.white)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final feedController = Provider.of<FeedController>(context);

    // Rule Check: Human Profile without registered Pet is BLOCKED
    if (!authController.hasPet) {
      return Scaffold(
        backgroundColor: AppTheme.bgWarmCream,
        appBar: AppBar(
          backgroundColor: AppTheme.bgWarmCream,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.warmBrown),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Crear Publicación',
            style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWarm,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.borderWarm),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pets_rounded, size: 56, color: AppTheme.primaryTerracotta),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '¡Solo las Mascotas Publican! 🐾',
                    style: GoogleFonts.fredoka(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTerracotta,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Para subir fotos y videos con música al feed, registra el perfil de tu mascota creadora en Solana.',
                    style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTerracotta,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: Text(
                      'Registrar a tu Mascota',
                      style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const CreatePetScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final isPetMode = authController.isPetModeActive;

    return Scaffold(
      backgroundColor: AppTheme.bgWarmCream,
      appBar: AppBar(
        backgroundColor: AppTheme.bgWarmCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.warmBrown),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isPetMode ? '🐾 Subir Fotos / Video' : '👤 Publicar para Mascota',
          style: GoogleFonts.fredoka(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryTerracotta,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Context Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPetMode
                      ? [AppTheme.primaryTerracotta, AppTheme.accentOrange]
                      : [AppTheme.warmBrown, const Color(0xFF4A3B32)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (isPetMode ? AppTheme.primaryTerracotta : AppTheme.warmBrown).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isPetMode ? Icons.pets_rounded : Icons.person_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isPetMode ? 'Modo Mascota Creadora Activo' : 'Modo Tutor Humano',
                          style: GoogleFonts.fredoka(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isPetMode
                        ? 'El post se publicará en el perfil de @${_selectedPet?.name ?? "tu mascota"} y podrá recibir patrocinios.'
                        : 'Como tutor (${authController.currentProfile?.fullName ?? "Tutor"}), el post se asignará a la mascota seleccionada.',
                    style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.9), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pet Selector
            Text(
              '🐾 Mascota Creadora que Publica:',
              style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.warmBrown, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWarm,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderWarm),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<PetModel>(
                  value: _selectedPet,
                  dropdownColor: AppTheme.surfaceWarm,
                  isExpanded: true,
                  items: authController.userPets.map((pet) => DropdownMenuItem<PetModel>(
                    value: pet,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: NetworkImage(
                            pet.avatarUrl.isNotEmpty
                                ? pet.avatarUrl
                                : 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=200',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('@${pet.name}', style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('${pet.species} • ${pet.breed}', style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedPet = val);
                      authController.setActivePet(val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Media Type Chips
            Text(
              'Tipo de Contenido:',
              style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.warmBrown, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    avatar: Icon(Icons.photo_library_rounded, size: 20, color: _mediaType == 'image' ? Colors.white : AppTheme.primaryTerracotta),
                    label: Text('Fotos (hasta 5)', style: GoogleFonts.fredoka(color: _mediaType == 'image' ? Colors.white : AppTheme.warmBrown, fontWeight: FontWeight.bold)),
                    selected: _mediaType == 'image',
                    selectedColor: AppTheme.primaryTerracotta,
                    backgroundColor: AppTheme.surfaceWarm,
                    onSelected: (_) => setState(() {
                      _mediaType = 'image';
                      _pickedMedia.clear();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    avatar: Icon(Icons.videocam_rounded, size: 20, color: _mediaType == 'video' ? Colors.white : AppTheme.primaryTerracotta),
                    label: Text('Video (<30s)', style: GoogleFonts.fredoka(color: _mediaType == 'video' ? Colors.white : AppTheme.warmBrown, fontWeight: FontWeight.bold)),
                    selected: _mediaType == 'video',
                    selectedColor: AppTheme.primaryTerracotta,
                    backgroundColor: AppTheme.surfaceWarm,
                    onSelected: (_) => setState(() {
                      _mediaType = 'video';
                      _pickedMedia.clear();
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Recommended Dimensions Info Box
            _buildDimensionsGuide(),
            const SizedBox(height: 20),

            // Multi-image selection section
            if (_mediaType == 'image') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '📷 Galería de Fotos (${_pickedMedia.length}/$_maxImages):',
                    style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.warmBrown, fontSize: 14),
                  ),
                  if (_pickedMedia.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => setState(() => _pickedMedia.clear()),
                      icon: const Icon(Icons.clear_all, size: 16, color: Colors.redAccent),
                      label: Text('Limpiar', style: GoogleFonts.fredoka(color: Colors.redAccent, fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (_pickedMedia.length < _maxImages)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceWarm,
                      foregroundColor: AppTheme.primaryTerracotta,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppTheme.borderWarm, width: 1.5),
                      ),
                      elevation: 0,
                    ),
                    icon: Icon(_pickedMedia.isEmpty ? Icons.add_photo_alternate_rounded : Icons.add_rounded),
                    label: Text(
                      _pickedMedia.isEmpty
                          ? 'Seleccionar hasta $_maxImages fotos'
                          : 'Agregar más fotos (${_maxImages - _pickedMedia.length} restantes)',
                      style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _pickImages,
                  ),
                ),

              // Carousel Preview of Picked Images with Dimension Badges
              if (_pickedMedia.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pickedMedia.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final media = _pickedMedia[i];
                      return Container(
                        width: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.borderWarm, width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(media.bytes, fit: BoxFit.cover),
                              // Remove button
                              Positioned(
                                top: 6,
                                right: 6,
                                child: GestureDetector(
                                  onTap: () => _removeMedia(i),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                              // Slide index badge
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.65),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${i + 1}/$_maxImages',
                                    style: GoogleFonts.fredoka(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              // Dimensions Badge in px
                              Positioned(
                                bottom: 6,
                                left: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.75),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.straighten_rounded, color: AppTheme.accentOrange, size: 12),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          media.dimensionsText,
                                          style: GoogleFonts.fredoka(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '💡 Se mostrará como carrusel deslizable con puntos indicadores en el feed.',
                  style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMutedWarm, fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 20),
            ],

            // Single video selection section
            if (_mediaType == 'video') ...[
              Text(
                '🎥 Video:',
                style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.warmBrown, fontSize: 14),
              ),
              const SizedBox(height: 8),

              // Video Studio Action Button (TikTok-Style Editor) - Prominent and always available
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _openVideoEditor,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _videoEditorResult != null
                                      ? '✨ Editar de nuevo en Video Studio'
                                      : '🎬 Abrir en Pawtbook Video Studio',
                                  style: GoogleFonts.fredoka(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Recorta tiempo, aplica filtros FX, agrega stickers, texto y música',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Pick video from device button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceWarm,
                    foregroundColor: AppTheme.primaryTerracotta,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppTheme.borderWarm, width: 1.5),
                    ),
                    elevation: 0,
                  ),
                  icon: Icon(
                    _pickedMedia.isNotEmpty ? Icons.check_circle_rounded : Icons.cloud_upload_rounded,
                    color: _pickedMedia.isNotEmpty ? AppTheme.emeraldGreen : AppTheme.primaryTerracotta,
                  ),
                  label: Text(
                    _pickedMedia.isNotEmpty
                        ? 'Video listo: ${_pickedMedia.first.filename}'
                        : 'O seleccionar archivo de video de tu galería',
                    style: GoogleFonts.fredoka(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: _pickedMedia.isNotEmpty ? AppTheme.emeraldGreen : AppTheme.primaryTerracotta,
                    ),
                  ),
                  onPressed: _pickVideo,
                ),
              ),
              if (_pickedMedia.isNotEmpty) ...[
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final media = _pickedMedia.first;
                    final isLandscape = media.width != null && media.height != null && media.width! > media.height!;
                    final isSquare = media.width != null && media.height != null && media.width! == media.height!;
                    final aspectRatio = isLandscape ? 16 / 9 : (isSquare ? 1.0 : 9 / 16);
                    final ratioLabel = isLandscape
                        ? '🖥️ Horizontal ${media.width} × ${media.height} px (16:9)'
                        : isSquare
                            ? '⏹️ Cuadrado ${media.width} × ${media.height} px (1:1)'
                            : '📱 Vertical ${media.width ?? 1080} × ${media.height ?? 1920} px (9:16)';

                    return Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _videoEditorResult != null ? AppTheme.accentOrange : Colors.white12,
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AspectRatio(
                          aspectRatio: aspectRatio,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Real interactive Video Player View
                              VideoMetadataService.instance.buildVideoPlayerView(
                                bytes: media.bytes,
                                viewKey: 'create_post_vid_${media.filename.hashCode.abs()}',
                                autoPlay: true,
                                loop: true,
                                muted: true,
                                fit: BoxFit.contain,
                              ),

                              // Tap overlay to open Studio
                              Positioned.fill(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _openVideoEditor,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white30),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.auto_fix_high_rounded, color: AppTheme.accentOrange, size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Toca para editar en Studio 🎬',
                                              style: GoogleFonts.fredoka(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Bottom Aspect Ratio Badge
                              Positioned(
                                bottom: 10,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.75),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isLandscape ? Icons.crop_16_9_rounded : (isSquare ? Icons.crop_square_rounded : Icons.crop_portrait_rounded),
                                        color: AppTheme.solanaGreen,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        ratioLabel,
                                        style: GoogleFonts.fredoka(color: Colors.white, fontSize: 11),
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
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 20),
                    label: Text(
                      _videoEditorResult != null
                          ? '✨ Volver a editar en Video Studio'
                          : '🎬 Entrar a Pawtbook Video Studio',
                      style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _openVideoEditor,
                  ),
                ),

                // Applied Studio Edits Badge
                if (_videoEditorResult != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWarm,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.accentOrange.withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppTheme.emeraldGreen, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Ediciones aplicadas en Studio:',
                              style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.warmBrown, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _buildDimensionChip('✂️ Recorte', '${_videoEditorResult!.startSeconds.toStringAsFixed(1)}s - ${_videoEditorResult!.endSeconds.toStringAsFixed(1)}s (${_videoEditorResult!.duration.toStringAsFixed(1)}s)'),
                            _buildDimensionChip('🎨 Filtro', _videoEditorResult!.filterName),
                            if (_videoEditorResult!.overlays.isNotEmpty)
                              _buildDimensionChip('😀 Overlays', '${_videoEditorResult!.overlays.length} stickers/texto'),
                            if (_videoEditorResult!.selectedSound != null)
                              _buildDimensionChip('🎵 Sonido', _videoEditorResult!.selectedSound!.title),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 20),
            ],

            // Sound / Music Selection Section
            _buildSoundSelectionSection(),
            const SizedBox(height: 20),

            // Caption Field
            Text(
              'Descripción de la Publicación:',
              style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.warmBrown, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _captionController,
              maxLines: 3,
              style: GoogleFonts.outfit(color: AppTheme.warmBrown),
              decoration: InputDecoration(
                hintText: 'Escribe una historia divertida sobre ${_selectedPet?.name ?? "tu mascota"}...',
                hintStyle: GoogleFonts.outfit(color: AppTheme.textMutedWarm),
                filled: true,
                fillColor: AppTheme.surfaceWarm,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryTerracotta, width: 1.5)),
              ),
            ),
            const SizedBox(height: 28),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTerracotta,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                icon: _isUploading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.send_rounded, color: Colors.white),
                label: Text(
                  _isUploading
                      ? 'Subiendo a Cloudflare R2...'
                      : 'Publicar como @${_selectedPet?.name ?? "Mascota"}',
                  style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: _isUploading ? null : () => _submitPost(feedController),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Dimensions Guide Widget ────────────────────────────────────────────────
  Widget _buildDimensionsGuide() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWarm,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.straighten_rounded, size: 16, color: AppTheme.accentOrange),
              const SizedBox(width: 8),
              Text(
                'Dimensiones recomendadas en px',
                style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.warmBrown, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildDimensionChip('📷 Feed Vertical', '1080 × 1350 px (4:3)'),
              _buildDimensionChip('🎥 Feed Video', '1080 × 1920 px (9:16)'),
              _buildDimensionChip('🐾 Perfil', '400 × 400 px (1:1)'),
              _buildDimensionChip('🛍️ Bandana', '800 × 800 px (1:1)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionChip(String label, String dim) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgWarmCream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderWarm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: GoogleFonts.fredoka(fontSize: 10, color: AppTheme.warmBrown, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(dim, style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.textMutedWarm)),
        ],
      ),
    );
  }

  // ── Royalty-Free Sound Selection Widget ────────────────────────────────────
  Widget _buildSoundSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.music_note_rounded, color: AppTheme.accentOrange, size: 20),
            const SizedBox(width: 8),
            Text(
              'Sonido / Música para tu Post',
              style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.warmBrown, fontSize: 14),
            ),
            const Spacer(),
            if (_selectedSound != null)
              TextButton.icon(
                onPressed: _clearSound,
                icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                label: Text('Quitar sonido', style: GoogleFonts.fredoka(color: Colors.redAccent, fontSize: 12)),
              ),
          ],
        ),

        if (_selectedSound != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primaryTerracotta, AppTheme.accentOrange]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Text(_selectedSound!.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedSound!.title,
                        style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        '${_selectedSound!.artist} • ${_selectedSound!.duration}',
                        style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.85), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),
        Text(
          'Repertorio de música royalty-free (sin derechos de autor):',
          style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMutedWarm),
        ),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceWarm,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderWarm),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: royaltyFreeSoundsCatalog.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderWarm, indent: 56),
            itemBuilder: (context, i) {
              final track = royaltyFreeSoundsCatalog[i];
              final isSelected = _selectedSound?.id == track.id;
              final isThisPlaying = _playingId == track.id && _isAudioPlaying;

              return InkWell(
                borderRadius: i == 0
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : (i == royaltyFreeSoundsCatalog.length - 1
                        ? const BorderRadius.vertical(bottom: Radius.circular(16))
                        : BorderRadius.zero),
                onTap: () => _selectSound(track),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryTerracotta.withOpacity(0.08) : Colors.transparent,
                    borderRadius: i == 0
                        ? const BorderRadius.vertical(top: Radius.circular(16))
                        : (i == royaltyFreeSoundsCatalog.length - 1
                            ? const BorderRadius.vertical(bottom: Radius.circular(16))
                            : BorderRadius.zero),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        // Preview Play/Pause button
                        GestureDetector(
                          onTap: () => _toggleSoundPreview(track),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isThisPlaying ? AppTheme.primaryTerracotta : AppTheme.bgWarmCream,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isThisPlaying ? AppTheme.primaryTerracotta : AppTheme.borderWarm,
                              ),
                            ),
                            child: Center(
                              child: isThisPlaying
                                  ? const Icon(Icons.pause_rounded, color: Colors.white, size: 20)
                                  : Text(track.emoji, style: const TextStyle(fontSize: 18)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                style: GoogleFonts.fredoka(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isSelected ? AppTheme.primaryTerracotta : AppTheme.textPrimaryDark,
                                ),
                              ),
                              Text(
                                '${track.artist} • ${track.duration}',
                                style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMutedWarm),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: AppTheme.primaryTerracotta, size: 22)
                        else
                          Icon(Icons.add_circle_outline_rounded, color: AppTheme.textMutedWarm, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Post Submission ────────────────────────────────────────────────────────
  Future<void> _submitPost(FeedController feedController) async {
    if (_selectedPet == null) return;
    final rawCaption = _captionController.text.trim();
    if (rawCaption.isEmpty) {
      _showSnack('Por favor escribe un texto para la publicación', isError: true);
      return;
    }
    if (_pickedMedia.isEmpty) {
      _showSnack('Selecciona al menos una ${_mediaType == "video" ? "video" : "foto"}', isError: true);
      return;
    }

    final caption = ProfanityFilterService.sanitize(rawCaption);
    setState(() => _isUploading = true);
    await _audioPlayer.stop();

    try {
      final first = _pickedMedia.first;
      final extraBytes = _pickedMedia.length > 1
          ? _pickedMedia.sublist(1).map((m) => m.bytes).toList()
          : null;
      final extraNames = _pickedMedia.length > 1
          ? _pickedMedia.sublist(1).map((m) => m.filename).toList()
          : null;

      await feedController.createPetPost(
        pet: _selectedPet,
        mediaBytes: first.bytes,
        filename: first.filename,
        mediaType: _mediaType,
        caption: caption,
        extraMediaBytes: extraBytes,
        extraFilenames: extraNames,
        soundUrl: _selectedSound?.url,
        soundTitle: _selectedSound?.title,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '¡Publicación subida a Cloudflare R2! 🐾${_selectedSound != null ? " 🎵 Con ${_selectedSound!.title}" : ""}',
            style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.emeraldGreen,
        ));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _showSnack('Error al publicar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
