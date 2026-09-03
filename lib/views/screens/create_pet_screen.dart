import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/language_controller.dart';
import '../../models/pet_model.dart';
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
  final _bioController = TextEditingController();
  final _avatarUrlController = TextEditingController(text: CreatePetScreen.avatarPresets[0]);

  String _selectedSpecies = 'Perro 🐶';
  String _selectedBreed = 'Mestizo / Criollo';
  String _selectedAvatar = CreatePetScreen.avatarPresets[0];

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  void _onSpeciesChanged(String? newSpecies) {
    if (newSpecies != null && newSpecies != _selectedSpecies) {
      setState(() {
        _selectedSpecies = newSpecies;
        final breeds = CreatePetScreen.speciesBreedsMap[newSpecies] ?? ['Mestizo'];
        _selectedBreed = breeds.first;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final langController = Provider.of<LanguageController>(context);
    final availableBreeds = CreatePetScreen.speciesBreedsMap[_selectedSpecies] ?? ['Mestizo'];

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
                        CircleAvatar(
                          radius: 54,
                          backgroundColor: AppTheme.surfaceWarm,
                          backgroundImage: NetworkImage(_selectedAvatar),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryTerracotta,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Elige una foto para tu mascota:',
                      style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 54,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: CreatePetScreen.avatarPresets.length,
                        itemBuilder: (ctx, idx) {
                          final url = CreatePetScreen.avatarPresets[idx];
                          final isSelected = _selectedAvatar == url;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedAvatar = url;
                              _avatarUrlController.text = url;
                            }),
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
              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                  label: Text(
                    'Crear Perfil de Creador',
                    style: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTerracotta,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final newPet = PetModel(
                        id: 'pet_${const Uuid().v4().substring(0, 8)}',
                        ownerId: authController.currentProfile?.id ?? 'usr_demo',
                        name: _nameController.text.trim(),
                        species: _selectedSpecies.split(' ').first,
                        breed: _selectedBreed,
                        bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : 'Creador oficial en Pawtbook 🐾',
                        avatarUrl: _selectedAvatar,
                        nftMintAddress: null, // Verifiable later on profile
                        createdAt: DateTime.now(),
                      );

                      await authController.registerPet(newPet);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.emeraldGreen,
                            content: Text(
                              '🎉 ¡${newPet.name} registrado con éxito como Mascota Creadora!',
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
