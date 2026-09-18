import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/comment_model.dart';
import '../../services/supabase_service.dart';

class LiveCommentItem {
  final String username;
  final String comment;
  final String? avatarUrl;

  const LiveCommentItem({
    required this.username,
    required this.comment,
    this.avatarUrl,
  });
}

class LiveCommentBubbles extends StatefulWidget {
  final String? postId;
  final List<LiveCommentItem>? comments;
  final bool isVisible;
  final VoidCallback? onTap;

  const LiveCommentBubbles({
    super.key,
    this.postId,
    this.comments,
    this.isVisible = true,
    this.onTap,
  });

  @override
  State<LiveCommentBubbles> createState() => _LiveCommentBubblesState();
}

class _LiveCommentBubblesState extends State<LiveCommentBubbles> {
  final SupabaseService _supabaseService = SupabaseService();
  List<LiveCommentItem> _displayComments = [];
  int _currentIndex = 0;
  Timer? _bubbleTimer;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void didUpdateWidget(covariant LiveCommentBubbles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId || oldWidget.comments != widget.comments) {
      _loadComments();
    }
  }

  Future<void> _loadComments() async {
    // 1. If comments list passed explicitly, use it
    if (widget.comments != null) {
      _setComments(widget.comments!);
      return;
    }

    // 2. If postId is present, fetch REAL comments from Supabase
    if (widget.postId != null && widget.postId!.isNotEmpty) {
      try {
        final List<CommentModel> realComments =
            await _supabaseService.getCommentsForPost(widget.postId!);

        if (!mounted) return;

        // Filter out empty or whitespace comments
        final validComments = realComments
            .where((c) => c.content.trim().isNotEmpty)
            .map((c) => LiveCommentItem(
                  username: (c.username != null && c.username!.trim().isNotEmpty)
                      ? c.username!.trim()
                      : 'usuario',
                  comment: c.content.trim(),
                  avatarUrl: c.avatarUrl,
                ))
            .toList();

        _setComments(validComments);
      } catch (e) {
        debugPrint('[LiveCommentBubbles] Error fetching post comments: $e');
        if (mounted) _setComments([]);
      }
    } else {
      _setComments([]);
    }
  }

  void _setComments(List<LiveCommentItem> list) {
    _bubbleTimer?.cancel();
    _bubbleTimer = null;
    _currentIndex = 0;

    setState(() {
      _displayComments = list;
    });

    if (list.length > 1) {
      _bubbleTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (!mounted) return;
        setState(() {
          _currentIndex = (_currentIndex + 1) % _displayComments.length;
        });
      });
    }
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If hidden, loading, or no real comments exist on this post, do NOT show fake comments
    if (!widget.isVisible || _displayComments.isEmpty) {
      return const SizedBox.shrink();
    }

    final item = _displayComments[_currentIndex];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey<String>('${widget.postId}_${_currentIndex}_${item.comment}'),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.48),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFFFF6B6B),
                backgroundImage: item.avatarUrl != null && item.avatarUrl!.isNotEmpty
                    ? NetworkImage(item.avatarUrl!)
                    : null,
                child: (item.avatarUrl == null || item.avatarUrl!.isEmpty)
                    ? const Icon(Icons.pets, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                '@${item.username}: ',
                style: GoogleFonts.fredoka(
                  color: const Color(0xFFFF9E7D),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Flexible(
                child: Text(
                  item.comment,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
