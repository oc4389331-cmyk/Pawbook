import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../models/pet_model.dart';
import '../../services/r2_storage_service.dart';
import '../../theme/app_theme.dart';

class CreatePetScreen extends StatefulWidget {
  const CreatePetScreen({super.key});

  static const Map<String, List<String>> speciesBreedsMap = {
    'Perro 🐶': [
      'Mestizo / Criollo',
      'Golden Retriever',
      'Labrador Retriever',
      'Bulldog Francés',
      'Pastor Alemán',
      'Pug',
      'Chihuahua',
      'Beagle',
      'Poodle / Caniche',
      'Siberian Husky',
      'Boxer',
      'Dachshund / Teckel',
      'Rottweiler',
      'Shih Tzu',
      'Yorkshire Terrier',
      'Border Collie',
      'Doberman',
      'Corgi',
      'Otro'
    ],
    'Gato 🐱': [
      'Mestizo / Común Europeo',
      'Persa',
      'Siamés',
      'Maine Coon',
      'Bengalí',
      'Ragdoll',
      'Esfinge (Sphynx)',
      'British Shorthair',
      'Abisinio',
      'Angora Turco',
      'Scottish Fold',
      'Otro'
    ],
    'Conejo 🐰': [
      'Cabeza de León',
      'Belier / Holland Lop',
      'Holandés Enano',
      'Angora',
      'Rex',
      'Gigante de Flandes',
      'Común',
      'Otro'
    ],
    'Roedor 🐹': [
      'Hámster Sirio',
      'Hámster Ruso',
      'Cobaya / Cuy',
      'Chinchilla',
      'Hurón (Ferret)',
      'Rata Doméstica',
      'Jerbo',
      'Otro'
    ],
    'Ave 🦜': [
      'Perico Australiano',
      'Ninfa / Carolina',
      'Agapornis (Inseparable)',
      'Canario',
      'Loro',
      'Cacatúa',
      'Guacamayo',
      'Otro'
    ],
    'Reptil / Tortuga 🐢': [
      'Tortuga de Agua',
      'Tortuga Terrestre',
      'Iguana Verde',
      'Dragón Barbudo',
      'Gecko Leopardo',
      'Camaleón',
      'Otro'
    ],
    'Pez 🐠': [
      'Goldfish / Pez Dorado',
      'Betta',
      'Guppy',
      'Pez Disco',
      'Tetra Neón',
      'Otro'
    ],
    'Caballo / Miniatura 🐴': [
      'Pony',
      'Caballo Miniatura',
      'Paso Fino',
      'Pura Sangre',
      'Cuarto de Milla',
      'Otro'
    ],
    'Minipig / Cerdo 🐷': [
      'Minipig',
      'Vietnamita',
      'Juliana',
      'Otro'
    ],
    'Otro 🐾': [
      'Especie / Raza Única',
      'Exótico',
      'Personalizado',
      'Otro'
    ],
  };

  static const List<String> avatarPresets = [
    'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=400',
    'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=400',
    'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?w=400',
    'https://images.unsplash.com/photo-1537151608828-ea2b11777ee8?w=400',
    'https://images.unsplash.com/photo-1552053831-71594a27632d?w=400',
    'https://images.unsplash.com/photo-1583337130417-3346a1be7dee?w=400',
  ];

  @override
  State<CreatePetScreen> createState() => _CreatePetScreenState();
}

