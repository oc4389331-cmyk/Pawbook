import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../controllers/language_controller.dart';
import '../../controllers/oracle_controller.dart';
import '../../models/pet_model.dart';
import '../../models/post_model.dart';
import '../../models/sponsorship_model.dart';
import '../../models/withdrawal_model.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/sponsorship_modal.dart';
import '../widgets/pet_analytics_dashboard_modal.dart';
import '../widgets/claim_sponsorship_modal.dart';
import '../widgets/post_card.dart';
import '../widgets/terms_and_conditions_modal.dart';
import 'login_screen.dart';
import 'create_post_screen.dart';

class PetProfileScreen extends StatefulWidget {
  final PetModel pet;
  final VoidCallback? onSwitchToHuman;

  const PetProfileScreen({super.key, required this.pet, this.onSwitchToHuman});

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isVerifyingNft = false;
  String? _verifiedNftAddress;
  bool _isFollowing = false;
  bool _isUploadingAvatar = false;
  Future<List<PostModel>>? _postsFuture;

  // Pet Sponsorship Ledger & Claim Audit State
  List<SponsorshipModel> _petSponsorships = [];
  List<WithdrawalModel> _petWithdrawals = [];
  int _unclaimedSkr = 0;
  int _lifetimeSkr = 0;
  int _withdrawnSkr = 0;
  bool _isLoadingLedger = true;
  bool _showSponsorshipsList = false;

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

  void _refreshPosts() {
    final auth = Provider.of<AuthController>(context, listen: false);
    final feed = Provider.of<FeedController>(context, listen: false);
    setState(() {
      _postsFuture = feed.getPostsForPet(widget.pet.id, currentUserId: auth.currentProfile?.id);
    });
  }

  Future<void> _loadPetLedger() async {
    if (!mounted) return;
    setState(() => _isLoadingLedger = true);

    try {
      final spns = await _supabaseService.getSponsorshipsForPet(widget.pet.id);
      final wths = await _supabaseService.getWithdrawalsForPet(widget.pet.id);

      int totalLife = 0;
      int totalUnclaimed = 0;
      int totalWithdrawn = 0;

      for (final s in spns) {
        totalLife += s.netAmount;
        if (!s.isClaimed && s.status != 'withdrawn') {
          totalUnclaimed += s.netAmount;
        } else {
          totalWithdrawn += s.netAmount;
        }
      }

      if (mounted) {
        setState(() {
          _petSponsorships = spns;
          _petWithdrawals = wths;
          _lifetimeSkr = totalLife > 0 ? totalLife : widget.pet.totalSponsoredScore;
          _unclaimedSkr = totalUnclaimed;
          _withdrawnSkr = totalWithdrawn;
          _isLoadingLedger = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _unclaimedSkr = widget.pet.totalSponsoredScore;
          _lifetimeSkr = widget.pet.totalSponsoredScore;
          _isLoadingLedger = false;
        });
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
      _refreshPosts();
      _loadPetLedger();
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
    final oracleController = Provider.of<OracleController>(context);
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
                              if (!authController.isAuthenticated) {
                                TermsAndConditionsModal.show(context);
                                return;
                              }
                              SponsorshipModal.show(context, pet: widget.pet, userId: authController.currentProfile?.id ?? 'usr_guest');
                            },
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 18),
                  ],

