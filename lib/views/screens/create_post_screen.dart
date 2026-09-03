import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../models/pet_model.dart';
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

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final feedController = Provider.of<FeedController>(context);

    // Key Rule Check: Human Profile without Pet is BLOCKED from posting
    if (!authController.hasPet) {
      return Scaffold(
        appBar: AppBar(title: const Text('Crear Publicación')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 64, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              const Text(
                'Restricción de Rol: Solo Mascotas Creadoras',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Como Perfil Humano (Tutor / Patrocinador) puedes ver, dar likes y patrocinar mascotas. Para publicar contenido, debes registrar a tu mascota primero.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                icon: const Icon(Icons.pets, color: AppTheme.solanaGreen),
                label: const Text('Registrar a tu Mascota Primero'),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const CreatePetScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Publicación (Mascota)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Pet Selector
            const Text('Publicando como:', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.solanaPurple),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<PetModel>(
                  value: _selectedPet,
                  dropdownColor: AppTheme.cardDark,
                  isExpanded: true,
                  items: authController.userPets.map((pet) {
                    return DropdownMenuItem<PetModel>(
                      value: pet,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundImage: NetworkImage(
                              pet.avatarUrl.isNotEmpty
                                  ? pet.avatarUrl
                                  : 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=200',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(pet.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedPet = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Media Type Picker (Photo vs Short Video <30s)
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library, size: 18),
                        SizedBox(width: 6),
                        Text('Foto'),
                      ],
                    ),
                    selected: _mediaType == 'image',
                    selectedColor: AppTheme.solanaPurple,
                    onSelected: (_) => setState(() {
                      _mediaType = 'image';
                      _sampleMediaUrl = 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=800';
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam, size: 18),
                        SizedBox(width: 6),
                        Text('Video (<30s)'),
                      ],
                    ),
                    selected: _mediaType == 'video',
                    selectedColor: AppTheme.solanaPurple,
                    onSelected: (_) => setState(() {
                      _mediaType = 'video';
                      _sampleMediaUrl = 'https://images.unsplash.com/photo-1573865526739-10659fec78a5?w=800';
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Media Preview Box
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.network(_sampleMediaUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                    Container(
                      color: Colors.black38,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload, size: 36, color: AppTheme.solanaGreen),
                          SizedBox(height: 6),
                          Text('Cloudflare R2 (media.pawbooklife.com)', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Caption Field
            TextField(
              controller: _captionController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Escribe algo divertido sobre ...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.surfaceDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.borderDark),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Submit Button: Presigned URL -> R2 Upload -> Moderation Pipeline
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: _isUploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send, color: AppTheme.solanaGreen),
                label: Text(_isUploading ? 'Subiendo a Cloudflare R2 & Moderando...' : 'Publicar Contenido'),
                onPressed: _isUploading
                    ? null
                    : () async {
                        if (_selectedPet == null) return;
                        final caption = _captionController.text.trim();
                        if (caption.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor escribe un texto para la publicación')),
                          );
                          return;
                        }

                        setState(() => _isUploading = true);

                        try {
                          final dummyBytes = List<int>.filled(1024, 0); // Mock media bytes
                          final filename = 'media_.';

                          await feedController.createPetPost(
                            pet: _selectedPet,
                            mediaBytes: dummyBytes,
                            filename: filename,
                            mediaType: _mediaType,
                            caption: caption,
                          );

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('¡Publicación enviada a revisión y aprobada por moderación! 🐾'),
                                backgroundColor: AppTheme.solanaGreen,
                              ),
                            );
                            Navigator.of(context).pop();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al publicar: '),
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
