import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  const PetProfileScreen({super.key, required this.pet});

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  bool _isVerifyingNft = false;
  String? _verifiedNftAddress;
  bool _isFollowing = false;
  Future<List<PostModel>>? _postsFuture;

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

    final walletAddress = authController.currentProfile?.walletAddress ?? 'PawSolanaWallet';
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
    final isOwner = authController.activePet?.id == widget.pet.id;

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
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.cardWarm,
                    backgroundImage: NetworkImage(
                      widget.pet.avatarUrl.isNotEmpty
                          ? widget.pet.avatarUrl
                          : 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=400',
                    ),
                  ),
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
                  
                  if (!isOwner && authController.isAuthenticated)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowing ? AppTheme.surfaceWarm : AppTheme.primaryTerracotta,
                            foregroundColor: _isFollowing ? AppTheme.primaryTerracotta : Colors.white,
                            elevation: _isFollowing ? 0 : 2,
                            side: BorderSide(color: AppTheme.primaryTerracotta, width: _isFollowing ? 1 : 0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: Icon(_isFollowing ? Icons.check_rounded : Icons.person_add_rounded),
                          label: Text(_isFollowing ? 'Siguiendo' : 'Seguir', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final myId = authController.currentProfile!.id;
                            if (_isFollowing) {
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
                    ),
                  if (!isOwner && authController.isAuthenticated)
                    const SizedBox(height: 18),

                  // Solana NFT Badge & Verification Button Section
                  if (_verifiedNftAddress != null && _verifiedNftAddress!.isNotEmpty && !_verifiedNftAddress!.contains('SolMint')) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldGreen.withOpacity(0.12),
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
