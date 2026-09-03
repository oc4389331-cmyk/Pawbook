import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/post_model.dart';
import '../../theme/app_theme.dart';
import 'pet_badge.dart';
import 'sponsor_dialog.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final Function(String petId, int amount)? onSponsor;
  final Function(String postId)? onReport;

  const PostCard({
    super.key,
    required this.post,
    this.onSponsor,
    this.onReport,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.post.likesCount;
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime = DateFormat.yMMMd().add_jm().format(widget.post.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Pet Avatar & Solana NFT Mint Badge
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.solanaPurple,
                  backgroundImage: NetworkImage(
                    widget.post.petAvatarUrl ?? 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=200',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PetBadge(
                        petName: widget.post.petName ?? 'Mascota Creadora',
                        nftMintAddress: widget.post.nftMintAddress,
                        avatarUrl: null,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedTime,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.flag_outlined, size: 20, color: AppTheme.textMuted),
                  tooltip: 'Denunciar publicación',
                  onPressed: () {
                    if (widget.onReport != null) {
                      widget.onReport!(widget.post.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Publicación denunciada. La comunidad revisará el contenido.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // Media Content served from Cloudflare R2: https://media.pawbooklife.com
          ClipRRect(
            borderRadius: BorderRadius.zero,
            child: Container(
              height: 260,
              width: double.infinity,
              color: AppTheme.surfaceDark,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(
                    widget.post.mediaUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppTheme.surfaceDark,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.pets, size: 48, color: AppTheme.solanaPurple),
                              SizedBox(height: 8),
                              Text('Pawtbook Media R2 Served', style: TextStyle(color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (widget.post.mediaType == 'video')
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow, size: 36, color: AppTheme.solanaGreen),
                    ),
                ],
              ),
            ),
          ),

          // Caption & Interactive Bar (Like & Sponsor Pet Action)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.caption,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? Colors.redAccent : AppTheme.textMuted,
                      ),
                      onPressed: () {
                        setState(() {
                          _isLiked = !_isLiked;
                          _likesCount += _isLiked ? 1 : -1;
                        });
                      },
                    ),
                    Text(
                      ' likes',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const Spacer(),
                    // Sponsor Pet Button (Human Sponsor Tippable)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.solanaPurple.withValues(alpha: 0.2),
                        foregroundColor: AppTheme.solanaGreen,
                        side: const BorderSide(color: AppTheme.solanaGreen, width: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      icon: const Icon(Icons.volunteer_activism, size: 16, color: AppTheme.solanaGreen),
                      label: const Text('Patrocinar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => SponsorDialog(
                            petName: widget.post.petName ?? 'Mascota',
                            onSponsor: (amount) {
                              if (widget.onSponsor != null) {
                                widget.onSponsor!(widget.post.petId, amount);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