class _CreatePetScreenState extends State<CreatePetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _customSpeciesController = TextEditingController();
  final _bioController = TextEditingController();
  final _customAvatarUrlController = TextEditingController();
  final _tutorEmailController = TextEditingController();
  final _tutorPasswordController = TextEditingController();

  String _selectedSpecies = 'Perro 🐶';
  String _selectedBreed = 'Mestizo / Criollo';
  String _selectedAvatar = CreatePetScreen.avatarPresets[0];

  bool _isUploadingToR2 = false;
  final ImagePicker _picker = ImagePicker();
  final R2StorageService _r2Service = R2StorageService();

  @override
  void dispose() {
    _nameController.dispose();
    _customSpeciesController.dispose();
    _bioController.dispose();
    _customAvatarUrlController.dispose();
    _tutorEmailController.dispose();
    _tutorPasswordController.dispose();
    super.dispose();
  }

  void _onSpeciesChanged(String? newSpecies) {
    if (newSpecies != null && newSpecies != _selectedSpecies) {
      setState(() {
        _selectedSpecies = newSpecies;
        final breeds = CreatePetScreen.speciesBreedsMap[newSpecies] ?? ['Especie / Raza Única'];
        _selectedBreed = breeds.first;
      });
    }
  }

  Future<void> _pickAndUploadPhotoToR2(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingToR2 = true);

      final bytes = await pickedFile.readAsBytes();
      final filename = 'pet_avatar_${const Uuid().v4().substring(0, 8)}.jpg';

      // Data URI format for instant preview + Cloudflare R2 URL
      final base64Image = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64Image';
      final r2PublicUrl = '${AppConfig.r2MediaDomain}/avatars/$filename';

      // Upload to Cloudflare R2 bucket
      await _r2Service.uploadMediaWithPresignedUrl(
        presignedPutUrl: r2PublicUrl,
        publicUrl: r2PublicUrl,
        bytes: bytes,
        contentType: 'image/jpeg',
      );

      setState(() {
        _selectedAvatar = dataUrl;
        _isUploadingToR2 = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.emeraldGreen,
            content: Text(
              '☁️ ¡Imagen cargada y guardada exitosamente en Cloudflare R2!',
              style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingToR2 = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'Error al subir imagen a Cloudflare R2: $e',
              style: GoogleFonts.fredoka(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  void _showCustomPhotoOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Seleccionar Foto para Mascota ☁️',
                style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
              ),
              const SizedBox(height: 6),
              Text(
                'Se guardará directamente en Cloudflare R2',
                style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Option 1: Pick from Device Gallery / File Manager
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.surfaceWarm,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryTerracotta),
                ),
                title: Text('Galería / Archivos del Dispositivo', style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark)),
                subtitle: Text('Subir foto desde tu dispositivo a Cloudflare R2', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMutedWarm)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhotoToR2(ImageSource.gallery);
                },
              ),
              const Divider(),

              // Option 2: Take Photo with Camera
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.surfaceWarm,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppTheme.accentOrange),
                ),
                title: Text('Tomar Foto con Cámara', style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark)),
                subtitle: Text('Capturar directamente una foto nueva', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMutedWarm)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhotoToR2(ImageSource.camera);
                },
              ),
              const Divider(),

              // Option 3: Direct URL Link
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.surfaceWarm,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.link_rounded, color: AppTheme.emeraldGreen),
                ),
                title: Text('Ingresar URL / Enlace de Foto', style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark)),
                subtitle: Text('Usar un enlace directo de imagen web', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMutedWarm)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showUrlInputDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUrlInputDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.bgWarmCream,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Ingresar URL de Foto 📸',
            style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ingresa la URL pública de la imagen de tu mascota:',
                style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customAvatarUrlController,
                decoration: InputDecoration(
                  hintText: 'https://miservidor.com/mascota.jpg',
                  hintStyle: GoogleFonts.outfit(color: AppTheme.textMutedWarm),
                  filled: true,
                  fillColor: AppTheme.surfaceWarm,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: GoogleFonts.fredoka(color: AppTheme.textMutedWarm)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTerracotta,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                final url = _customAvatarUrlController.text.trim();
                if (url.isNotEmpty) {
                  setState(() => _selectedAvatar = url);
                }
                Navigator.pop(ctx);
              },
              child: Text('Usar URL', style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAvatarPreview() {
    ImageProvider imageProvider;

    if (_selectedAvatar.startsWith('data:image')) {
      final base64Str = _selectedAvatar.split(',').last;
      imageProvider = MemoryImage(base64Decode(base64Str));
    } else {
      imageProvider = NetworkImage(_selectedAvatar);
    }

    return CircleAvatar(
      radius: 56,
      backgroundColor: AppTheme.surfaceWarm,
      backgroundImage: imageProvider,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final availableBreeds = CreatePetScreen.speciesBreedsMap[_selectedSpecies] ?? ['Especie / Raza Única'];

    return Scaffold(
      backgroundColor: AppTheme.bgWarmCream,
      appBar: AppBar(
        backgroundColor: AppTheme.bgWarmCream,
        elevation: 0,
        title: Text(
          'Registrar Mascota 🐾',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta, fontSize: 22),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Selection Section
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        _buildAvatarPreview(),
                        if (_isUploadingToR2)
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: _showCustomPhotoOptionsModal,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryTerracotta,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Foto de tu Mascota',
                      style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),

                    // Custom Photo Upload Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: _isUploadingToR2
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cloud_upload_rounded, size: 20),
                      label: Text(
                        _isUploadingToR2 ? 'Subiendo a Cloudflare R2...' : 'Subir Foto (Galería / Cámara) ☁️',
                        style: GoogleFonts.fredoka(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _isUploadingToR2 ? null : _showCustomPhotoOptionsModal,
                    ),
                    const SizedBox(height: 14),

                    // Presets Carousel
                    Text(
                      'O selecciona un avatar rápido:',
                      style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: CreatePetScreen.avatarPresets.length,
                        itemBuilder: (ctx, idx) {
                          final url = CreatePetScreen.avatarPresets[idx];
                          final isSelected = _selectedAvatar == url;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedAvatar = url),
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? AppTheme.primaryTerracotta : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 22,
                                backgroundImage: NetworkImage(url),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Pet Name Input
              Text(
                'Nombre de la Mascota:',
                style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark),
                decoration: _inputDecoration('Ej. Firulais, Michi, Rocky', Icons.pets_rounded),
                validator: (v) => v == null || v.trim().isEmpty ? 'Por favor ingresa un nombre' : null,
              ),
              const SizedBox(height: 18),

              // Species Dropdown Selector
              Text(
                'Tipo de Animal Doméstico:',
                style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWarm,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderWarm),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSpecies,
                    isExpanded: true,
                    dropdownColor: AppTheme.bgWarmCream,
                    onChanged: _onSpeciesChanged,
                    items: CreatePetScreen.speciesBreedsMap.keys.map((species) {
                      return DropdownMenuItem<String>(
                        value: species,
                        child: Text(
                          species,
                          style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Custom Species Field (Visible ONLY if "Otro 🐾" is selected)
              if (_selectedSpecies == 'Otro 🐾') ...[
                Text(
                  'Especifica el tipo de animal:',
                  style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _customSpeciesController,
                  style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark),
                  decoration: _inputDecoration('Ej. Hurón, Alpaca, Erizo, Pato...', Icons.category_rounded),
                  validator: (v) => (_selectedSpecies == 'Otro 🐾' && (v == null || v.trim().isEmpty))
                      ? 'Por favor especifica el tipo de animal'
                      : null,
                ),
                const SizedBox(height: 18),
              ],

              // Breed Dropdown Selector (Filtered by Species)
              Text(
                'Raza del Animal:',
                style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWarm,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderWarm),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: availableBreeds.contains(_selectedBreed) ? _selectedBreed : availableBreeds.first,
                    isExpanded: true,
                    dropdownColor: AppTheme.bgWarmCream,
                    onChanged: (String? newBreed) {
                      if (newBreed != null) {
                        setState(() => _selectedBreed = newBreed);
                      }
                    },
                    items: availableBreeds.map((breed) {
                      return DropdownMenuItem<String>(
                        value: breed,
                        child: Text(
                          breed,
                          style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark, fontSize: 15),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Bio / Description
              Text(
                'Biografía / Descripción:',
                style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _bioController,
                maxLines: 2,
                style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark),
                decoration: _inputDecoration('¡Cuenta algo divertido de tu mascota!', Icons.description_rounded),
              ),

              // Account Linking Section (ONLY for Guests creating a pet)
              if (!authController.isAuthenticated) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWarm,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.primaryTerracotta.withOpacity(0.3), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.mark_email_read_rounded, color: AppTheme.primaryTerracotta),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Correo para Iniciar Sesión (Tutor):',
                              style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ingresa tu correo para administrar tu cuenta y volver a entrar a tu mascota desde cualquier celular.',
                        style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _tutorEmailController,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark),
                        decoration: _inputDecoration('tu.correo@gmail.com', Icons.email_outlined),
                        validator: (v) {
                          if (!authController.isAuthenticated && (v == null || v.trim().isEmpty || !v.contains('@'))) {
                            return 'Por favor ingresa tu correo para crear tu cuenta de acceso';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _tutorPasswordController,
                        obscureText: true,
                        style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark),
                        decoration: _inputDecoration('Contraseña (mínimo 6 caracteres)', Icons.lock_outline_rounded),
                        validator: (v) {
                          if (!authController.isAuthenticated && (v == null || v.trim().length < 6)) {
                            return 'Por favor ingresa una contraseña de al menos 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton.icon(
                          icon: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(color: Color(0xFF4285F4), shape: BoxShape.circle),
                            child: const Text('G', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                          label: Text(
                            'O asociar rápidamente con Google',
                            style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontSize: 13),
                          ),
                          onPressed: () async {
                            final emailToUse = _tutorEmailController.text.trim();
                            final ok = await authController.loginWithGoogle(
                              googleEmail: emailToUse.isNotEmpty ? emailToUse : null,
                            );
                            if (ok && mounted) {
                              setState(() {
                                _tutorEmailController.text = authController.currentProfile?.email ?? emailToUse;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  icon: authController.isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_rounded, color: Colors.white),
                  label: Text(
                    authController.isLoading ? 'Registrando Perfil y Wallet...' : 'Crear Perfil y Asociar Cuenta',
                    style: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTerracotta,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: authController.isLoading
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            final speciesFinal = _selectedSpecies == 'Otro 🐾'
                                ? _customSpeciesController.text.trim()
                                : _selectedSpecies.split(' ').first;

                            final newPet = PetModel(
                              id: 'pet_${const Uuid().v4().substring(0, 8)}',
                              ownerId: authController.currentProfile?.id ?? 'usr_pending',
                              name: _nameController.text.trim(),
                              species: speciesFinal,
                              breed: _selectedBreed,
                              bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : 'Creador oficial en Pawtbook 🐾',
                              avatarUrl: _selectedAvatar,
                              nftMintAddress: null,
                              createdAt: DateTime.now(),
                            );

                            await authController.registerPet(
                              newPet,
                              ownerEmail: _tutorEmailController.text.trim(),
                              ownerPassword: _tutorPasswordController.text.trim(),
                            );

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppTheme.emeraldGreen,
                                  content: Text(
                                    '🎉 ¡${newPet.name} registrado! Tu cuenta de Tutor y Wallet de Solana han sido vinculadas.',
                                    style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                              Navigator.of(context).pop();
                            }
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(color: AppTheme.textMutedWarm),
      prefixIcon: Icon(icon, color: AppTheme.primaryTerracotta),
      filled: true,
      fillColor: AppTheme.surfaceWarm,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppTheme.borderWarm),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppTheme.borderWarm),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppTheme.primaryTerracotta, width: 2),
      ),
    );
  }
}
