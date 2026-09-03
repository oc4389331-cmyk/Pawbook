import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../widgets/tiktok_feed_item.dart';
import 'create_pet_screen.dart';
import 'create_post_screen.dart';
import 'marketplace_screen.dart';
import 'pet_profile_screen.dart';
import 'rewards_store_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FeedController>(context, listen: false).fetchActivePosts();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final feedController = Provider.of<FeedController>(context);
    final currentUserId = authController.currentProfile?.id ?? 'usr_guest';

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: TikTok Style Vertical Feed
          _buildTikTokFeedTab(feedController, currentUserId, authController),

          // Tab 1: Marketplace (Exclusive Bandanas)
          const MarketplaceScreen(),

          // Tab 2: Pet Profile (or Human Tutor profile)
          authController.hasPet
              ? PetProfileScreen(pet: authController.activePet!)
              : _buildHumanProfileTab(authController),

          // Tab 3: Rewards Store
          const RewardsStoreScreen(),
        ],
      ),

      // Floating Action Button (+ Video) ONLY visible for Pet Creators
      floatingActionButton: authController.hasPet
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF6366F1),
              elevation: 8,
              icon: const Icon(Icons.videocam, color: Color(0xFF14F195)),
              label: const Text(
                '+ Video',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                );
              },
            )
          : null,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: const Color(0xFF18181B),
        selectedItemColor: const Color(0xFF14F195),
        unselectedItemColor: Colors.grey[500],
        type: BottomNavigationBarType.fixed,
        onTap: (idx) => setState(() => _currentIndex = idx),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.movie_creation_outlined), activeIcon: Icon(Icons.movie_creation), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.storefront_outlined), activeIcon: Icon(Icons.storefront), label: 'Marketplace'),
          BottomNavigationBarItem(icon: Icon(Icons.pets_outlined), activeIcon: Icon(Icons.pets), label: 'Perfil'),
          BottomNavigationBarItem(icon: Icon(Icons.card_giftcard_outlined), activeIcon: Icon(Icons.card_giftcard), label: 'Premios'),
        ],
      ),
    );
  }

  Widget _buildTikTokFeedTab(FeedController feedController, String currentUserId, AuthController authController) {
    if (feedController.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }

    if (feedController.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No hay publicaciones activas en el feed.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => feedController.fetchActivePosts(),
              child: const Text('Actualizar Feed'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Vertical PageView (TikTok Style)
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: feedController.posts.length,
          itemBuilder: (context, index) {
            final post = feedController.posts[index];
            return TikTokFeedItem(
              post: post,
              currentUserId: currentUserId,
              onLikeToggled: () {
                setState(() {});
              },
            );
          },
        ),

        // Top Overlay Header
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pets, color: Color(0xFF14F195), size: 24),
                    const SizedBox(width: 8),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF14F195), Color(0xFF9945FF)],
                      ).createShader(bounds),
                      child: const Text(
                        'Pawtbook',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 26),
                      tooltip: 'Marketplace Bandanas',
                      onPressed: () => setState(() => _currentIndex = 1),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF6366F1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.stars, color: Color(0xFFF59E0B), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${authController.currentProfile?.pawtScore ?? 100} pts',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHumanProfileTab(AuthController authController) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        title: const Text('Perfil Humano (Patrocinador)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Color(0xFF6366F1),
                child: Icon(Icons.person, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                authController.currentProfile?.username ?? '@tutor_human',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Wallet: ${authController.currentProfile?.walletAddress ?? "Not connected"}',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.pets, size: 48, color: Color(0xFF14F195)),
                    const SizedBox(height: 10),
                    const Text(
                      '¿Tienes una mascota?',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Registra a tu mascota para convertirte en Creador y subir videos cortos a Pawtbook.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Registrar Mascota Creadora', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CreatePetScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
