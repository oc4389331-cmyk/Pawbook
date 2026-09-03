import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../controllers/auth_controller.dart';
import '../../models/pet_model.dart';
import '../../theme/app_theme.dart';

class CreatePetScreen extends StatefulWidget {
  const CreatePetScreen({super.key});

  @override
  State<CreatePetScreen> createState() => _CreatePetScreenState();
}

class _CreatePetScreenState extends State<CreatePetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _speciesController = TextEditingController(text: 'Perro');
  final _breedController = TextEditingController();
  final _bioController = TextEditingController();
  final _avatarUrlController = TextEditingController(
    text: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=400',
  );
  final _nftMintController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _speciesController.dispose();
    _breedController.dispose();
    _bioController.dispose();
    _avatarUrlController.dispose();
    _nftMintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Mascota (Perfil Creador)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¡Habilita la opción de publicar contenido registrando a tu mascota! 🐾',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Nombre de la Mascota', Icons.pets),
                validator: (v) => v == null || v.isEmpty ? 'Ingresa el nombre' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _speciesController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Especie (Perro, Gato, etc.)', Icons.category),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _breedController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Raza', Icons.nature),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _bioController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: _inputDecoration('Biografía de la Mascota', Icons.description),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _avatarUrlController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('URL de Avatar / Foto', Icons.image),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _nftMintController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Solana NFT Mint Address (Opcional)', Icons.verified),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle, color: AppTheme.solanaGreen),
                  label: const Text('Registrar Mascota'),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final newPet = PetModel(
                        id: 'pet_' + const Uuid().v4().substring(0, 8),
                        ownerId: authController.currentProfile?.id ?? 'usr_demo',
                        name: _nameController.text.trim(),
                        species: _speciesController.text.trim(),
                        breed: _breedController.text.trim().isNotEmpty ? _breedController.text.trim() : 'Mixta',
                        bio: _bioController.text.trim(),
                        avatarUrl: _avatarUrlController.text.trim(),
                        nftMintAddress: _nftMintController.text.trim().isNotEmpty ? _nftMintController.text.trim() : 'SolMint',
                        createdAt: DateTime.now(),
                      );

                      await authController.registerPet(newPet);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('¡ registrada con éxito! Ahora eres Perfil Creador.'),
                            backgroundColor: AppTheme.solanaGreen,
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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textMuted),
      prefixIcon: Icon(icon, color: AppTheme.solanaPurple),
      filled: true,
      fillColor: AppTheme.surfaceDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.borderDark),
      ),
    );
  }
}
