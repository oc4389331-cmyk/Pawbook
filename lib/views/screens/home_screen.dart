import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/post_card.dart';
import 'create_pet_screen.dart';
import 'create_post_screen.dart';
import 'pet_profile_screen.dart';
import 'rewards_store_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FeedController>(context, listen: false).fetchActivePosts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final feedController = Provider.of<FeedController>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets, color: AppTheme.solanaGreen, size: 24),
            const SizedBox(width: 8),
            Text(
              'Pawtbook',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                foreground: Paint()
                  ..shader = const LinearGradient(
                    colors: [AppTheme.solanaGreen, AppTheme.solanaPurple],
                  ).createShader(const Rect.fromLTWH(0, 0, 150, 20)),
              ),
            ),
          ],
        ),
        actions: [
          // PawtScore Badge
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.solanaPurple),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars, color: AppTheme.solanaGreen, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      ' pts',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: Feed (Active Posts Only)
          _buildFeedTab(feedController, authController),

          // Tab 1: Pet Profile showcase (or Create Pet view if none)
          authController.hasPet
              ? PetProfileScreen(pet: authController.activePet!)
              : _buildNoPetProfileView(),

          // Tab 2: Rewards Store
          const RewardsStoreScreen(),
        ],
      ),

      // Floating Action Button to Add Post (Enforces Pet Creator Restriction)
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.solanaPurple,
        icon: const Icon(Icons.add_a_photo, color: AppTheme.solanaGreen),
        label: Text(
          authController.hasPet ? 'Publicar (Mascota)' : 'Crear Post',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          if (!authController.hasPet) {
            _showMustRegisterPetDialog();
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreatePostScreen()),
            );
          }
        },
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: AppTheme.surfaceDark,
        selectedItemColor: AppTheme.solanaGreen,
        unselectedItemColor: AppTheme.textMuted,
        onTap: (idx) => setState(() => _currentIndex = idx),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dynamic_feed), label: 'Feed Global'),
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'Mascota'),
          BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Recompensas'),
        ],
      ),
    );
  }

  Widget _buildFeedTab(FeedController feedController, AuthController authController) {
    if (feedController.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.solanaPurple));
    }

    if (feedController.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text('No hay publicaciones activas en el feed.', style: TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => feedController.fetchActivePosts(),
              child: const Text('Actualizar Feed'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => feedController.fetchActivePosts(),
      color: AppTheme.solanaGreen,
      child: ListView.builder(
        itemCount: feedController.posts.length,
        itemBuilder: (context, index) {
          final post = feedController.posts[index];
          return PostCard(
            post: post,
            onSponsor: (petId, amount) {
              feedController.sponsorPet(petId, amount);
              authController.addPawtScore(amount ~/ 2); // Rewards sponsor with bonus points
            },
            onReport: (postId) {
              feedController.reportPost(postId);
            },
          );
        },
      ),
    );
  }

  Widget _buildNoPetProfileView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 72, color: AppTheme.solanaPurple),
            const SizedBox(height: 16),
            const Text(
              'Perfil Humano (Tutor / Patrocinador)',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Actualmente estás registrado como tutor/espectador. ¡Registra a tu mascota para convertirte en Creador y subir publicaciones!',
              style: TextStyle(color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, color: AppTheme.solanaGreen),
              label: const Text('Registrar a tu Mascota'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreatePetScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMustRegisterPetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Row(
          children: [
            Icon(Icons.pets, color: AppTheme.solanaGreen),
            SizedBox(width: 10),
            Text('Registrar a tu mascota primero', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Solo las mascotas registradas pueden ser creadoras de contenido en Pawtbook. Como perfil humano puedes patrocinar y explorar.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreatePetScreen()),
              );
            },
            child: const Text('Registrar Mascota'),
          ),
        ],
      ),
    );
  }
}
