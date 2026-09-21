import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/pet_model.dart';
import '../models/profile_model.dart';
import '../services/supabase_service.dart';
import '../services/r2_storage_service.dart';
import '../services/render_backend_service.dart';

class FeedController extends ChangeNotifier {
  final SupabaseService _supabaseService;
  final R2StorageService _r2StorageService;
  final RenderBackendService _renderBackendService;

  List<PostModel> _posts = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<PostModel> get posts => List.unmodifiable(_posts);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  FeedController({
    SupabaseService? supabaseService,
    R2StorageService? r2StorageService,
    RenderBackendService? renderBackendService,
  })  : _supabaseService = supabaseService ?? SupabaseService(),
        _r2StorageService = r2StorageService ?? R2StorageService(),
        _renderBackendService = renderBackendService ?? RenderBackendService();

  Future<void> fetchActivePosts({String? currentUserId}) async {
    _setLoading(true);
    try {
      _posts = await _supabaseService.getActivePosts(currentUserId: currentUserId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // --- Follows & Pet Profile ---
  final Set<String> _followedPetIds = {};
  Set<String> get followedPetIds => _followedPetIds;
  bool isFollowingPet(String petId) => _followedPetIds.contains(petId);

  Future<void> followPet(String humanId, String petId) async {
    _followedPetIds.add(petId);
    notifyListeners();
    await _supabaseService.followPet(humanId, petId);
  }

  Future<void> unfollowPet(String humanId, String petId) async {
    _followedPetIds.remove(petId);
    notifyListeners();
    await _supabaseService.unfollowPet(humanId, petId);
  }

  Future<List<PetModel>> getFollowedPets(String humanId) async {
    final pets = await _supabaseService.getFollowedPets(humanId);
    _followedPetIds.addAll(pets.map((p) => p.id));
    return pets;
  }

  Future<List<ProfileModel>> getFollowersForPet(String petId) async {
    return await _supabaseService.getFollowersForPet(petId);
  }

  Future<List<PostModel>> getPostsForPet(String petId, {String? currentUserId}) async {
    return await _supabaseService.getPostsForPet(petId, currentUserId: currentUserId);
  }

  /// Creates a new post for a pet. Enforces ROLE RESTRICTION & Moderation Pipeline.
  /// Creates a new post for a pet. Enforces ROLE RESTRICTION & Moderation Pipeline.
  Future<PostModel?> createPetPost({
    required PetModel? pet,
    required List<int> mediaBytes,
    required String filename,
    required String mediaType,
    required String caption,
    List<List<int>>? extraMediaBytes,
    List<String>? extraFilenames,
    String? soundUrl,
    String? soundTitle,
    String? forceModerationDecision,
    Uint8List? overlayPngBytes,
    double? startSeconds,
    double? endSeconds,
    double? originalVolume,
    double? musicVolume,
  }) async {
    // 1. Role Check: Only Pet Creators can publish
    if (pet == null || pet.id.isEmpty) {
      throw Exception('ROLE_RESTRICTION: Only Pet Profiles can upload content. Human sponsors must register a pet first.');
    }

    _setLoading(true);
    try {
      // 2. Obtain R2 Presigned Upload URL from Backend API for primary media
      final uploadRes = await _renderBackendService.requestUploadUrl(
        petId: pet.id,
        mediaType: mediaType,
        filename: filename,
      );

      if (uploadRes['success'] != true) {
        throw Exception(uploadRes['error'] ?? 'Failed to get upload URL');
      }

      final presignedPutUrl = uploadRes['presignedPutUrl'] as String;
      final publicUrl = uploadRes['publicUrl'] as String;

      // 3. Upload Original File to Cloudflare R2
      String finalUploadedUrl = await _r2StorageService.uploadMediaWithPresignedUrl(
        presignedPutUrl: presignedPutUrl,
        publicUrl: publicUrl,
        bytes: mediaBytes,
        contentType: mediaType == 'video' ? 'video/mp4' : 'image/jpeg',
      );

      String? finalSoundUrl = soundUrl;
      String? finalSoundTitle = soundTitle;

      // 3B. Si es video y tiene audio, overlays o recortes, procesarlo mediante el pipeline FFmpeg en backend
      if (mediaType == 'video') {
        final hasOverlays = overlayPngBytes != null && overlayPngBytes.isNotEmpty;
        final hasSound = soundUrl != null && soundUrl.isNotEmpty;
        final hasTrim = (startSeconds != null && startSeconds > 0) || (endSeconds != null && endSeconds < 30.0);

        if (hasOverlays || hasSound || hasTrim) {
          try {
            debugPrint('[FeedController] 🎬 Procesando video con FFmpeg: overlays=$hasOverlays, audio=$hasSound');
            final processRes = await _renderBackendService.processVideo(
              petId: pet.id,
              videoUrl: finalUploadedUrl,
              overlayPngBytes: overlayPngBytes,
              soundUrl: soundUrl,
              startSeconds: startSeconds ?? 0.0,
              endSeconds: endSeconds ?? AppConfig.maxVideoDurationSeconds,
              originalVolume: originalVolume ?? 1.0,
              musicVolume: musicVolume ?? 0.8,
            );

            if (processRes['success'] == true && processRes['publicUrl'] != null) {
              finalUploadedUrl = processRes['publicUrl'] as String;
              debugPrint('[FeedController] ✅ Video procesado exitosamente: $finalUploadedUrl');

              // Si el audio quedó integrado directamente en la pista del archivo de video,
              // evitamos que el reproductor de feed reproduzca una pista externa duplicada
              if (processRes['audioIntegrated'] == true) {
                finalSoundUrl = null;
              }
            } else {
              debugPrint('[FeedController] ⚠️ FFmpeg no disponible o falló, usando video original: ${processRes["error"]}');
            }
          } catch (procEx) {
            debugPrint('[FeedController] ⚠️ Excepción en processVideo, continuando con video base: $procEx');
          }
        }
      }

      final List<String> allUploadedUrls = [finalUploadedUrl];

      // Upload any additional images
      if (extraMediaBytes != null && extraMediaBytes.isNotEmpty) {
        for (int i = 0; i < extraMediaBytes.length; i++) {
          final extraName = (extraFilenames != null && i < extraFilenames.length)
              ? extraFilenames[i]
              : 'extra_${i + 1}.jpg';
          try {
            final extraRes = await _renderBackendService.requestUploadUrl(
              petId: pet.id,
              mediaType: 'image',
              filename: extraName,
            );
            if (extraRes['success'] == true) {
              final extraPutUrl = extraRes['presignedPutUrl'] as String;
              final extraPublicUrl = extraRes['publicUrl'] as String;
              final extraUploaded = await _r2StorageService.uploadMediaWithPresignedUrl(
                presignedPutUrl: extraPutUrl,
                publicUrl: extraPublicUrl,
                bytes: extraMediaBytes[i],
                contentType: 'image/jpeg',
              );
              allUploadedUrls.add(extraUploaded);
            }
          } catch (e) {
            print('Error uploading extra image $i: $e');
          }
        }
      }

      // 4. Create Post record with status = pending_review
      final postId = 'post_' + const Uuid().v4().substring(0, 8);
      final newPost = PostModel(
        id: postId,
        petId: pet.id,
        mediaUrl: finalUploadedUrl,
        mediaUrls: allUploadedUrls,
        mediaType: mediaType,
        caption: caption,
        status: PostStatus.pendingReview,
        createdAt: DateTime.now(),
        soundUrl: finalSoundUrl,
        soundTitle: finalSoundTitle,
        petName: pet.name,
        petAvatarUrl: pet.avatarUrl,
        nftMintAddress: pet.nftMintAddress,
      );

      final insertedPost = await _supabaseService.createPost(newPost);

      // 5. Trigger Backend Safety & Animal Welfare Moderation Webhook
      final modRes = await _renderBackendService.triggerModeration(
        postId: postId,
        mediaUrl: finalUploadedUrl,
        forceDecision: forceModerationDecision,
      );

      final finalStatusStr = modRes['status'] as String?;
      if (finalStatusStr == 'active') {
        await _supabaseService.updatePostStatus(postId, PostStatus.active);
        final activePost = insertedPost.copyWith(status: PostStatus.active);
        _posts.insert(0, activePost);
        notifyListeners();
        return activePost;
      } else {
        await _supabaseService.updatePostStatus(postId, PostStatus.rejected);
        throw Exception('MODERATION_REJECTED');
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sponsorPet(String petId, int pawtScoreAmount, {String sponsorId = 'usr_guest'}) async {
    await _supabaseService.sponsorPet(
      sponsorId: sponsorId,
      petId: petId,
      amount: pawtScoreAmount,
    );
    notifyListeners();
  }

  Future<void> reportPost(String postId, {String userId = 'usr_guest'}) async {
    await _supabaseService.reportPost(postId, userId);
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      final current = _posts[idx];
      final newCount = current.reportCount + 1;
      if (newCount >= 3) {
        _posts.removeAt(idx); // Auto-hide post from feed
      } else {
        _posts[idx] = current.copyWith(reportCount: newCount);
      }
      notifyListeners();
    }
  }


  Future<void> deletePetPost(String postId) async {
    _setLoading(true);
    try {
      await _supabaseService.deletePost(postId);
      _posts.removeWhere((p) => p.id == postId);
      notifyListeners();
    } catch (e) {
      print('Error deleting post: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Toggles Like for a post with instant 0ms optimistic UI update
  Future<void> toggleLikePost(String userId, String postId) async {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final current = _posts[idx];
    final bool newLikedState = !current.isLikedByCurrentUser;
    final int newCount = newLikedState
        ? current.likesCount + 1
        : (current.likesCount > 0 ? current.likesCount - 1 : 0);

    // 1. Optimistic Update Inmediato (0 ms)
    _posts[idx] = current.copyWith(
      likesCount: newCount,
      isLikedByCurrentUser: newLikedState,
    );
    notifyListeners();

    // 2. Persistencia en Supabase
    try {
      final isLikedNow = await _supabaseService.toggleLikePost(userId, postId);
      if (isLikedNow != newLikedState) {
        final curIdx = _posts.indexWhere((p) => p.id == postId);
        if (curIdx != -1) {
          _posts[curIdx] = _posts[curIdx].copyWith(isLikedByCurrentUser: isLikedNow);
          notifyListeners();
        }
      }
    } catch (e) {
      // Revertir si hay fallo
      final curIdx = _posts.indexWhere((p) => p.id == postId);
      if (curIdx != -1) {
        _posts[curIdx] = current;
        notifyListeners();
      }
    }
  }

  /// Adds a comment to a post and immediately increments commentsCount in FeedController (0ms latency)
  Future<CommentModel> addCommentToPost({
    required String userId,
    required String postId,
    required String content,
    String? username,
    String? parentId,
    String? replyToUsername,
  }) async {
    // 1. Incremento inmediato optimista en memoria
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      _posts[idx] = _posts[idx].copyWith(
        commentsCount: _posts[idx].commentsCount + 1,
      );
      notifyListeners();
    }

    // 2. Persistencia en Supabase
    return await _supabaseService.addComment(
      userId,
      postId,
      content,
      username: username,
      parentId: parentId,
      replyToUsername: replyToUsername,
    );
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