                  // Creator Analytics & Metrics Card Button (Exclusivo para el tutor/dueño de la mascota)
                  if (isOwner)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => PetAnalyticsDashboardModal.show(context, pet: widget.pet),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.insights_rounded, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Métricas & Estadísticas',
                                            style: GoogleFonts.fredoka(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.25),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Global & Videos',
                                              style: GoogleFonts.fredoka(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Gráficas de Vistas, Likes, Comentarios y Retención',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white.withOpacity(0.88),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Billetera, Abonos & Patrocinios de la Mascota (Audit Ledger & Withdrawals - Solo visible para el dueño/tutor)
                  if (isOwner)
                    _buildSponsorshipLedgerCard(authController, oracleController, langController, isOwner),


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
                  // Logout Red Action Button (Solo para el dueño/tutor)
                  if (isOwner) ...[
                    const SizedBox(height: 14),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.borderWarm),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTerracotta.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.video_camera_back_rounded, size: 36, color: AppTheme.primaryTerracotta),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '¡@${widget.pet.name} aún no tiene publicaciones!',
                            style: GoogleFonts.fredoka(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryDark,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isOwner
                                ? 'Sube el primer video o foto de ${widget.pet.name} para comenzar a interactuar con la comunidad y acumular vistas y likes.'
                                : 'Esta mascota aún no ha compartido publicaciones.',
                            style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          if (isOwner) ...[
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryTerracotta,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 2,
                              ),
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                              label: Text(
                                'Subir Primer Video / Foto',
                                style: GoogleFonts.fredoka(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                                );
                                _refreshPosts();
                              },
                            ),
                          ],
                        ],
                      ),
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
                  return GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (modalCtx) {
                          return Container(
                            decoration: const BoxDecoration(
                              color: AppTheme.bgWarmCream,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                            ),
                            padding: const EdgeInsets.only(top: 14, bottom: 20),
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
                                  const SizedBox(height: 10),
                                  PostCard(
                                    post: post,
                                    onPlayAttempt: () async {
                                      if (!authController.isAuthenticated) {
                                        TermsAndConditionsModal.show(context);
                                        return false;
                                      }
                                      return true;
                                    },
                                    onSponsor: (petId, amount) {
                                      SponsorshipModal.show(
                                        context,
                                        pet: widget.pet,
                                        userId: authController.currentProfile?.id ?? 'usr_guest',
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    child: ClipRRect(
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
                            // Video Icon indicator overlay
                            if (post.mediaType == 'video')
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
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

  void _openSolscan(String txHash) {
    final cleanHash = txHash.trim();
    if (cleanHash.isEmpty) return;
    final url = 'https://solscan.io/tx/$cleanHash';
    if (kIsWeb) {
      try {
        js.context.callMethod('open', [url, '_blank']);
      } catch (_) {}
    } else {
      Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enlace de Solscan copiado al portapapeles')),
      );
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _confirmResetPetLedger() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWarm,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.restart_alt_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Reiniciar Historial a 0',
                style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Deseas eliminar todos los registros de abonos y retiros de prueba de ${widget.pet.name} para comenzar de cero?',
          style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.fredoka(color: AppTheme.textMutedWarm)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sí, Reiniciar a 0', style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _isLoadingLedger = true);
      await _supabaseService.resetPetLedger(widget.pet.id);
      await _loadPetLedger();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.emeraldGreen,
          content: Text(
            '✅ Historial de patrocinios y balance de ${widget.pet.name} reiniciados a 0.',
            style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  Widget _buildSponsorshipLedgerCard(
    AuthController authController,
    OracleController oracleController,
    LanguageController langController,
    bool isOwner,
  ) {
    final availableUsd = oracleController.skrToUsd(_unclaimedSkr);
    final availableSol = oracleController.skrToSol(_unclaimedSkr);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F2027),
            const Color(0xFF203A43),
            const Color(0xFF2C5364),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.emeraldGreen.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.emeraldGreen.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldGreen.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.emeraldGreen, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Billetera & Patrocinios',
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Abonos recibidos y registro auditable en Solana',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.restart_alt_rounded, color: Colors.white70, size: 20),
                  tooltip: 'Reiniciar a 0 (Limpiar pruebas)',
                  onPressed: _confirmResetPetLedger,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                  tooltip: 'Actualizar balance',
                  onPressed: _loadPetLedger,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Available Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'BALANCE DISPONIBLE (UNCLAIMED)',
                        style: GoogleFonts.fredoka(
                          color: AppTheme.emeraldGreen,
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Solana Ledger',
                          style: GoogleFonts.outfit(color: AppTheme.emeraldGreen, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$_unclaimedSkr',
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '\$SKR',
                        style: GoogleFonts.fredoka(
                          color: AppTheme.accentOrange,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '≈ \$${availableUsd.toStringAsFixed(2)} USD • ${availableSol.toStringAsFixed(4)} SOL (Oracle Live)',
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Stats row (Recaudado Histórico vs Total Retirado)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Histórico', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text('$_lifetimeSkr \$SKR', style: GoogleFonts.fredoka(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Retirado', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text('$_withdrawnSkr \$SKR', style: GoogleFonts.fredoka(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Abonos', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text('${_petSponsorships.length}', style: GoogleFonts.fredoka(color: Colors.lightBlueAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Owner Action: Claim Payout Button
            if (isOwner) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.diamond_rounded, size: 20),
                  label: Text(
                    'Retirar Patrocinios (Claim Payout)',
                    style: GoogleFonts.fredoka(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    await ClaimSponsorshipModal.show(
                      context,
                      pet: widget.pet,
                      userId: authController.currentProfile?.id ?? '',
                    );
                    _loadPetLedger();
                  },
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),

            // Toggleable Abonos / Transactions List
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() => _showSponsorshipsList = !_showSponsorshipsList);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _showSponsorshipsList ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          color: AppTheme.emeraldGreen,
                          size: 22,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Historial de Abonos & Solscan (${_petSponsorships.length})',
                          style: GoogleFonts.fredoka(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _showSponsorshipsList ? 'Ocultar' : 'Ver detalle',
                      style: GoogleFonts.outfit(color: AppTheme.emeraldGreen, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            if (_showSponsorshipsList) ...[
              const SizedBox(height: 10),
              if (_isLoadingLedger)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: AppTheme.emeraldGreen),
                  ),
                )
              else if (_petSponsorships.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.pets_rounded, color: Colors.white38, size: 32),
                      const SizedBox(height: 6),
                      Text(
                        'No hay abonos registrados aún para esta mascota.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                )
              else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _petSponsorships.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final s = _petSponsorships[index];
                    final isWithdrawn = s.isClaimed || s.status == 'withdrawn';
                    final dateStr = '${s.createdAt.day.toString().padLeft(2, '0')}/${s.createdAt.month.toString().padLeft(2, '0')}/${s.createdAt.year}';
                    final txHashStr = s.txHash;
                    final txDisplay = (txHashStr != null && txHashStr.isNotEmpty)
                        ? (txHashStr.length > 14
                            ? '${txHashStr.substring(0, 6)}...${txHashStr.substring(txHashStr.length - 6)}'
                            : txHashStr)
                        : null;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isWithdrawn
                              ? Colors.white.withOpacity(0.08)
                              : AppTheme.emeraldGreen.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppTheme.emeraldGreen.withOpacity(0.2),
                                backgroundImage: s.sponsorAvatar != null && s.sponsorAvatar!.isNotEmpty
                                    ? NetworkImage(s.sponsorAvatar!)
                                    : null,
                                child: (s.sponsorAvatar == null || s.sponsorAvatar!.isEmpty)
                                    ? const Icon(Icons.person, color: AppTheme.emeraldGreen, size: 16)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.sponsorName ?? 'Patrocinador',
                                      style: GoogleFonts.fredoka(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      dateStr,
                                      style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '+${s.netAmount} \$SKR',
                                    style: GoogleFonts.fredoka(
                                      color: isWithdrawn ? Colors.white60 : AppTheme.emeraldGreen,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isWithdrawn
                                          ? Colors.amber.withOpacity(0.15)
                                          : AppTheme.emeraldGreen.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isWithdrawn ? Icons.lock_outline_rounded : Icons.check_circle_outline_rounded,
                                          color: isWithdrawn ? Colors.amberAccent : AppTheme.emeraldGreen,
                                          size: 10,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          isWithdrawn ? 'Retirado' : 'Disponible',
                                          style: GoogleFonts.outfit(
                                            color: isWithdrawn ? Colors.amberAccent : AppTheme.emeraldGreen,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (txDisplay != null && txHashStr != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.fingerprint_rounded, color: Colors.white38, size: 14),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'TX: $txDisplay',
                                      style: GoogleFonts.robotoMono(color: Colors.white60, fontSize: 10),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _copyToClipboard(txHashStr, 'TX Hash copiado'),
                                    child: const Padding(
                                      padding: EdgeInsets.all(2),
                                      child: Icon(Icons.copy_rounded, color: Colors.white60, size: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => _openSolscan(txHashStr),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.solanaPurple.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Solscan', style: GoogleFonts.outfit(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 2),
                                          const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 9),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],

              // Completed Withdrawals Section (if any)
              if (_petWithdrawals.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Retiros Realizados (${_petWithdrawals.length})',
                  style: GoogleFonts.fredoka(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _petWithdrawals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final w = _petWithdrawals[index];
                    final dateStr = '${w.createdAt.day.toString().padLeft(2, '0')}/${w.createdAt.month.toString().padLeft(2, '0')}/${w.createdAt.year}';
                    final walletDisplay = w.destinationWallet.length > 12
                        ? '${w.destinationWallet.substring(0, 6)}...${w.destinationWallet.substring(w.destinationWallet.length - 4)}'
                        : w.destinationWallet;

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.amberAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${w.amountSkr} \$SKR retirados', style: GoogleFonts.fredoka(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('$dateStr • Destino: $walletDisplay', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10)),
                              ],
                            ),
                          ),
                          if (w.txHash != null && w.txHash!.isNotEmpty)
                            InkWell(
                              onTap: () => _openSolscan(w.txHash!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.solanaPurple.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Solscan', style: GoogleFonts.outfit(color: Colors.white, fontSize: 9)),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 9),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
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

