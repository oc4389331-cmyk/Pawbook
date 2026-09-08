import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../models/pet_model.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

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
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _supabaseService.recordPostView(widget.post.id);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Media Background (Serving from Cloudflare R2 / Unsplash / Mixkit video)
        Container(
          color: Colors.black,
          child: Image.network(
            widget.post.mediaUrl.contains('mixkit')
                ? 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=1000'
                : widget.post.mediaUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF09090B),
              child: const Center(
                child: Icon(Icons.pets_rounded, size: 80, color: AppTheme.primaryTerracotta),
              ),
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
