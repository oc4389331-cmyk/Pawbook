import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../controllers/language_controller.dart';
import '../../services/r2_storage_service.dart';
import '../../services/render_backend_service.dart';
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
  bool _hasShownRegisterWall = false;

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

  void _showTikTokRegistrationWall(BuildContext context, AuthController authController) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.bgWarmCream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppTheme.borderWarm,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 20),

              // Hero Paw Circle Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWarm,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.cardWarm, width: 2),
                ),
                child: const Icon(
                  Icons.pets_rounded,
                  size: 48,
                  color: AppTheme.primaryTerracotta,
                ),
              ),
              const SizedBox(height: 18),

              Text(
                '¡Únete a la comunidad Pawtbook! 🐾',
                style: GoogleFonts.fredoka(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTerracotta,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Has disfrutado de los primeros videos. Para continuar la experiencia, dar likes, comentar, patrocinar y ganar PawtScore, crea tu cuenta gratis.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppTheme.textMutedWarm,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Option 1: Human Account (Sponsor)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTerracotta,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                  icon: const Icon(Icons.person_outline_rounded, color: Colors.white),
                  label: Text(
                    '👤 Crear / Entrar Cuenta de Humano',
                    style: GoogleFonts.fredoka(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Option 2: Pet Creator Account
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                  icon: const Icon(Icons.pets_rounded, color: Colors.white),
                  label: Text(
                    '🐾 Registrar Perfil de Mascota (Creador)',
                    style: GoogleFonts.fredoka(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreatePetScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Option 3: Continue Watching as Guest
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Seguir viendo videos por ahora 🐾',
                  style: GoogleFonts.fredoka(color: AppTheme.textMutedWarm, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditHumanProfileModal(BuildContext context, AuthController authController) {
    final profile = authController.currentProfile;
    final usernameController = TextEditingController(text: profile?.username ?? '');
    final fullNameController = TextEditingController(text: profile?.fullName ?? '');
    final avatarUrlController = TextEditingController(text: profile?.avatarUrl ?? '');
    final bioController = TextEditingController(text: profile?.bio ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final avatarInput = avatarUrlController.text.trim();

            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.bgWarmCream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.borderWarm,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '✏️ Editar Perfil Humano',
                      style: GoogleFonts.fredoka(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
                    ),
                    const SizedBox(height: 16),

                    // Avatar Circle Preview
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppTheme.surfaceWarm,
                      backgroundImage: avatarInput.isNotEmpty ? NetworkImage(avatarInput) : null,
                      child: avatarInput.isEmpty
                          ? const Icon(Icons.person_rounded, size: 44, color: AppTheme.primaryTerracotta)
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Button: Upload Photo to Cloudflare R2
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentOrange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 20),
                        label: const Text(
                          '📷 Seleccionar Foto (Cloudflare R2)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: () async {
                          try {
                            final picker = ImagePicker();
                            final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              final renderBackend = RenderBackendService();
                              final r2Service = R2StorageService();

                              final uploadRes = await renderBackend.requestUploadUrl(
                                petId: authController.currentProfile?.id ?? 'usr_human',
                                mediaType: 'image',
                                filename: image.name,
                              );

                              if (uploadRes['success'] == true) {
                                final presignedPutUrl = uploadRes['presignedPutUrl'] as String;
                                final publicUrl = uploadRes['publicUrl'] as String;

                                final uploadedUrl = await r2Service.uploadMediaWithPresignedUrl(
                                  presignedPutUrl: presignedPutUrl,
                                  publicUrl: publicUrl,
                                  bytes: bytes,
                                  contentType: 'image/jpeg',
                                );

                                setModalState(() {
                                  avatarUrlController.text = uploadedUrl;
                                });
                              }
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al subir imagen: $e')),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Input: URL de Foto de Perfil
                    TextField(
                      controller: avatarUrlController,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        labelText: 'URL de Foto de Perfil',
                        hintText: 'https://media.pawbooklife.com/...',
                        prefixIcon: const Icon(Icons.photo_camera_outlined, color: AppTheme.primaryTerracotta),
                        filled: true,
                        fillColor: AppTheme.surfaceWarm,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
          authController.isAuthenticated
              ? (authController.hasPet
                  ? PetProfileScreen(pet: authController.activePet!)
                  : _buildHumanProfileTab(authController, langController))
              : _buildGuestProfilePromptTab(authController, langController),

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
          onTap: (idx) {
            if (idx == 2 && !authController.isAuthenticated) {
              _showTikTokRegistrationWall(context, authController);
            } else {
              setState(() => _currentIndex = idx);
            }
          },
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
          onPageChanged: (index) {
            // Trigger Registration Wall after watching 3 videos for guests!
            if (!authController.isAuthenticated && index >= 3 && !_hasShownRegisterWall) {
              setState(() => _hasShownRegisterWall = true);
              _showTikTokRegistrationWall(context, authController);
            }
          },
          itemBuilder: (context, index) {
            final post = feedController.posts[index];
            return TikTokFeedItem(
              post: post,
              currentUserId: currentUserId,
              onLikeToggled: () {
                if (!authController.isAuthenticated) {
                  _showTikTokRegistrationWall(context, authController);
                } else {
                  setState(() {});
                }
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
                    GestureDetector(
                      onTap: () {
                        if (!authController.isAuthenticated) {
                          _showTikTokRegistrationWall(context, authController);
                        }
                      },
                      child: Container(
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

  Widget _buildGuestProfilePromptTab(AuthController authController, LanguageController langController) {
    return Scaffold(
      backgroundColor: AppTheme.bgWarmCream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceWarm,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pets_rounded, size: 64, color: AppTheme.primaryTerracotta),
              ),
              const SizedBox(height: 20),
              Text(
                '¡Crea tu perfil en Pawtbook! 🐾',
                style: GoogleFonts.fredoka(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Únete como humano patrocinador o registra a tu mascota para subir videos y ganar PawtScore.',
                style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTerracotta,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                  icon: const Icon(Icons.person_outline_rounded, color: Colors.white),
                  label: Text('👤 Iniciar Sesión / Registrar Humano', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                  icon: const Icon(Icons.pets_rounded, color: Colors.white),
                  label: Text('🐾 Registrar Mascota Creadora', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreatePetScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHumanProfileTab(AuthController authController, LanguageController langController) {
    final profile = authController.currentProfile;
    final avatarUrl = profile?.avatarUrl ?? '';
    final fullName = profile?.fullName;
    final bio = profile?.bio;

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
            icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryTerracotta),
            tooltip: 'Editar Perfil Humano',
            onPressed: () => _showEditHumanProfileModal(context, authController),
          ),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Human Avatar Image
            CircleAvatar(
              radius: 48,
              backgroundColor: AppTheme.surfaceWarm,
              backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty
                  ? const Icon(Icons.person_rounded, size: 52, color: AppTheme.primaryTerracotta)
                  : null,
            ),
            const SizedBox(height: 14),

            // Display Name & Username
            if (fullName != null && fullName.isNotEmpty) ...[
              Text(
                fullName,
                style: GoogleFonts.fredoka(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
              ),
              Text(
                profile?.username ?? '@tutor_human',
                style: GoogleFonts.outfit(fontSize: 15, color: AppTheme.textMutedWarm, fontWeight: FontWeight.w600),
              ),
            ] else ...[
              Text(
                profile?.username ?? '@tutor_human',
                style: GoogleFonts.fredoka(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
              ),
            ],

            if (bio != null && bio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  bio,
                  style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 6),
            Text(
              'Wallet: ${profile?.walletAddress ?? "Not connected"}',
              style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Edit Profile Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryTerracotta,
                side: const BorderSide(color: AppTheme.primaryTerracotta, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text('✏️ Editar Perfil Humano', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
              onPressed: () => _showEditHumanProfileModal(context, authController),
            ),
            const SizedBox(height: 24),

            // Pet Creator Card
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
            const SizedBox(height: 24),
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
    );
  }
}
