import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/language_controller.dart';
import '../../models/post_model.dart';
import '../../models/pet_model.dart';
import '../../models/comment_model.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import 'sponsorship_modal.dart';

class TikTokFeedItem extends StatefulWidget {
  final PostModel post;
  final String currentUserId;
  final VoidCallback? onLikeToggled;

  const TikTokFeedItem({
    super.key,
    required this.post,
    required this.currentUserId,
    this.onLikeToggled,
  });

  @override
  State<TikTokFeedItem> createState() => _TikTokFeedItemState();
}

class _TikTokFeedItemState extends State<TikTokFeedItem> {
  late bool _isLiked;
  late int _likesCount;
  late int _viewsCount;
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedByCurrentUser;
    _likesCount = widget.post.likesCount;
    _viewsCount = widget.post.viewsCount;
    _supabaseService.recordPostView(widget.post.id);
  }

  void _handleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    await _supabaseService.toggleLikePost(widget.currentUserId, widget.post.id);
    if (widget.onLikeToggled != null) widget.onLikeToggled!();
  }

  void _showCommentsBottomSheet(LanguageController langController) {
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgWarmCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.borderWarm,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    langController.t('comments'),
                    style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Divider(color: AppTheme.borderWarm),
                  Expanded(
                    child: FutureBuilder<List<CommentModel>>(
                      future: _supabaseService.getCommentsForPost(widget.post.id),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryTerracotta));
                        }
                        final comments = snapshot.data!;
                        if (comments.isEmpty) {
                          return Center(
                            child: Text(
                              langController.t('noComments'),
                              style: GoogleFonts.outfit(color: AppTheme.textMutedWarm),
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: comments.length,
                          itemBuilder: (context, idx) {
                            final cmt = comments[idx];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.surfaceWarm,
                                child: Text(
                                  (cmt.username ?? 'U')[0].toUpperCase(),
                                  style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                cmt.username ?? 'Paw User',
                                style: GoogleFonts.fredoka(color: AppTheme.textPrimaryDark, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                cmt.content,
                                style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark, fontSize: 14),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            style: GoogleFonts.outfit(color: AppTheme.textPrimaryDark),
                            decoration: InputDecoration(
                              hintText: langController.t('addComment'),
                              hintStyle: GoogleFonts.outfit(color: AppTheme.textMutedWarm),
                              filled: true,
                              fillColor: AppTheme.surfaceWarm,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(color: AppTheme.borderWarm),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: AppTheme.primaryTerracotta),
                          onPressed: () async {
                            if (commentController.text.trim().isNotEmpty) {
                              final text = commentController.text.trim();
                              commentController.clear();
                              await _supabaseService.addComment(
                                widget.currentUserId,
                                widget.post.id,
                                text,
                              );
                              setModalState(() {});
                            }
                          },
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final langController = Provider.of<LanguageController>(context);
    final petName = widget.post.petName ?? 'Mascota';
    final petAvatar = widget.post.petAvatarUrl ?? 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=200';

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Media Background (Serving from Cloudflare R2 / Unsplash / Mixkit video)
        Image.network(
          widget.post.mediaUrl.contains('mixkit')
              ? 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=1000'
              : widget.post.mediaUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFF09090B),
            child: const Center(
              child: Icon(Icons.pets_rounded, size: 80, color: AppTheme.primaryTerracotta),
            ),
          ),
        ),

        // Gradient Dark Overlay for TikTok UI legibility
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black54,
                Colors.transparent,
                Colors.black87,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // Play Icon Overlay if video
        if (widget.post.mediaType == 'video')
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, size: 48, color: Colors.white),
            ),
          ),

        // 2. Right Vertical Sidebar Actions
        Positioned(
          right: 14,
          bottom: 110,
          child: Column(
            children: [
              // Pet Profile Avatar with mint badge
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppTheme.emeraldGreen,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(petAvatar),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryTerracotta,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Like Button
              GestureDetector(
                onTap: _handleLike,
                child: Column(
                  children: [
                    Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? const Color(0xFFEF4444) : Colors.white,
                      size: 36,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_likesCount',
                      style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Comment Button
              GestureDetector(
                onTap: () => _showCommentsBottomSheet(langController),
                child: Column(
                  children: [
                    const Icon(Icons.comment_rounded, color: Colors.white, size: 34),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.post.commentsCount}',
                      style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Views counter
              Column(
                children: [
                  const Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 30),
                  const SizedBox(height: 4),
                  Text(
                    '$_viewsCount',
                    style: GoogleFonts.fredoka(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // SPONSORSHIP BAR BUTTON (Dual Stripe & Solana Pay Modal)
              GestureDetector(
                onTap: () {
                  SponsorshipModal.show(
                    context,
                    pet: widget.post.toPetModel(),
                    userId: widget.currentUserId,
                  );
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
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryTerracotta.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 26),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                langController.t('sponsor'),
                style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
        ),

        // 3. Bottom Left Info Overlay (Pet Name, Caption, Tags)
        Positioned(
          left: 16,
          bottom: 30,
          right: 90,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '@$petName',
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.post.nftMintAddress != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.solanaPurple.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.solanaPurple),
                      ),
                      child: Text(
                        'Solana NFT 🐾',
                        style: GoogleFonts.fredoka(color: AppTheme.solanaGreen, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.post.caption,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.post.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: widget.post.tags.map((t) {
                    return Text(
                      '#$t',
                      style: GoogleFonts.fredoka(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 12),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

extension PostDummyPetExt on PostModel {
  PetModel toPetModel() {
    return PetModel(
      id: petId,
      ownerId: 'usr_owner',
      name: petName ?? 'Mascota Creadora',
      species: 'Pet',
      breed: 'Pawtbook Creator',
      bio: 'Star creator pet on Solana 🐾',
      avatarUrl: petAvatarUrl ?? 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=200',
      nftMintAddress: nftMintAddress,
      totalSponsoredScore: 500,
      createdAt: DateTime.now(),
    );
  }
}
