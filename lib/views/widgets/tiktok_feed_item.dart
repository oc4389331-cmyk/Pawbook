import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/post_model.dart';
import '../../models/pet_model.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../services/app_audio_player.dart';
import 'app_video_player_widget.dart';

class TikTokFeedItem extends StatefulWidget {
  final PostModel post;
  final String currentUserId;
  final bool isCurrentPage;
  final VoidCallback? onLikeToggled;
  final Future<bool> Function()? onPlayAttempt;

  const TikTokFeedItem({
    super.key,
    required this.post,
    required this.currentUserId,
    this.isCurrentPage = true,
    this.onLikeToggled,
    this.onPlayAttempt,
  });

  @override
  State<TikTokFeedItem> createState() => _TikTokFeedItemState();
}

class _TikTokFeedItemState extends State<TikTokFeedItem> with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  final Stopwatch _watchStopwatch = Stopwatch();
  bool _viewRecorded = false;

  // Multi-image PageView state
  int _currentImageIndex = 0;
  final PageController _imagePageController = PageController();

  // Audio player & rotating music disc animation
  AppAudioPlayer? _audioPlayer;
  bool _isPlayingSound = false;
  bool _isMuted = false;
  late AnimationController _discAnimationController;

  @override
  void initState() {
    super.initState();
    _watchStopwatch.start();
    _recordView();

    _discAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    if (widget.post.hasSound) {
      _initAudioPlayer();
    }
  }

  void _recordView() {
    if (_viewRecorded) return;
    _viewRecorded = true;
    _supabaseService.recordPostView(widget.post.id, userId: widget.currentUserId);
  }

  Future<void> _initAudioPlayer() async {
    try {
      _audioPlayer = AppAudioPlayer();

      _audioPlayer!.onPlayingChanged.listen((playing) {
        if (!mounted) return;
        setState(() => _isPlayingSound = playing);
        if (playing) {
          if (!_discAnimationController.isAnimating) {
            _discAnimationController.repeat();
          }
        } else {
          _discAnimationController.stop();
        }
      });

      if (widget.isCurrentPage && !_isMuted && widget.post.soundUrl != null) {
        await _audioPlayer!.play(widget.post.soundUrl!, loop: true);
      }
    } catch (e) {
      debugPrint('[TikTokFeedItem] Audio player init error: $e');
    }
  }

  @override
  void didUpdateWidget(covariant TikTokFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.hasSound && _audioPlayer != null) {
      if (widget.isCurrentPage && !_isMuted) {
        if (!_isPlayingSound && widget.post.soundUrl != null) {
          _audioPlayer!.play(widget.post.soundUrl!, loop: true);
        }
      } else {
        if (_isPlayingSound) {
          _audioPlayer!.pause();
        }
      }
    }
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    if (_audioPlayer != null && widget.post.hasSound) {
      if (_isMuted) {
        _audioPlayer!.pause();
      } else if (widget.isCurrentPage && widget.post.soundUrl != null) {
        _audioPlayer!.play(widget.post.soundUrl!, loop: true);
      }
    }
  }

  @override
  void dispose() {
    _watchStopwatch.stop();
    final elapsedSeconds = _watchStopwatch.elapsed.inSeconds;
    if (elapsedSeconds > 0) {
      _supabaseService.recordWatchTime(widget.post.id, elapsedSeconds);
    }
    _imagePageController.dispose();
    _discAnimationController.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaList = widget.post.allMediaUrls;
    final hasMultiple = mediaList.length > 1;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Media Area (Multi-Image Carousel OR Single Image / Video)
        if (hasMultiple) ...[
          PageView.builder(
            controller: _imagePageController,
            scrollDirection: Axis.horizontal,
            itemCount: mediaList.length,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              return _buildMediaImage(mediaList[index]);
            },
          ),

          // Top-right multi-image counter badge
          Positioned(
            top: 70,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '${_currentImageIndex + 1}/${mediaList.length}',
                    style: GoogleFonts.fredoka(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Pagination Dots
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(mediaList.length, (index) {
                final isSelected = index == _currentImageIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isSelected ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.accentOrange : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ] else if (widget.post.mediaType == 'video') ...[
          AppVideoPlayerWidget(
            videoUrl: widget.post.mediaUrl,
            isCurrentPage: widget.isCurrentPage,
            isMuted: _isMuted || widget.post.hasSound,
            loop: true,
            fit: BoxFit.contain,
            onPlayAttempt: widget.onPlayAttempt,
          ),
        ] else ...[
          _buildMediaImage(widget.post.mediaUrl),
        ],

        // 2. Sound Playing Indicator / Mute Toggle (Top-Left under header)
        if (widget.post.hasSound)
          Positioned(
            top: 70,
            left: 16,
            child: GestureDetector(
              onTap: _toggleMute,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accentOrange.withOpacity(0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RotationTransition(
                      turns: _discAnimationController,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryTerracotta,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isMuted ? Icons.volume_off_rounded : Icons.music_note_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        widget.post.soundTitle ?? 'Audio Original',
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMediaImage(String url) {
    return Container(
      color: Colors.black,
      child: Image.network(
        url.contains('mixkit')
            ? 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=1000'
            : url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF09090B),
          child: const Center(
            child: Icon(Icons.pets_rounded, size: 80, color: AppTheme.primaryTerracotta),
          ),
        ),
      ),
    );
  }
}

extension PostDummyPetExt on PostModel {
  PetModel toPetModel() {
    return PetModel(
      id: petId,
      ownerId: 'usr_owner',
      name: petName ?? 'Mascota Creadora',
      species: petSpecies ?? 'Pet',
      breed: 'Pawtbook Creator',
      bio: 'Star creator pet on Solana 🐾',
      avatarUrl: petAvatarUrl ?? 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=200',
      nftMintAddress: nftMintAddress,
      totalSponsoredScore: 500,
      createdAt: DateTime.now(),
    );
  }
}
