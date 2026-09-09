import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../controllers/language_controller.dart';
import '../../models/pet_model.dart';
import '../../theme/app_theme.dart';
import '../../models/post_model.dart';
import '../widgets/sponsorship_modal.dart';
import 'login_screen.dart';

class PetProfileScreen extends StatefulWidget {
  final PetModel pet;
  final VoidCallback? onSwitchToHuman;

  const PetProfileScreen({super.key, required this.pet, this.onSwitchToHuman});

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  bool _isVerifyingNft = false;
  String? _verifiedNftAddress;
  bool _isFollowing = false;
  bool _isUploadingAvatar = false;
  Future<List<PostModel>>? _postsFuture;

  Future<void> _pickAndChangePetAvatar(AuthController authController) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );

    if (pickedFile == null) return;

    setState(() => _isUploadingAvatar = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final bytes = await pickedFile.readAsBytes();
      final filename = pickedFile.name.isNotEmpty ? pickedFile.name : 'avatar.jpg';

      final success = await authController.updatePetAvatarR2(
        petId: widget.pet.id,
        imageBytes: bytes,
        filename: filename,
      );

      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        if (success) {
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.emeraldGreen,
              duration: const Duration(seconds: 3),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🎉 ¡Foto de perfil de ${widget.pet.name} actualizada con éxito!',
                      style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text(
                '❌ No se pudo actualizar la foto de perfil. Intenta de nuevo.',
                style: GoogleFonts.fredoka(color: Colors.white),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('❌ Error al procesar la imagen seleccionada.', style: GoogleFonts.fredoka(color: Colors.white)),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _verifiedNftAddress = widget.pet.nftMintAddress;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthController>(context, listen: false);
      final feed = Provider.of<FeedController>(context, listen: false);
      if (auth.currentProfile != null) {
        feed.getFollowedPets(auth.currentProfile!.id).then((pets) {
          if (mounted) setState(() => _isFollowing = pets.any((p) => p.id == widget.pet.id));
        });
      }
      setState(() {
        _postsFuture = feed.getPostsForPet(widget.pet.id, currentUserId: auth.currentProfile?.id);
      });
    });
  }

  Future<void> _verifySolanaWalletNft(AuthController authController) async {
    setState(() => _isVerifyingNft = true);

    await Future.delayed(const Duration(milliseconds: 1200));

    final walletAddress = authController.currentProfile?.walletAddress ?? '8szRk9h4k1i5e2hGjVjK3f7g1f888888888888888888';
    final mockVerifiedNft = 'SolNFT_${widget.pet.name}_${walletAddress.substring(0, 6)}';

    setState(() {
      _verifiedNftAddress = mockVerifiedNft;
      _isVerifyingNft = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.emeraldGreen,
          content: Text(
            '⚡ ¡NFT de Solana verificado con éxito en tu wallet! ($mockVerifiedNft)',
            style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedController = Provider.of<FeedController>(context);
    final authController = Provider.of<AuthController>(context);
    final langController = Provider.of<LanguageController>(context);
    final isOwner = (authController.currentProfile != null && widget.pet.ownerId == authController.currentProfile!.id) ||
        authController.activePet?.id == widget.pet.id ||
        authController.userPets.any((p) => p.id == widget.pet.id);

    return Scaffold(
      backgroundColor: AppTheme.bgWarmCream,
      appBar: AppBar(
        backgroundColor: AppTheme.bgWarmCream,
        elevation: 0,
        title: Text(
          widget.pet.name,
          style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta, fontSize: 22),
        ),
        actions: [
          if (isOwner && widget.onSwitchToHuman != null)
            IconButton(
              icon: const Icon(Icons.person_pin_rounded, color: AppTheme.primaryTerracotta, size: 28),
              tooltip: 'Cambiar a Perfil Humano (Tutor)',
              onPressed: widget.onSwitchToHuman,
            ),
          if (isOwner)
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
        child: Column(
          children: [
            // Switch to Human Profile Banner (Visible for owner)
            if (isOwner)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWarm,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderWarm),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primaryTerracotta,
                      backgroundImage: (authController.currentProfile?.avatarUrl != null && authController.currentProfile!.avatarUrl!.isNotEmpty)
                          ? NetworkImage(authController.currentProfile!.avatarUrl!)
                          : null,
                      child: (authController.currentProfile?.avatarUrl == null || authController.currentProfile!.avatarUrl!.isEmpty)
                          ? const Icon(Icons.person, color: Colors.white, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '👤 Tutor: ${authController.currentProfile?.fullName ?? authController.currentProfile?.username ?? "Humano"}',
                            style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '🏆 PawtScore: ${authController.currentProfile?.pawtScore ?? 0} pts (Patrocinador)',
                            style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTerracotta,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.switch_account_rounded, size: 16),
                      label: Text('Humano', style: GoogleFonts.fredoka(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: widget.onSwitchToHuman ?? () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            // Header Hero Card (Pawly Warm Style)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWarm,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppTheme.borderWarm),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryTerracotta.withOpacity(0.08),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Interactive Pet Avatar with Edit Badge for Owner
                  Builder(builder: (_) {
                    final currentPetAvatar = (isOwner && authController.activePet?.id == widget.pet.id)
                        ? (authController.activePet!.avatarUrl.isNotEmpty ? authController.activePet!.avatarUrl : widget.pet.avatarUrl)
                        : (authController.userPets.any((p) => p.id == widget.pet.id)
                            ? (authController.userPets.firstWhere((p) => p.id == widget.pet.id).avatarUrl)
                            : widget.pet.avatarUrl);

                    return Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 54,
                          backgroundColor: AppTheme.primaryTerracotta.withOpacity(0.15),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: AppTheme.cardWarm,
                            backgroundImage: NetworkImage(
                              currentPetAvatar.isNotEmpty
                                  ? currentPetAvatar
                                  : 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=400',
                            ),
                            child: _isUploadingAvatar
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.55),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 30,
                                        height: 30,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        if (isOwner)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isUploadingAvatar ? null : () => _pickAndChangePetAvatar(authController),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppTheme.primaryTerracotta, AppTheme.accentOrange],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryTerracotta.withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                  const SizedBox(height: 12),
                  Text(
                    widget.pet.name,
                    style: GoogleFonts.fredoka(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentOrange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${widget.pet.species} • ${widget.pet.breed}',
                          style: GoogleFonts.fredoka(color: AppTheme.accentOrange, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.pet.bio,
                    style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  
                  if (!isOwner && authController.isAuthenticated) ...[
                    Builder(builder: (_) {
                      final isFollowing = feedController.isFollowingPet(widget.pet.id) || _isFollowing;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFollowing ? AppTheme.surfaceWarm : AppTheme.primaryTerracotta,
                              foregroundColor: isFollowing ? AppTheme.primaryTerracotta : Colors.white,
                              elevation: isFollowing ? 0 : 2,
                              side: BorderSide(color: AppTheme.primaryTerracotta, width: isFollowing ? 1 : 0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            icon: Icon(isFollowing ? Icons.check_rounded : Icons.person_add_rounded),
                            label: Text(isFollowing ? 'Siguiendo' : 'Seguir', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final myId = authController.currentProfile!.id;
                              if (isFollowing) {
                                await feedController.unfollowPet(myId, widget.pet.id);
                                setState(() => _isFollowing = false);
                              } else {
                                await feedController.followPet(myId, widget.pet.id);
                                setState(() => _isFollowing = true);
                              }
                            },
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentOrange,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            icon: const Icon(Icons.volunteer_activism_rounded),
                            label: Text('Patrocinar', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              SponsorshipModal.show(context, pet: widget.pet, userId: authController.currentProfile!.id);
                            },
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 18),
                  ],

                  // Solana Dynamic Wallet Card for this Pet
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.4), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.emeraldGreen, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Wallet Solana (Dynamic.xyz):',
                                  style: GoogleFonts.fredoka(color: AppTheme.emeraldGreen, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.emeraldGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Activa ⚡',
                                style: GoogleFonts.fredoka(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.pet.dynamicWalletAddress,
                                style: GoogleFonts.sourceCodePro(
                                  color: AppTheme.textPrimaryDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.emeraldGreen),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Copiar Wallet',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: widget.pet.dynamicWalletAddress));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppTheme.emeraldGreen,
                                    duration: const Duration(seconds: 2),
                                    content: Text('⚡ ¡Wallet de @${widget.pet.name} copiada al portapapeles! (${widget.pet.dynamicWalletAddress})'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Solana NFT Badge & Verification Button Section
                  if (_verifiedNftAddress != null && _verifiedNftAddress!.isNotEmpty && !_verifiedNftAddress!.contains('SolMint')) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.emeraldGreen),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, color: AppTheme.emeraldGreen, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            'NFT de Solana Verificado 🐾',
                            style: GoogleFonts.fredoka(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    // Button to verify Solana NFT directly in wallet!
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.solanaPurple,
                          side: const BorderSide(color: AppTheme.solanaPurple, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        icon: _isVerifyingNft
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.solanaPurple))
                            : const Icon(Icons.verified_rounded, size: 18),
                        label: Text(
                          _isVerifyingNft ? 'Escaneando Wallet...' : 'Verificar NFT de Solana en Wallet',
                          style: GoogleFonts.fredoka(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isVerifyingNft ? null : () => _verifySolanaWalletNft(authController),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Stats Row
                  FutureBuilder<List<PostModel>>(
                    future: _postsFuture,
                    builder: (context, snapshot) {
                      final postsCount = snapshot.data?.length ?? 0;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatColumn('PawtScore', '${widget.pet.totalSponsoredScore} pts', AppTheme.accentOrange),
                          _buildStatColumn('Publicaciones', '$postsCount', AppTheme.primaryTerracotta),
                        ],
                      );
                    },
                  ),
                  if (!isOwner) ...[
                    const SizedBox(height: 18),
                    // Sponsor Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryTerracotta,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                        icon: const Icon(Icons.volunteer_activism_rounded, color: Colors.white),
                        label: Text(
                          '${langController.t('sponsor')} ${widget.pet.name}',
                          style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: () {
                          SponsorshipModal.show(
                            context,
                            pet: widget.pet,
                            userId: authController.currentProfile?.id ?? 'usr_demo',
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Logout Red Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  ),
                ],
              ),
            ),

            // Pet Posts Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Publicaciones de ${widget.pet.name}',
                  style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
                ),
              ),
            ),

            FutureBuilder<List<PostModel>>(
              future: _postsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primaryTerracotta)),
                  );
                }
                
                final petPosts = snapshot.data ?? [];

                if (petPosts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Esta mascota aún no tiene publicaciones activas.',
                      style: GoogleFonts.outfit(color: AppTheme.textMutedWarm),
                    ),
                  );
                }
                  
                return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: petPosts.length,
                itemBuilder: (context, index) {
                  final post = petPosts[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      color: AppTheme.surfaceWarm,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            post.mediaUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.pets_rounded, color: AppTheme.primaryTerracotta),
                            ),
                          ),
                          if (isOwner)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: AppTheme.surfaceWarm,
                                        title: Text('Eliminar publicación', style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark)),
                                        content: Text('¿Estás seguro de que quieres eliminar esta publicación?', style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark)),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: Text('Cancelar', style: GoogleFonts.fredoka(color: AppTheme.textMutedWarm)),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              feedController.deletePetPost(post.id);
                                              setState(() {
                                                _postsFuture = feedController.getPostsForPet(widget.pet.id, currentUserId: authController.currentProfile?.id);
                                              });
                                            },
                                            child: Text('Eliminar', style: GoogleFonts.fredoka(color: Colors.redAccent)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMutedWarm),
        ),
      ],
    );
  }
}
