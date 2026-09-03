import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/post_model.dart';
import '../models/pet_model.dart';
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

  Future<void> fetchActivePosts() async {
    _setLoading(true);
    try {
      _posts = await _supabaseService.getActivePosts();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Creates a new post for a pet. Enforces ROLE RESTRICTION & Moderation Pipeline.
  Future<PostModel?> createPetPost({
    required PetModel? pet,
    required List<int> mediaBytes,
    required String filename,
    required String mediaType,
    required String caption,
    String? forceModerationDecision,
  }) async {
    // 1. Role Check: Only Pet Creators can publish
    if (pet == null || pet.id.isEmpty) {
      throw Exception('ROLE_RESTRICTION: Only Pet Profiles can upload content. Human sponsors must register a pet first.');
    }

    _setLoading(true);
    try {
      // 2. Obtain R2 Presigned Upload URL from Backend API
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

      // 3. Upload File to Cloudflare R2
      final uploadedUrl = await _r2StorageService.uploadMediaWithPresignedUrl(
        presignedPutUrl: presignedPutUrl,
        publicUrl: publicUrl,
        bytes: mediaBytes,
        contentType: mediaType == 'video' ? 'video/mp4' : 'image/jpeg',
      );

      // 4. Create Post record with status = pending_review
      final postId = 'post_' + const Uuid().v4().substring(0, 8);
      final newPost = PostModel(
        id: postId,
        petId: pet.id,
        mediaUrl: uploadedUrl,
        mediaType: mediaType,
        caption: caption,
        status: PostStatus.pendingReview,
        createdAt: DateTime.now(),
        petName: pet.name,
        petAvatarUrl: pet.avatarUrl,
        nftMintAddress: pet.nftMintAddress,
      );

      final insertedPost = await _supabaseService.createPost(newPost);

      // 5. Trigger Backend Safety & Animal Welfare Moderation Webhook
      final modRes = await _renderBackendService.triggerModeration(
        postId: postId,
        mediaUrl: uploadedUrl,
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
        throw Exception('MODERATION_REJECTED: ');
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

  Future<void> reportPost(String postId) async {
    await _supabaseService.reportPost(postId);
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

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
