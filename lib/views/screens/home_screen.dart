import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../controllers/language_controller.dart';
import '../../models/post_model.dart';
import '../../models/pet_model.dart';
import '../../models/comment_model.dart';
import '../../services/supabase_service.dart';
import '../../services/profanity_filter_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/language_selector.dart';
import '../widgets/tiktok_feed_item.dart';
import '../widgets/sponsorship_modal.dart';
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
  int _currentFeedPage = 0;
  final Set<String> _followedPetIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authController = Provider.of<AuthController>(context, listen: false);
      final feedController = Provider.of<FeedController>(context, listen: false);
      feedController.fetchActivePosts(currentUserId: authController.currentProfile?.id);
      if (authController.currentProfile != null) {
        feedController.getFollowedPets(authController.currentProfile!.id).then((pets) {
          if (mounted) {
            setState(() {
              _followedPetIds.addAll(pets.map((p) => p.id));
            });
          }
        });
      }
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

  void _showCommentsModal(BuildContext context, PostModel post, String currentUserId, AuthController authController, LanguageController langController) {
    final commentController = TextEditingController();
    final supabaseService = SupabaseService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              decoration: const BoxDecoration(
                color: AppTheme.bgWarmCream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Handle indicator
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.borderWarm,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '💬 ${langController.t("comments")}',
                          style: GoogleFonts.fredoka(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryTerracotta,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppTheme.textMutedWarm, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: AppTheme.borderWarm, height: 1),

                  // Comments List
                  Expanded(
                    child: FutureBuilder<List<CommentModel>>(
                      future: supabaseService.getCommentsForPost(post.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: AppTheme.primaryTerracotta, strokeWidth: 2),
                          );
                        }
                        final comments = snapshot.data ?? [];
                        if (comments.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppTheme.textMutedWarm),
                                  const SizedBox(height: 12),
                                  Text(
                                    '¡Sé el primero en comentar esta publicación! 🐾',
                                    style: GoogleFonts.fredoka(color: AppTheme.textMutedWarm, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: comments.length,
                          itemBuilder: (context, idx) {
                            final c = comments[idx];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppTheme.surfaceWarm,
                                    child: Text(
                                      (c.username != null && c.username!.isNotEmpty)
                                          ? c.username![0].toUpperCase()
                                          : 'P',
                                      style: GoogleFonts.fredoka(
                                        color: AppTheme.primaryTerracotta,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.username ?? '@usuario',
                                          style: GoogleFonts.fredoka(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppTheme.primaryTerracotta,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          c.content,
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            color: AppTheme.textPrimaryDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Bottom Comment Input Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(
                      color: AppTheme.surfaceWarm,
                      border: Border(top: BorderSide(color: AppTheme.borderWarm, width: 1)),
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.bgWarmCream,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppTheme.borderWarm),
                              ),
                              child: TextField(
                                controller: commentController,
                                style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textPrimaryDark),
                                decoration: InputDecoration(
                                  hintText: authController.isAuthenticated
                                      ? 'Añadir un comentario amable... 🐾'
                                      : 'Inicia sesión para comentar... 🐾',
                                  hintStyle: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 13),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppTheme.primaryTerracotta, AppTheme.accentOrange],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                              onPressed: () async {
                                if (!authController.isAuthenticated) {
                                  Navigator.pop(ctx);
                                  _showTikTokRegistrationWall(context, authController);
                                  return;
                                }

                                final text = commentController.text.trim();
                                if (text.isEmpty) return;

                                if (ProfanityFilterService.hasProfanity(text)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppTheme.primaryTerracotta,
                                      content: Text(
                                        '⚠️ ${langController.t("profanityWarning")}',
                                        style: GoogleFonts.fredoka(color: Colors.white),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final sanitized = ProfanityFilterService.sanitize(text);
                                commentController.clear();
                                await supabaseService.addComment(currentUserId, post.id, sanitized);
                                if (mounted) {
                                  setState(() {});
                                  setModalState(() {});
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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
                      backgroundImage: avatarInput.isNotEmpty
                          ? (avatarInput.startsWith('data:')
                              ? MemoryImage(base64Decode(avatarInput.split(',').last)) as ImageProvider
                              : NetworkImage(avatarInput))
                          : null,
                      child: avatarInput.isEmpty
                          ? const Icon(Icons.person_rounded, size: 44, color: AppTheme.primaryTerracotta)
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Button: Pick Image from Desktop/Device
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentOrange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        icon: const Icon(Icons.desktop_windows_rounded, color: Colors.white, size: 20),
                        label: const Text(
                          '🖥️ Buscar Imagen en Escritorio',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: () async {
                          try {
                            final picker = ImagePicker();
                            final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              final base64Preview = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                              setModalState(() {
                                avatarUrlController.text = base64Preview;
                              });

                              // Upload immediately to Cloudflare R2 and delete old photo
                              final uploadedUrl = await authController.updateProfileAvatarR2(bytes, image.name);
                              if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                                setModalState(() {
                                  avatarUrlController.text = uploadedUrl;
                                });

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: AppTheme.emeraldGreen,
                                      content: Text('☁️ ¡Foto actualizada en Cloudflare R2 y anterior eliminada exitosamente! 🗑️'),
                                    ),
                                  );
                                }
                              }
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al buscar/subir imagen: $e')),
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
                        labelText: 'URL de Foto de Perfil (Cloudflare R2)',
                        hintText: 'https://media.pawbooklife.com/avatars/...',
                        prefixIcon: const Icon(Icons.photo_camera_outlined, color: AppTheme.primaryTerracotta),
                        filled: true,
                        fillColor: AppTheme.surfaceWarm,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Input: Nombre Completo
                    TextField(
                      controller: fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre Completo',
                        hintText: 'Ej. Juan Pérez',
                        prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.primaryTerracotta),
                        filled: true,
                        fillColor: AppTheme.surfaceWarm,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Input: Nombre de Usuario
                    TextField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre de Usuario',
                        hintText: 'Ej. @juan_pawt',
                        prefixIcon: const Icon(Icons.alternate_email_rounded, color: AppTheme.primaryTerracotta),
                        filled: true,
                        fillColor: AppTheme.surfaceWarm,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Input: Biografía
                    TextField(
                      controller: bioController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Biografía / Acerca de ti',
                        hintText: 'Amante de las mascotas y tutor de Firulais 🐾',
                        prefixIcon: const Icon(Icons.description_outlined, color: AppTheme.primaryTerracotta),
                        filled: true,
                        fillColor: AppTheme.surfaceWarm,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save Changes & Cancel Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('Cancelar', style: GoogleFonts.fredoka(color: AppTheme.textMutedWarm, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryTerracotta,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            icon: const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                            label: authController.isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text('💾 Guardar Cambios', style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: authController.isLoading
                                ? null
                                : () async {
                                    final ok = await authController.updateCurrentProfile(
                                      fullName: fullNameController.text.trim(),
                                      username: usernameController.text.trim(),
                                      avatarUrl: avatarUrlController.text.trim(),
                                      bio: bioController.text.trim(),
                                    );
                                    if (ok && ctx.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('¡Perfil actualizado y guardado exitosamente! ✨'),
                                          backgroundColor: AppTheme.emeraldGreen,
                                        ),
                                      );
                                    } else if (ctx.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(authController.errorMessage ?? 'Error al guardar. Verifica la consola.'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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

    if (authController.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final msg = authController.errorMessage;
        if (msg != null && mounted) {
          authController.clearError();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.primaryTerracotta,
              duration: const Duration(seconds: 5),
              content: Text(
                msg,
                style: GoogleFonts.fredoka(color: Colors.white, fontSize: 14),
              ),
              action: SnackBarAction(
                label: 'Ir a Login',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
            ),
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.bgWarmCream,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: TikTok Style Vertical Feed
          _buildTikTokFeedTab(feedController, currentUserId, authController, langController),

          // Tab 1: Marketplace (Exclusive Bandanas)
          const MarketplaceScreen(),

          // Tab 2: Profile (Switchable between Pet Profile and Human Tutor Profile)
          authController.isAuthenticated
              ? (authController.isPetModeActive && authController.activePet != null
                  ? PetProfileScreen(
                      pet: authController.activePet!,
                      onSwitchToHuman: () {
                        authController.setPetModeActive(false);
                      },
                    )
                  : _buildHumanProfileTab(
                      authController,
                      langController,
                      onSwitchToPet: authController.hasPet
                          ? () {
                              authController.setPetModeActive(true);
                            }
                          : null,
                    ))
              : _buildGuestProfilePromptTab(authController, langController),

          // Tab 3: Rewards Store
          const RewardsStoreScreen(),
        ],
      ),

      // Floating Action Button (+ Video): ONLY visible when in Pet Creator Mode (Hidden in Human Profile Mode)
      floatingActionButton: (authController.isAuthenticated && authController.isPetModeActive)
          ? FloatingActionButton.extended(
              key: const ValueKey('fab_pet_mode'),
              backgroundColor: AppTheme.primaryTerracotta,
              elevation: 8,
              icon: const Icon(Icons.videocam_rounded, color: Colors.white),
              label: Text(
                '+ Video (@${authController.activePet?.name ?? "Mascota"})',
                style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
              ),
              tooltip: 'Publicar video como @${authController.activePet?.name ?? "Mascota"}',
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
              onPressed: () => feedController.fetchActivePosts(currentUserId: authController.currentProfile?.id),
              child: Text(langController.t('refreshFeed'), style: GoogleFonts.fredoka()),
            ),
          ],
        ),
      );
    }

    final currentPost = feedController.posts.isNotEmpty ? feedController.posts[_currentFeedPage] : null;

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Stack(
          children: [
            // Vertical PageView (TikTok Style) — only background media
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: feedController.posts.length,
              onPageChanged: (index) {
                setState(() => _currentFeedPage = index);
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

            // Top Overlay Header — placed FIRST so sidebar renders on top
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

            // ACTION SIDEBAR — rendered AFTER header so it appears on top
            if (currentPost != null)
              Positioned(
                right: 14,
                bottom: 110,
                child: _buildActionSidebar(currentPost, currentUserId, authController, langController, feedController),
              ),

            // BOTTOM LEFT INFO — also rendered after header
            if (currentPost != null)
              Positioned(
                left: 16,
                bottom: 30,
                right: 90,
                child: _buildBottomInfo(currentPost),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSidebar(PostModel post, String currentUserId, AuthController authController, LanguageController langController, FeedController feedController) {
    final isOwner = authController.activePet?.id == post.petId;
    final isLiked = post.isLikedByCurrentUser;
    final likesCount = post.likesCount;
    final isFollowing = feedController.isFollowingPet(post.petId) || _followedPetIds.contains(post.petId);
    final petAvatar = post.petAvatarUrl ?? 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=200';

    return Column(
      children: [
        // --- Pet Profile Avatar with Follow Badge ---
        SizedBox(
          width: 64,
          height: 72,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              // Avatar Tap -> Opens Pet Profile Screen
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PetProfileScreen(pet: post.toPetModel())),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    color: AppTheme.emeraldGreen,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(petAvatar),
                  ),
                ),
              ),

              // Plus (+) / Check (✓) Follow Button Badge
              if (!isOwner)
                Positioned(
                  bottom: 6,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      if (!authController.isAuthenticated) {
                        _showTikTokRegistrationWall(context, authController);
                        return;
                      }
                      if (isFollowing) {
                        await feedController.unfollowPet(currentUserId, post.petId);
                        _followedPetIds.remove(post.petId);
                        if (mounted) {
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Dejaste de seguir a @${post.petName ?? "mascota"}'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } else {
                        await feedController.followPet(currentUserId, post.petId);
                        _followedPetIds.add(post.petId);
                        if (mounted) {
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.emeraldGreen,
                              content: Text('🐾 ¡Ahora sigues a @${post.petName ?? "mascota"}!'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: BoxDecoration(
                        color: isFollowing ? AppTheme.emeraldGreen : AppTheme.primaryTerracotta,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        isFollowing ? Icons.check : Icons.add,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // --- Like Button ---
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!authController.isAuthenticated) {
              _showTikTokRegistrationWall(context, authController);
              return;
            }
            feedController.toggleLikePost(currentUserId, post.id);
            setState(() {});
          },
          child: Column(
            children: [
              Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? const Color(0xFFEF4444) : Colors.white,
                size: 36,
              ),
              const SizedBox(height: 4),
              Text('$likesCount', style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // --- Comment Button ---
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _showCommentsModal(context, post, currentUserId, authController, langController);
          },
          child: Column(
            children: [
              const Icon(Icons.comment_rounded, color: Colors.white, size: 34),
              const SizedBox(height: 4),
              Text('${post.commentsCount}', style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // --- Views ---
        Column(
          children: [
            const Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 30),
            const SizedBox(height: 4),
            Text('${post.viewsCount}', style: GoogleFonts.fredoka(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 22),

        // --- More Options ---
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: AppTheme.bgWarmCream,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 40, height: 5, decoration: BoxDecoration(color: AppTheme.borderWarm, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(height: 20),
                    if (isOwner)
                      ListTile(
                        leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        title: Text('Eliminar publicación', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await feedController.deletePetPost(post.id);
                          if (mounted) setState(() {});
                        },
                      )
                    else
                      ListTile(
                        leading: const Icon(Icons.report_problem_outlined, color: Colors.orange),
                        title: Text('Reportar / Bloquear', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: Colors.orange)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await feedController.reportPost(post.id, userId: currentUserId);
                          if (mounted) setState(() {});
                        },
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
          child: const Column(
            children: [
              Icon(Icons.more_vert_rounded, color: Colors.white, size: 30),
              SizedBox(height: 4),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // --- Sponsor Button ---
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            SponsorshipModal.show(context, pet: post.toPetModel(), userId: currentUserId);
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryTerracotta, AppTheme.accentOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppTheme.primaryTerracotta.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)],
            ),
            child: const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 4),
        Text(langController.t('sponsor'), style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
      ],
    );
  }

  Widget _buildBottomInfo(PostModel post) {
    final petName = post.petName ?? 'Mascota';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PetProfileScreen(pet: post.toPetModel())),
                );
              },
              child: Text(
                '@$petName',
                style: GoogleFonts.fredoka(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            if (post.nftMintAddress != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.solanaPurple.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.solanaPurple),
                ),
                child: Text('Solana NFT 🐾', style: GoogleFonts.fredoka(color: AppTheme.solanaGreen, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(post.caption, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
        if (post.tags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: post.tags.map((t) => Text('#$t', style: GoogleFonts.fredoka(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 12))).toList(),
          ),
        ],
      ],
    );
  }


  Widget _buildGuestProfilePromptTab(AuthController authController, LanguageController langController) {
    return Scaffold(
      backgroundColor: AppTheme.bgWarmCream,
      appBar: AppBar(
        backgroundColor: AppTheme.bgWarmCream,
        elevation: 0,
        title: Text(
          langController.t('profile'),
          style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta, fontSize: 22),
        ),
      ),
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

  Widget _buildHumanProfileTab(AuthController authController, LanguageController langController, {VoidCallback? onSwitchToPet}) {
    final profile = authController.currentProfile;
    final avatarUrl = profile?.avatarUrl ?? '';
    final fullName = profile?.fullName;
    final bio = profile?.bio;
    final feedController = Provider.of<FeedController>(context, listen: false);

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
          if (authController.hasPet && onSwitchToPet != null)
            IconButton(
              icon: const Icon(Icons.pets_rounded, color: AppTheme.primaryTerracotta, size: 26),
              tooltip: 'Cambiar a Perfil de Mascota (@${authController.activePet?.name ?? "Mascota"})',
              onPressed: onSwitchToPet,
            ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryTerracotta),
            tooltip: 'Editar Perfil Humano',
            onPressed: () => _showEditHumanProfileModal(context, authController),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: langController.t('logOut'),
            onPressed: () async {
              await authController.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Switcher to Pet Profile Banner (if user has pets)
            if (authController.hasPet && onSwitchToPet != null)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryTerracotta, AppTheme.accentOrange],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryTerracotta.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(
                        (authController.activePet?.avatarUrl != null && authController.activePet!.avatarUrl.isNotEmpty)
                            ? authController.activePet!.avatarUrl
                            : 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=200',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🐾 Modo Mascota Creadora',
                            style: GoogleFonts.fredoka(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Perfil de @${authController.activePet?.name ?? "Mascota"}',
                            style: GoogleFonts.fredoka(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryTerracotta,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: onSwitchToPet,
                      child: Text(
                        'Ver Mascota 🐾',
                        style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
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

            // --- Section: Followed Pets (Mascotas que sigo) ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWarm,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.borderWarm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pets_rounded, color: AppTheme.primaryTerracotta, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        '🐾 Mascotas que sigo',
                        style: GoogleFonts.fredoka(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTerracotta,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (profile != null)
                    FutureBuilder<List<PetModel>>(
                      future: feedController.getFollowedPets(profile.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(color: AppTheme.primaryTerracotta, strokeWidth: 2),
                            ),
                          );
                        }
                        final followedPets = snapshot.data ?? [];
                        if (followedPets.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                'Aún no sigues a ninguna mascota.\n¡Toca el botón + en los videos del feed para seguir a tus creadores favoritos! 🐾',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 13),
                              ),
                            ),
                          );
                        }
                        return SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: followedPets.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 14),
                            itemBuilder: (context, idx) {
                              final pet = followedPets[idx];
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => PetProfileScreen(pet: pet)),
                                  );
                                },
                                child: Container(
                                  width: 88,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgWarmCream,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.borderWarm),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 26,
                                        backgroundImage: NetworkImage(
                                          pet.avatarUrl.isNotEmpty
                                              ? pet.avatarUrl
                                              : 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=200',
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        pet.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.fredoka(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppTheme.primaryTerracotta,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- Section: Algorithm & Content Preferences ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWarm,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.borderWarm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: AppTheme.accentOrange, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        '🎯 Preferencias de Contenido (Algoritmo)',
                        style: GoogleFonts.fredoka(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTerracotta,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Basado en los videos que ves, likes y las mascotas que sigues, el algoritmo de Pawtbook prioriza estos animales en tu feed:',
                    style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (profile?.favoriteSpecies.isNotEmpty ?? false)
                        ? profile!.favoriteSpecies.map((species) {
                            String emoji = '🐾';
                            if (species.toLowerCase().contains('dog') || species.toLowerCase().contains('perro')) emoji = '🐕';
                            if (species.toLowerCase().contains('cat') || species.toLowerCase().contains('gato')) emoji = '🐱';
                            if (species.toLowerCase().contains('bird') || species.toLowerCase().contains('ave')) emoji = '🦜';
                            if (species.toLowerCase().contains('rabbit') || species.toLowerCase().contains('conejo')) emoji = '🐰';

                            return Chip(
                              backgroundColor: AppTheme.primaryTerracotta.withOpacity(0.12),
                              side: const BorderSide(color: AppTheme.primaryTerracotta),
                              avatar: Text(emoji, style: const TextStyle(fontSize: 16)),
                              label: Text(
                                species,
                                style: GoogleFonts.fredoka(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryTerracotta,
                                  fontSize: 13,
                                ),
                              ),
                            );
                          }).toList()
                        : [
                            Chip(
                              backgroundColor: AppTheme.surfaceWarm,
                              side: const BorderSide(color: AppTheme.borderWarm),
                              avatar: const Text('🐕', style: TextStyle(fontSize: 16)),
                              label: Text('Perros (Principal)', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark, fontSize: 13)),
                            ),
                            Chip(
                              backgroundColor: AppTheme.surfaceWarm,
                              side: const BorderSide(color: AppTheme.borderWarm),
                              avatar: const Text('🐱', style: TextStyle(fontSize: 16)),
                              label: Text('Gatos', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark, fontSize: 13)),
                            ),
                          ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Pet Creator Card (Only shown if user has NOT registered a pet yet - Max 1 pet per user)
            if (!authController.hasPet) ...[
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
            ],
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
              onPressed: () async {
                await authController.logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
