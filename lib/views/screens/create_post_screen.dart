import 'dart:typed_data';
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
  Uint8List? _pickedFileBytes;
  String? _pickedFileName;
  String _sampleMediaUrl = 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=800';

  @override
  void initState() {
    super.initState();
    final authController = Provider.of<AuthController>(context, listen: false);
    if (authController.userPets.isNotEmpty) {
      _selectedPet = authController.activePet ?? authController.userPets.first;
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickMediaFile() async {
    try {
      final picker = ImagePicker();
      final XFile? file = _mediaType == 'video'
          ? await picker.pickVideo(source: ImageSource.gallery)
          : await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);

      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _pickedFileBytes = bytes;
          _pickedFileName = file.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Error al seleccionar archivo: $e', style: GoogleFonts.fredoka()),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final feedController = Provider.of<FeedController>(context);

    // Key Rule Check: Human Profile without Pet is BLOCKED from posting
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
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
                    style: GoogleFonts.fredoka(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Como Tutor Humano puedes explorar, seguir y patrocinar mascotas.\nPara subir videos y fotos, registra el perfil de tu mascota creadora.',
                    style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 14, height: 1.4),
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
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                    label: Text(
                      '🐶 Registrar a tu Mascota Primero',
                      style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const CreatePetScreen()),
                      );
                    },
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
          isPetMode ? '🐾 Subir Video / Foto' : '👤 Publicar para Mascota',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta, fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Context Banner: Differentiating Human Mode vs Pet Creator Mode
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
                      Icon(
                        isPetMode ? Icons.pets_rounded : Icons.person_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isPetMode
                            ? 'Modo Mascota Creadora Activo'
                            : 'Modo Tutor Humano (Publicando para Mascota)',
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isPetMode
                        ? 'Este video se publicará directamente en el perfil creador de @${_selectedPet?.name ?? "tu mascota"} y podrá recibir patrocinios.'
                        : 'Como tutor (${authController.currentProfile?.fullName ?? "Tutor"}), el video se asignará al perfil creador de la mascota seleccionada.',
                    style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.9), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pet Selector (Dropdown)
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
                  items: authController.userPets.map((pet) {
                    return DropdownMenuItem<PetModel>(
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
                              Text(
                                '@${pet.name}',
                                style: GoogleFonts.fredoka(
                                  color: AppTheme.primaryTerracotta,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${pet.species} • ${pet.breed}',
                                style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
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

            // Media Type Picker (Photo vs Video)
            Text(
              'Tipo de Contenido:',
              style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.warmBrown, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    avatar: Icon(
                      Icons.videocam_rounded,
                      size: 20,
                      color: _mediaType == 'video' ? Colors.white : AppTheme.primaryTerracotta,
                    ),
                    label: Text(
                      'Video (<30s)',
                      style: GoogleFonts.fredoka(
                        color: _mediaType == 'video' ? Colors.white : AppTheme.warmBrown,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: _mediaType == 'video',
                    selectedColor: AppTheme.primaryTerracotta,
                    backgroundColor: AppTheme.surfaceWarm,
                    onSelected: (_) => setState(() {
                      _mediaType = 'video';
                      _sampleMediaUrl = 'https://images.unsplash.com/photo-1573865526739-10659fec78a5?w=800';
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    avatar: Icon(
                      Icons.photo_library_rounded,
                      size: 20,
                      color: _mediaType == 'image' ? Colors.white : AppTheme.primaryTerracotta,
                    ),
                    label: Text(
                      'Foto',
                      style: GoogleFonts.fredoka(
                        color: _mediaType == 'image' ? Colors.white : AppTheme.warmBrown,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: _mediaType == 'image',
                    selectedColor: AppTheme.primaryTerracotta,
                    backgroundColor: AppTheme.surfaceWarm,
                    onSelected: (_) => setState(() {
                      _mediaType = 'image';
                      _sampleMediaUrl = 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=800';
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Direct File Upload Button (ImagePicker to Cloudflare R2)
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
                icon: Icon(
                  _pickedFileBytes != null ? Icons.check_circle_rounded : Icons.cloud_upload_rounded,
                  color: _pickedFileBytes != null ? AppTheme.emeraldGreen : AppTheme.primaryTerracotta,
                ),
                label: Text(
                  _pickedFileBytes != null
                      ? '✅ Archivo: ${_pickedFileName ?? "media"}'
                      : '📷 Seleccionar ${_mediaType == "video" ? "Video" : "Foto"} de tu Dispositivo',
                  style: GoogleFonts.fredoka(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _pickedFileBytes != null ? AppTheme.emeraldGreen : AppTheme.primaryTerracotta,
                  ),
                ),
                onPressed: _pickMediaFile,
              ),
            ),
            const SizedBox(height: 16),

            // Media Preview Box
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surfaceWarm,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderWarm),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _pickedFileBytes != null
                        ? Image.memory(
                            _pickedFileBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : Image.network(
                            _sampleMediaUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _pickedFileBytes != null ? Icons.check_circle : Icons.visibility_rounded,
                            size: 18,
                            color: AppTheme.emeraldGreen,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _pickedFileBytes != null
                                ? 'Listo para Cloudflare R2'
                                : 'Vista previa de prueba',
                            style: GoogleFonts.fredoka(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.borderWarm),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.borderWarm),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.primaryTerracotta, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Submit Button: Presigned URL -> R2 Upload -> Moderation Pipeline
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTerracotta,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
                label: Text(
                  _isUploading
                      ? 'Subiendo a R2 & Moderando...'
                      : '🚀 Publicar como @${_selectedPet?.name ?? "Mascota"}',
                  style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: _isUploading
                    ? null
                    : () async {
                        if (_selectedPet == null) return;
                        final rawCaption = _captionController.text.trim();
                        if (rawCaption.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.orangeAccent,
                              content: Text(
                                'Por favor escribe un texto para la publicación',
                                style: GoogleFonts.fredoka(),
                              ),
                            ),
                          );
                          return;
                        }

                        // Apply profanity filter to caption
                        final caption = ProfanityFilterService.sanitize(rawCaption);

                        setState(() => _isUploading = true);

                        try {
                          final mediaBytes = _pickedFileBytes ?? List<int>.filled(1024, 0);
                          final filename = _pickedFileName ??
                              'media_${DateTime.now().millisecondsSinceEpoch}.${_mediaType == "video" ? "mp4" : "jpg"}';

                          await feedController.createPetPost(
                            pet: _selectedPet,
                            mediaBytes: mediaBytes,
                            filename: filename,
                            mediaType: _mediaType,
                            caption: caption,
                          );

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '¡Publicación subida a Cloudflare R2 y aprobada por moderación! 🐾',
                                  style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
                                ),
                                backgroundColor: AppTheme.emeraldGreen,
                              ),
                            );
                            Navigator.of(context).pop();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al publicar: $e', style: GoogleFonts.fredoka()),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isUploading = false);
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

