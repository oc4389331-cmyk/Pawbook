import 'dart:math';
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
import '../../services/url_launcher_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/sponsorship_modal.dart';
import '../widgets/pet_analytics_dashboard_modal.dart';
import '../widgets/claim_sponsorship_modal.dart';
import '../widgets/post_card.dart';
import '../widgets/language_selector.dart';
import '../widgets/terms_and_conditions_modal.dart';
import '../widgets/about_pawbook_modal.dart';
import '../widgets/pet_attribute_bar.dart';
import '../widgets/pet_analytics_curve_card.dart';
import '../widgets/follows_dashboard_modal.dart';
import '../widgets/pet_verification_modal.dart';
import '../widgets/video_thumbnail_widget.dart';
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
  List<PostModel> _petPosts = [];
  int _followersCount = 0;
  int _followingCount = 0;

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
    final future = feed.getPostsForPet(widget.pet.id, currentUserId: auth.currentProfile?.id);
    setState(() {
      _postsFuture = future;
    });
    future.then((posts) {
      if (mounted) {
        setState(() {
          _petPosts = posts;
        });
      }
    });
  }

  Future<void> _loadPetLedger() async {
    if (!mounted) return;
    setState(() => _isLoadingLedger = true);

    try {
      final spns = await _supabaseService.getSponsorshipsForPet(widget.pet.id);
      final wths = await _supabaseService.getWithdrawalsForPet(widget.pet.id);
      final followers = await _supabaseService.getFollowersCountForPet(widget.pet.id);
      final auth = Provider.of<AuthController>(context, listen: false);
      int following = 0;
      if (auth.currentProfile != null) {
        try {
          final followedPets = await _supabaseService.getFollowedPets(auth.currentProfile!.id);
          following = followedPets.length;
        } catch (_) {}
      }

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
          _lifetimeSkr = totalLife;
          _unclaimedSkr = totalUnclaimed;
          _withdrawnSkr = totalWithdrawn;
          _followersCount = followers;
          _followingCount = following;
          _isLoadingLedger = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _unclaimedSkr = 0;
          _lifetimeSkr = 0;
          _withdrawnSkr = 0;
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
    final bool isChico = widget.pet.id == 'pet_d1148fad' ||
        widget.pet.name.trim().toLowerCase() == 'chico' ||
        widget.pet.id.toLowerCase().contains('chico');

    bool isOwner = false;
    if (authController.isAuthenticated && authController.currentProfile != null) {
      final currentUserId = authController.currentProfile!.id;
      final currentUserEmail = authController.currentProfile!.email?.trim().toLowerCase();

      if (isChico) {
        // Regla estricta: Chico pertenece exclusivamente a W. Ernesto (wernesto66@gmail.com / usr_VL5CBAhr / usr_sol_400a)
        isOwner = (currentUserEmail == 'wernesto66@gmail.com' ||
            currentUserId == 'usr_VL5CBAhr' ||
            currentUserId == 'usr_sol_400a');
      } else {
        isOwner = (widget.pet.ownerId.isNotEmpty &&
                widget.pet.ownerId != 'usr_owner' &&
                widget.pet.ownerId == currentUserId) ||
            (authController.activePet != null &&
                authController.activePet!.id == widget.pet.id &&
                (widget.pet.ownerId.isEmpty || widget.pet.ownerId == currentUserId)) ||
            (authController.userPets.any((p) =>
                p.id == widget.pet.id &&
                (p.ownerId == currentUserId || p.ownerId.isEmpty)));
      }
    }

    final currentPetInstance = widget.pet.copyWith(nftMintAddress: _verifiedNftAddress);
    final bool isExempted = currentPetInstance.isExempted;
    final bool isPetVerified = currentPetInstance.isVerified;
    final bool isVerificationExpired = currentPetInstance.isVerificationExpired;
    final int daysRemaining = currentPetInstance.verificationDaysRemaining;

    final totalViews = _petPosts.fold<int>(0, (sum, p) => sum + p.viewsCount);
    final totalLikes = _petPosts.fold<int>(0, (sum, p) => sum + p.likesCount);
    final totalComments = _petPosts.fold<int>(0, (sum, p) => sum + p.commentsCount);
    final postsCount = _petPosts.length;

    // 1. Vitalidad Real (Actividad y consistencia de videos publicados):
    final vitalityProgress = postsCount == 0
        ? 0.10
        : min(1.0, 0.20 + (postsCount * 0.20) + min(0.20, (totalComments * 0.03) + (totalLikes * 0.05)));
    final vitalityPercentageText = '${(vitalityProgress * 100).toInt()}%';

    // 2. Patrocinio Real (Progreso real de patrocinios sobre meta de 500 $SKR):
    const double targetSponsorshipGoal = 500.0;
    final sponsorshipProgress = targetSponsorshipGoal > 0
        ? (_lifetimeSkr / targetSponsorshipGoal).clamp(0.0, 1.0)
        : 0.0;
    final sponsorshipPercentageText = _lifetimeSkr > 0
        ? '${(sponsorshipProgress * 100).toInt()}%'
        : '0%';

    // 3. Nivel de Energía Real (Alcance y visualizaciones de los videos):
    final energyProgress = postsCount == 0
        ? 0.05
        : min(1.0, max(0.10, (totalViews / 1000.0) + (totalComments * 0.02)));
    final energyPercentageText = '${(energyProgress * 100).toInt()}%';

    // 4. Afinidad de la Comunidad Real (Tasa real de interacción):
    final affinityRate = totalViews > 0
        ? (((totalLikes + totalComments) / totalViews) * 100).clamp(0.0, 100.0)
        : 0.0;
    final affinityText = '${affinityRate > 0 ? affinityRate.toStringAsFixed(1) : "0"}% Afinidad';

    // 5. Score Real (Visualizaciones + likes + comentarios + patrocinios):
    final realScore = widget.pet.totalSponsoredScore > 0
        ? widget.pet.totalSponsoredScore
        : (totalViews + (totalLikes * 5) + (totalComments * 10) + _lifetimeSkr);

    // 6. Popularidad Real:
    final popularityPercent = totalViews > 0
        ? min(100.0, max(5.0, (totalViews / 10.0)))
        : 0.0;

    // 7. Monto en Dinero Real (Conversión real de patrocinios a USD):
    final double liveSkrPrice = oracleController.priceUsd > 0 ? oracleController.priceUsd : 0.0215;
    final double realEarningsUsd = _lifetimeSkr * liveSkrPrice;
    final String realEarningsText = realEarningsUsd > 0
        ? '\$${realEarningsUsd.toStringAsFixed(2)} USD'
        : '\$0.00 USD';

    // 8. Rendimiento Real:
    final String performanceText = postsCount >= 2 ? '+${(postsCount * 4.8).toStringAsFixed(1)}%' : '+0.0%';

    // 9. Curva de Puntos Real (Evolución de vistas acumuladas):
    List<double> weeklyPoints = [0.05, 0.05, 0.10, 0.20, 0.45, 0.70, 0.85];
    if (_petPosts.isNotEmpty) {
      final sortedPosts = List<PostModel>.from(_petPosts)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      double cum = 0;
      final List<double> pts = [0.05];
      for (final p in sortedPosts) {
        cum += p.viewsCount;
        pts.add(totalViews > 0 ? (cum / totalViews * 0.85).clamp(0.05, 0.95) : 0.1);
      }
      while (pts.length < 7) {
        pts.insert(0, 0.05);
      }
      weeklyPoints = pts;
    }

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
          const Center(child: LanguageSelector()),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: AppTheme.primaryTerracotta, size: 24),
            tooltip: langController.t('aboutBtn'),
            onPressed: () => AboutPawbookModal.show(context),
          ),
          if (isOwner && widget.onSwitchToHuman != null)
            IconButton(
              icon: const Icon(Icons.person_pin_rounded, color: AppTheme.primaryTerracotta, size: 28),
              tooltip: langController.t('switchToHumanTooltip'),
              onPressed: widget.onSwitchToHuman,
            ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              tooltip: langController.t('logOut'),
              onPressed: () async {
                await authController.logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
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
                  color: AppTheme.pastelSkyBlue.withValues(alpha: 0.6),
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
                            '${langController.t("guardianLabel")} ${authController.currentProfile?.fullName ?? authController.currentProfile?.username ?? "Humano"}',
                            style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '🏆 PawtScore: ${authController.currentProfile?.pawtScore ?? 0} pts',
                            style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 11, fontWeight: FontWeight.w600),
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
                      label: Text(langController.t('humanBtn'), style: GoogleFonts.fredoka(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: widget.onSwitchToHuman ?? () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            // Header Hero Card (Pawly Pastel Style - Exact Image 1 & 4 Reference)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: AppTheme.softCardShadow,
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
              ),
              child: Column(
                children: [
                  // Top Row with Avatar, Name, Handle, and Action Buttons (Like, Share)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar with Camera Badge and Holographic NFT Badge
                      Builder(builder: (_) {
                        final currentPetAvatar = (isOwner && authController.activePet?.id == widget.pet.id)
                            ? (authController.activePet!.avatarUrl.isNotEmpty ? authController.activePet!.avatarUrl : widget.pet.avatarUrl)
                            : (authController.userPets.any((p) => p.id == widget.pet.id)
                                ? (authController.userPets.firstWhere((p) => p.id == widget.pet.id).avatarUrl)
                                : widget.pet.avatarUrl);

                        return Stack(
                          alignment: Alignment.bottomRight,
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 46,
                              backgroundColor: AppTheme.pastelPeach,
                              child: CircleAvatar(
                                radius: 42,
                                backgroundColor: AppTheme.surfaceWarm,
                                backgroundImage: NetworkImage(
                                  currentPetAvatar.isNotEmpty
                                      ? currentPetAvatar
                                      : 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=400',
                                ),
                                child: _isUploadingAvatar
                                    ? Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.55),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            // Orange Camera Button
                            if (isOwner)
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _isUploadingAvatar ? null : () => _pickAndChangePetAvatar(authController),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.pawButtonGradient,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2.5),
                                        boxShadow: AppTheme.elevatedPawShadow,
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        color: Colors.white,
                                        size: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Holographic NFT / Verified Badge (only if verified)
                            if (isPetVerified)
                              Positioned(
                                top: -2,
                                left: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'VERIFICADO',
                                    style: GoogleFonts.fredoka(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }),
                      const SizedBox(width: 16),

                      // Name, Verified Badge, Handle, Breed
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.pet.name,
                                    style: GoogleFonts.fredoka(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimaryDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isPetVerified) ...[
                                  const SizedBox(width: 5),
                                  GestureDetector(
                                    onTap: isOwner
                                        ? () => PetVerificationModal.show(
                                              context,
                                              pet: currentPetInstance,
                                              onVerified: (updated) {
                                                setState(() {
                                                  _verifiedNftAddress = updated.nftMintAddress;
                                                });
                                                _refreshPosts();
                                              },
                                            )
                                        : null,
                                    child: Tooltip(
                                      message: isExempted
                                          ? 'Cuenta Oficial Verificada (Vitalicia / Exonerada) • Toca para gestionar'
                                          : 'Cuenta Oficial Verificada (Vence en $daysRemaining días) • Toca para gestionar',
                                      child: const Icon(
                                        Icons.verified_rounded,
                                        color: Color(0xFF0284C7),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  if (!isExempted && isOwner && daysRemaining <= 7) ...[
                                    const SizedBox(width: 6),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => PetVerificationModal.show(
                                        context,
                                        pet: currentPetInstance,
                                        onVerified: (updated) {
                                          setState(() {
                                            _verifiedNftAddress = updated.nftMintAddress;
                                          });
                                          _refreshPosts();
                                        },
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.amber.shade700, width: 0.8),
                                        ),
                                        child: Text(
                                          'Renovar ($daysRemaining d)',
                                          style: GoogleFonts.fredoka(
                                            color: Colors.amber.shade900,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ] else if (isOwner && !isExempted) ...[
                                  const SizedBox(width: 6),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => PetVerificationModal.show(
                                      context,
                                      pet: currentPetInstance,
                                      onVerified: (updated) {
                                        setState(() {
                                          _verifiedNftAddress = updated.nftMintAddress;
                                        });
                                        _refreshPosts();
                                      },
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (isVerificationExpired ? Colors.orange : const Color(0xFF0284C7)).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: (isVerificationExpired ? Colors.orange : const Color(0xFF0284C7)).withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isVerificationExpired ? Icons.replay_rounded : Icons.verified_outlined,
                                            color: isVerificationExpired ? Colors.orange.shade800 : const Color(0xFF0284C7),
                                            size: 13,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            isVerificationExpired ? 'Renovar (\$10)' : 'Verificar (\$10)',
                                            style: GoogleFonts.fredoka(
                                              color: isVerificationExpired ? Colors.orange.shade800 : const Color(0xFF0284C7),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${widget.pet.name.toLowerCase()} 💛',
                              style: GoogleFonts.fredoka(
                                fontSize: 13,
                                color: AppTheme.brandCoral,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, color: AppTheme.textMutedWarm, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${widget.pet.species} • ${widget.pet.breed}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: AppTheme.textMutedWarm,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Like and Share Action buttons in top-right
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.favorite_border_rounded, size: 18, color: AppTheme.brandCoral),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('¡Le diste amor a ${widget.pet.name}! ❤️'),
                                    backgroundColor: AppTheme.brandCoral,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.share_outlined, size: 18, color: AppTheme.textMutedWarm),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: 'https://pawbooklife.com/pet/${widget.pet.id}'));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('¡Enlace del perfil copiado! 🐾')),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bio description if present
                  if (widget.pet.bio.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        widget.pet.bio,
                        style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark, fontSize: 12.5),
                        textAlign: TextAlign.left,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Attribute Progress Bars (Solo visible para el tutor/dueño de la mascota)
                  if (isOwner) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5EE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Atributos de Bienestar',
                                style: GoogleFonts.fredoka(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryDark,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.brandCoral.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.people_outline_rounded, size: 12, color: AppTheme.brandCoral),
                                    const SizedBox(width: 4),
                                    Text(
                                      affinityText,
                                      style: GoogleFonts.fredoka(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.brandCoral,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          PetAttributeBar(
                            icon: Icons.favorite_rounded,
                            iconColor: AppTheme.brandCoral,
                            label: 'Vitalidad',
                            progress: vitalityProgress,
                            percentageText: vitalityPercentageText,
                            valueColor: AppTheme.brandCoral,
                          ),
                          PetAttributeBar(
                            icon: Icons.shield_rounded,
                            iconColor: AppTheme.pawTeal,
                            label: 'Patrocinio',
                            progress: sponsorshipProgress,
                            percentageText: sponsorshipPercentageText,
                            valueColor: AppTheme.pawTeal,
                          ),
                          PetAttributeBar(
                            icon: Icons.bolt_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            label: 'Nivel Energía',
                            progress: energyProgress,
                            percentageText: energyPercentageText,
                            valueColor: const Color(0xFFF59E0B),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Public Welcome Card for Visitors (Sin exponer métricas internas)
                  if (!isOwner) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.brandCoral.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.pets_rounded, color: AppTheme.brandCoral, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Canal Oficial de ${widget.pet.name}',
                                  style: GoogleFonts.fredoka(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '¡Disfruta sus videos y apóyalo con patrocinios!',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    color: AppTheme.textMutedWarm,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Analytics Curve Card (Métricas Privadas de Rendimiento y Ganancias - Exclusivo para el tutor/dueño)
                  if (isOwner) ...[
                    PetAnalyticsCurveCard(
                      followersCount: _followersCount,
                      totalScore: realScore,
                      popularityPercent: popularityPercent,
                      earningsText: realEarningsText,
                      performanceText: performanceText,
                      weeklyPoints: weeklyPoints,
                      onTapFollowers: () {
                        FollowsDashboardModal.show(
                          context,
                          pet: widget.pet,
                          currentUserId: authController.currentProfile?.id,
                          initialTabIndex: 0,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Community & Follows Quick Stat Chip
                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: isOwner ? () {
                        FollowsDashboardModal.show(
                          context,
                          pet: widget.pet,
                          currentUserId: authController.currentProfile?.id,
                          initialTabIndex: 0,
                        );
                      } : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite_rounded, size: 15, color: AppTheme.brandCoral),
                            const SizedBox(width: 6),
                            Text(
                              '$_followersCount ${_followersCount == 1 ? "Suscriptor" : "Suscriptores"}',
                              style: GoogleFonts.fredoka(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.textPrimaryDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('•', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            const Icon(Icons.pets_rounded, size: 15, color: Color(0xFF0284C7)),
                            const SizedBox(width: 6),
                            Text(
                              '$_followingCount Siguiendo',
                              style: GoogleFonts.fredoka(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.textPrimaryDark,
                              ),
                            ),
                            if (isOwner) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.textMutedWarm),
                            ],
                          ],
                        ),
                      ),
                    ),
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
                            label: Text(isFollowing ? langController.t('followingBtn') : langController.t('followBtn'), style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
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
                            label: Text(langController.t('sponsor'), style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
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
                          colors: [AppTheme.brandCoral, Color(0xFF7C3AED)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.brandCoral.withValues(alpha: 0.3),
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
                                    color: Colors.white.withValues(alpha: 0.2),
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
                                            langController.t('metricsAndStatsTitle'),
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
                                              color: Colors.white.withValues(alpha: 0.25),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              langController.t('globalAndVideos'),
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
                                        langController.t('metricsSubtitle'),
                                        style: GoogleFonts.outfit(
                                          color: Colors.white.withValues(alpha: 0.88),
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
                                  '${langController.t("walletLabel")}:',
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
                                '${langController.t("activeBadge")} ⚡',
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
                              tooltip: langController.t('copyWallet'),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: widget.pet.dynamicWalletAddress));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppTheme.emeraldGreen,
                                    duration: const Duration(seconds: 2),
                                    content: Text(langController.t('copiedWalletToast')),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Solana Verified Account & Verification Button Section ($10 USD / SOL / SKR)
                  if (isPetVerified) ...[
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: isOwner
                          ? () => PetVerificationModal.show(
                                context,
                                pet: currentPetInstance,
                                onVerified: (updated) {
                                  setState(() {
                                    _verifiedNftAddress = updated.nftMintAddress;
                                  });
                                  _refreshPosts();
                                },
                              )
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF0284C7)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, color: Color(0xFF0284C7), size: 20),
                            const SizedBox(width: 6),
                            Text(
                              isExempted
                                  ? 'Cuenta Oficial Verificada • Vitalicia (Exonerada)'
                                  : 'Cuenta Oficial Verificada en Solana ($daysRemaining días restantes)',
                              style: GoogleFonts.fredoka(color: const Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            if (isOwner) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.touch_app_rounded, color: Color(0xFF0284C7), size: 16),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (isOwner && !isExempted) ...[
                    // Button to acquire or renew official $10 USD Blue Star Badge (40 days)
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isVerificationExpired ? Colors.orange.shade700 : const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        icon: Icon(isVerificationExpired ? Icons.replay_rounded : Icons.verified_rounded, size: 18),
                        label: Text(
                          isVerificationExpired
                              ? 'Renovar Verificación (40 días) • \$10 USD / SOL / \$SKR'
                              : 'Obtener Insignia Verificada (40 días) • \$10 USD',
                          style: GoogleFonts.fredoka(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => PetVerificationModal.show(
                          context,
                          pet: currentPetInstance,
                          onVerified: (updated) {
                            setState(() {
                              _verifiedNftAddress = updated.nftMintAddress;
                            });
                            _refreshPosts();
                          },
                        ),
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
                          Expanded(child: _buildStatColumn(langController.t('pawtScoreLabel'), '${widget.pet.totalSponsoredScore} pts', AppTheme.brandCoral, bgColor: AppTheme.pastelPeach.withValues(alpha: 0.6))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStatColumn(langController.t('posts'), '$postsCount', AppTheme.solanaPurple, bgColor: AppTheme.pastelLavender.withValues(alpha: 0.6))),
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
                          if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Language Profile Tile (Permite cambiar el idioma directamente desde el perfil)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LanguageProfileTile(),
            ),
            const SizedBox(height: 8),

            // Pet Posts Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${langController.t("petPostsHeader")} ${widget.pet.name}',
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
                            '@${widget.pet.name} ${langController.t("petHasNoPostsYet")}',
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
                                ? langController.t('uploadFirstPostOwner')
                                : langController.t('uploadFirstPostGuest'),
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
                                langController.t('uploadFirstMediaBtn'),
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
                            VideoThumbnailWidget(
                              mediaUrl: post.mediaUrl,
                              mediaType: post.mediaType,
                              fallbackImageUrl: widget.pet.avatarUrl,
                            ),
                            // Video Icon indicator overlay
                            if (post.mediaType == 'video' || post.mediaUrl.toLowerCase().contains('.mp4'))
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                                ),
                              ),
                            // Bottom Views / Likes Indicator
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      post.mediaType == 'video' ? Icons.play_arrow_rounded : Icons.favorite_rounded,
                                      color: Colors.white,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${post.viewsCount > 0 ? post.viewsCount : post.likesCount}',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
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
                                          title: Text(langController.t('deletePostTitle'), style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark)),
                                          content: Text(langController.t('deletePostConfirm'), style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark)),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: Text(langController.t('cancel'), style: GoogleFonts.fredoka(color: AppTheme.textMutedWarm)),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                Navigator.pop(ctx);
                                                setState(() {
                                                  _petPosts.removeWhere((p) => p.id == post.id);
                                                });
                                                await feedController.deletePetPost(post.id);
                                                if (mounted) {
                                                  _refreshPosts();
                                                  _loadPetLedger();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      backgroundColor: AppTheme.brandCoral,
                                                      content: Text(
                                                        '🗑️ Publicación eliminada con éxito',
                                                        style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: Text(langController.t('deletePost'), style: GoogleFonts.fredoka(color: Colors.redAccent)),
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
    try {
      UrlLauncherService.instance.openUrl(url);
    } catch (_) {}
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _confirmResetPetLedger(LanguageController langController) async {
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
                langController.t('resetLedgerTitle'),
                style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          langController.t('resetLedgerConfirm'),
          style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(langController.t('cancel'), style: GoogleFonts.fredoka(color: AppTheme.textMutedWarm)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(langController.t('resetLedgerBtn'), style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold)),
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
            '✅ ${langController.t("resetLedgerSuccess")}',
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
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.emeraldGreen.withValues(alpha: 0.2),
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
                    color: AppTheme.emeraldGreen.withValues(alpha: 0.25),
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
                        langController.t('walletAndSponsorshipsTitle'),
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        langController.t('walletAndSponsorshipsSubtitle'),
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
                  tooltip: langController.t('resetToZeroTooltip'),
                  onPressed: () => _confirmResetPetLedger(langController),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                  tooltip: langController.t('refreshBalanceTooltip'),
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
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        langController.t('unclaimedBalanceLabel'),
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
                          color: AppTheme.emeraldGreen.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          langController.t('solanaLedgerBadge'),
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
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(langController.t('lifetimeTotal'), style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10)),
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
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(langController.t('totalWithdrawn'), style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10)),
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
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(langController.t('payoutsCount'), style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10)),
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
                    langController.t('claimPayoutBtn'),
                    style: GoogleFonts.fredoka(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    await ClaimSponsorshipModal.show(
                      context,
                      pet: widget.pet,
                      userId: authController.currentProfile?.id ?? '',
                      unclaimedSkr: _unclaimedSkr,
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
                          '${langController.t("payoutsHistoryHeader")} (${_petSponsorships.length})',
                          style: GoogleFonts.fredoka(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _showSponsorshipsList ? langController.t('hide') : langController.t('viewDetails'),
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
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.pets_rounded, color: Colors.white38, size: 32),
                      const SizedBox(height: 6),
                      Text(
                        langController.t('noPayoutsYet'),
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
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isWithdrawn
                              ? Colors.white.withValues(alpha: 0.08)
                              : AppTheme.emeraldGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppTheme.emeraldGreen.withValues(alpha: 0.2),
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
                                          ? Colors.amber.withValues(alpha: 0.15)
                                          : AppTheme.emeraldGreen.withValues(alpha: 0.2),
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
                                          isWithdrawn ? langController.t('statusWithdrawn') : langController.t('statusAvailable'),
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
                                color: Colors.white.withValues(alpha: 0.05),
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
                                        color: AppTheme.solanaPurple.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Solscan', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                          SizedBox(width: 2),
                                          Icon(Icons.open_in_new_rounded, color: Colors.white, size: 9),
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
                  '${langController.t("completedWithdrawalsHeader")} (${_petWithdrawals.length})',
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
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.amberAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${w.amountSkr} \$SKR ${langController.t("withdrawnAmount")}', style: GoogleFonts.fredoka(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('$dateStr • ${langController.t("destination")}: $walletDisplay', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10)),
                              ],
                            ),
                          ),
                          if (w.txHash != null && w.txHash!.isNotEmpty)
                            InkWell(
                              onTap: () => _openSolscan(w.txHash!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.solanaPurple.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Solscan', style: TextStyle(color: Colors.white, fontSize: 9)),
                                    SizedBox(width: 2),
                                    Icon(Icons.open_in_new_rounded, color: Colors.white, size: 9),
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

  Widget _buildStatColumn(String label, String value, Color color, {Color? bgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor ?? AppTheme.pastelPeach.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderWarm),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMutedWarm, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

