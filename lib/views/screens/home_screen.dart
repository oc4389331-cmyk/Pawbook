import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../controllers/language_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/language_selector.dart';
import '../widgets/tiktok_feed_item.dart';
import 'create_pet_screen.dart';
import 'create_post_screen.dart';
import 'login_screen.dart';
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
    final langController = Provider.of<LanguageController>(context);
    final currentUserId = authController.currentProfile?.id ?? 'usr_guest';

    return Scaffold(
      backgroundColor: AppTheme.bgWarmCream,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: TikTok Style Vertical Feed
          _buildTikTokFeedTab(feedController, currentUserId, authController, langController),

          // Tab 1: Marketplace (Exclusive Bandanas)
          const MarketplaceScreen(),

          // Tab 2: Pet Profile (or Human Tutor profile)
          authController.hasPet
              ? PetProfileScreen(pet: authController.activePet!)
              : _buildHumanProfileTab(authController, langController),

          // Tab 3: Rewards Store
          const RewardsStoreScreen(),
        ],
      ),

      // Floating Action Button (+ Video) ONLY visible for Pet Creators
      floatingActionButton: authController.hasPet
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryTerracotta,
              elevation: 8,
              icon: const Icon(Icons.videocam_rounded, color: Colors.white),
              label: Text(
                langController.t('addVideo'),
                style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                );
              },
            )
          : null,

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWarm,
          border: Border(top: BorderSide(color: AppTheme.borderWarm, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: AppTheme.surfaceWarm,
          selectedItemColor: AppTheme.primaryTerracotta,
          unselectedItemColor: AppTheme.textMutedWarm,
          selectedLabelStyle: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.outfit(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          onTap: (idx) => setState(() => _currentIndex = idx),
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.movie_creation_outlined), activeIcon: const Icon(Icons.movie_creation_rounded), label: langController.t('feed')),
            BottomNavigationBarItem(icon: const Icon(Icons.storefront_outlined), activeIcon: const Icon(Icons.storefront_rounded), label: langController.t('marketplace')),
            BottomNavigationBarItem(icon: const Icon(Icons.pets_outlined), activeIcon: const Icon(Icons.pets_rounded), label: langController.t('profile')),
            BottomNavigationBarItem(icon: const Icon(Icons.card_giftcard_outlined), activeIcon: const Icon(Icons.card_giftcard_rounded), label: langController.t('rewards')),
          ],
        ),
      ),
    );
  }

  Widget _buildTikTokFeedTab(FeedController feedController, String currentUserId, AuthController authController, LanguageController langController) {
    if (feedController.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryTerracotta));
    }

    if (feedController.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets_rounded, size: 64, color: AppTheme.textMutedWarm),
            const SizedBox(height: 12),
            Text(langController.t('noActivePosts'), style: GoogleFonts.outfit(color: AppTheme.textMutedWarm)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => feedController.fetchActivePosts(),
              child: Text(langController.t('refreshFeed'), style: GoogleFonts.fredoka()),
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

        // Top Overlay Header (Pawly Warm Style)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pets_rounded, color: AppTheme.accentOrange, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'Pawtbook',
                      style: GoogleFonts.fredoka(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          const Shadow(color: Colors.black45, blurRadius: 8),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const LanguageSelector(isDark: true),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.stars_rounded, color: AppTheme.accentOrange, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${authController.currentProfile?.pawtScore ?? 100} pts',
                            style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
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

  Widget _buildHumanProfileTab(AuthController authController, LanguageController langController) {
    return Scaffold(
      backgroundColor: AppTheme.bgWarmCream,
      appBar: AppBar(
        backgroundColor: AppTheme.bgWarmCream,
        elevation: 0,
        title: Text(
          langController.t('humanProfile'),
          style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: langController.t('logOut'),
            onPressed: () {
              authController.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 44,
                backgroundColor: AppTheme.surfaceWarm,
                child: Icon(Icons.person_rounded, size: 48, color: AppTheme.primaryTerracotta),
              ),
              const SizedBox(height: 16),
              Text(
                authController.currentProfile?.username ?? '@tutor_human',
                style: GoogleFonts.fredoka(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
              ),
              const SizedBox(height: 6),
              Text(
                'Wallet: ${authController.currentProfile?.walletAddress ?? "Not connected"}',
                style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWarm,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.borderWarm),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryTerracotta.withOpacity(0.06),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.pets_rounded, size: 52, color: AppTheme.accentOrange),
                    const SizedBox(height: 12),
                    Text(
                      langController.t('doYouHaveAPet'),
                      style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      langController.t('registerPetPrompt'),
                      style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      label: Text(langController.t('registerCreatorPet'), style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTerracotta,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
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
              const SizedBox(height: 28),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text(
                  langController.t('logOut'),
                  style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  authController.logout();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
