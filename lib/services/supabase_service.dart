import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../models/pet_model.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/sponsorship_model.dart';
import '../models/reward_order_model.dart';

class SupabaseService {
  SupabaseClient? _client;
  final bool _useMockFallback;

  // In-memory mock database for dev/testing when Supabase backend is unreachable
  final Map<String, ProfileModel> _mockProfiles = {};
  final Map<String, PetModel> _mockPets = {};
  final List<PostModel> _mockPosts = [];
  final List<CommentModel> _mockComments = [];
  final List<SponsorshipModel> _mockSponsorships = [];
  final Set<String> _mockLikedPostUserKeys = {}; // "userId_postId"
  final List<RewardOrderModel> _mockOrders = [];

  SupabaseService({bool useMockFallback = true}) : _useMockFallback = useMockFallback {
    try {
      _client = Supabase.instance.client;
    } catch (_) {
      // Supabase uninitialized or offline, fallback to mock store
    }
    _seedMockData();
  }

  void _seedMockData() {
    if (_mockPosts.isNotEmpty) return;
    
    final samplePet = PetModel(
      id: 'pet_demo_1',
      ownerId: 'usr_demo_123',
      name: 'Luna',
      species: 'Dog',
      breed: 'Golden Retriever',
      bio: 'Energetic beach lover 🐾 Solana native pet!',
      avatarUrl: 'https://images.unsplash.com/photo-1552053831-71594a27632d?w=400',
      nftMintAddress: 'SolLuna777...Mint',
      totalSponsoredScore: 450,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );
    _mockPets[samplePet.id] = samplePet;

    final samplePet2 = PetModel(
      id: 'pet_demo_2',
      ownerId: 'usr_demo_456',
      name: 'Milo',
      species: 'Cat',
      breed: 'Siamese',
      bio: 'King of sleeping & catching laser beams 👑',
      avatarUrl: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=400',
      nftMintAddress: 'SolMilo888...Mint',
      totalSponsoredScore: 210,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    );
    _mockPets[samplePet2.id] = samplePet2;

    _mockPosts.addAll([
      PostModel(
        id: 'post_demo_1',
        petId: 'pet_demo_1',
        mediaUrl: 'https://assets.mixkit.co/videos/preview/mixkit-playful-puppy-in-the-grass-42240-large.mp4',
        mediaType: 'video',
        caption: 'First day at the park! 🐾 #Pawtbook #SolanaPets',
        likesCount: 142,
        viewsCount: 1890,
        commentsCount: 12,
        tags: ['dog', 'golden', 'park'],
        status: PostStatus.active,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        petName: 'Luna',
        petAvatarUrl: 'https://images.unsplash.com/photo-1552053831-71594a27632d?w=400',
        nftMintAddress: 'SolLuna777...Mint',
      ),
      PostModel(
        id: 'post_demo_2',
        petId: 'pet_demo_2',
        mediaUrl: 'https://assets.mixkit.co/videos/preview/mixkit-cat-looking-at-the-camera-42526-large.mp4',
        mediaType: 'video',
        caption: 'Chilling on a Sunday afternoon 🐱☕ #Pawtbook',
        likesCount: 98,
        viewsCount: 1240,
        commentsCount: 8,
        tags: ['cat', 'siamese', 'chill'],
        status: PostStatus.active,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        petName: 'Milo',
        petAvatarUrl: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=400',
        nftMintAddress: 'SolMilo888...Mint',
      ),
    ]);

    _mockComments.addAll([
      CommentModel(
        id: 'cmt_1',
        postId: 'post_demo_1',
        userId: 'usr_demo_456',
        content: 'So cute!! Loving the energy 🐶❤️',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        username: 'paw_milo_owner',
      ),
    ]);
  }

  // --- Profile Operations ---
  Future<ProfileModel?> getProfileByWallet(String walletAddress) async {
    if (_client != null) {
      try {
        final res = await _client!
            .from('profiles')
            .select()
            .eq('wallet_address', walletAddress)
            .maybeSingle();
        if (res != null) return ProfileModel.fromJson(res);
      } catch (e) {
        if (!_useMockFallback) rethrow;
      }
    }
    return _mockProfiles.values.cast<ProfileModel?>().firstWhere(
          (p) => p?.walletAddress == walletAddress,
          orElse: () => null,
        );
  }

  Future<ProfileModel> createProfile(ProfileModel profile) async {
    if (_client != null) {
      try {
        final res = await _client!
            .from('profiles')
            .insert(profile.toJson())
            .select()
            .single();
        return ProfileModel.fromJson(res);
      } catch (e) {
        if (!_useMockFallback) rethrow;
      }
    }
    _mockProfiles[profile.id] = profile;
    return profile;
  }

  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    if (_client != null) {
      try {
        final res = await _client!
            .from('profiles')
            .update(profile.toJson())
            .eq('id', profile.id)
            .select()
            .single();
        return ProfileModel.fromJson(res);
      } catch (e) {
        if (!_useMockFallback) rethrow;
      }
    }
    _mockProfiles[profile.id] = profile;
    return profile;
  }

  // --- Pet Operations ---
  Future<List<PetModel>> getPetsForOwner(String ownerId) async {
    if (_client != null) {
      try {
        final res = await _client!
            .from('pets')
            .select()
            .eq('owner_id', ownerId);
        return (res as List).map((e) => PetModel.fromJson(e)).toList();
      } catch (e) {
        if (!_useMockFallback) rethrow;
      }
    }
    return _mockPets.values.where((p) => p.ownerId == ownerId).toList();
  }

  Future<PetModel> createPet(PetModel pet) async {
    if (_client != null) {
      try {
        final res = await _client!.from('pets').insert(pet.toJson()).select().single();
        return PetModel.fromJson(res);
      } catch (e) {
        if (!_useMockFallback) rethrow;
      }
    }
    _mockPets[pet.id] = pet;
    return pet;
  }

  // --- Posts & Recommendation Algorithm Operations ---
  Future<List<PostModel>> getActivePosts({String? currentUserId}) async {
    if (_client != null) {
      try {
        final res = await _client!
            .from('posts')
            .select('*, pets(*)')
            .eq('status', 'active')
            .order('created_at', ascending: false);

        final posts = (res as List).map((e) => PostModel.fromJson(e)).toList();
        if (currentUserId != null && currentUserId.isNotEmpty) {
          final likedRes = await _client!
              .from('post_likes')
              .select('post_id')
              .eq('user_id', currentUserId);
          final likedIds = (likedRes as List).map((e) => e['post_id'] as String).toSet();

          return posts.map((p) => p.copyWith(isLikedByCurrentUser: likedIds.contains(p.id))).toList();
        }
        return posts;
      } catch (e) {
        if (!_useMockFallback) rethrow;
      }
    }

    return _mockPosts.where((p) => p.status == PostStatus.active && p.reportCount < 3).map((p) {
      final key = '${currentUserId}_${p.id}';
      return p.copyWith(isLikedByCurrentUser: _mockLikedPostUserKeys.contains(key));
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<PostModel> createPost(PostModel post) async {
    if (_client != null) {
      try {
        final res = await _client!.from('posts').insert(post.toJson()).select().single();
        return PostModel.fromJson(res);
      } catch (e) {
        if (!_useMockFallback) throw Exception('Supabase RLS Error inserting post: $e');
      }
    }

    // Fallback Mock Validation
    if (post.petId.isEmpty || !_mockPets.containsKey(post.petId)) {
      throw Exception('RLS_VIOLATION: Human profile without registered pet cannot publish media posts');
    }

    final pet = _mockPets[post.petId];
    final fullPost = post.copyWith(
      petName: pet?.name ?? 'Pet',
      petAvatarUrl: pet?.avatarUrl ?? '',
      nftMintAddress: pet?.nftMintAddress,
    );
    _mockPosts.insert(0, fullPost);
    return fullPost;
  }

  /// Toggles Like for a user on a post
  Future<bool> toggleLikePost(String userId, String postId) async {
    if (_client != null) {
      try {
        final existing = await _client!
            .from('post_likes')
            .select()
            .eq('user_id', userId)
            .eq('post_id', postId)
            .maybeSingle();

        if (existing != null) {
          await _client!.from('post_likes').delete().eq('user_id', userId).eq('post_id', postId);
          await _client!.rpc('decrement_likes', params: {'post_id': postId});
          return false; // Now un-liked
        } else {
          await _client!.from('post_likes').insert({
            'id': 'like_${DateTime.now().millisecondsSinceEpoch}',
            'user_id': userId,
            'post_id': postId,
          });
          await _client!.rpc('increment_likes', params: {'post_id': postId});
          return true; // Now liked
        }
      } catch (_) {}
    }

    // Mock Fallback
    final key = '${userId}_$postId';
    final idx = _mockPosts.indexWhere((p) => p.id == postId);
    if (_mockLikedPostUserKeys.contains(key)) {
      _mockLikedPostUserKeys.remove(key);
      if (idx != -1) {
        _mockPosts[idx] = _mockPosts[idx].copyWith(
          likesCount: max(0, _mockPosts[idx].likesCount - 1),
          isLikedByCurrentUser: false,
        );
      }
      return false;
    } else {
      _mockLikedPostUserKeys.add(key);
      if (idx != -1) {
        _mockPosts[idx] = _mockPosts[idx].copyWith(
          likesCount: _mockPosts[idx].likesCount + 1,
          isLikedByCurrentUser: true,
        );
      }
      return true;
    }
  }

  /// Increments views count for recommendation algorithm
  Future<void> recordPostView(String postId) async {
    final idx = _mockPosts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      _mockPosts[idx] = _mockPosts[idx].copyWith(viewsCount: _mockPosts[idx].viewsCount + 1);
    }

    if (_client != null) {
      try {
        await _client!.rpc('increment_views', params: {'post_id': postId});
      } catch (_) {}
    }
  }

  // --- Comments Operations ---
  Future<List<CommentModel>> getCommentsForPost(String postId) async {
    if (_client != null) {
      try {
        final res = await _client!
            .from('comments')
            .select('*, profiles(username)')
            .eq('post_id', postId)
            .order('created_at', ascending: false);
        return (res as List).map((e) => CommentModel.fromJson(e)).toList();
      } catch (_) {}
    }

    return _mockComments.where((c) => c.postId == postId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<CommentModel> addComment(String userId, String postId, String content) async {
    final comment = CommentModel(
      id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
      postId: postId,
      userId: userId,
      content: content,
      createdAt: DateTime.now(),
      username: 'paw_user',
    );

    if (_client != null) {
      try {
        final res = await _client!.from('comments').insert(comment.toJson()).select().single();
        return CommentModel.fromJson(res);
      } catch (_) {}
    }

    _mockComments.insert(0, comment);
    final idx = _mockPosts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      _mockPosts[idx] = _mockPosts[idx].copyWith(
        commentsCount: _mockPosts[idx].commentsCount + 1,
      );
    }

    return comment;
  }

  // --- Sponsorship Operations (Dual Payment: Stripe / Solana Pay) ---
  Future<void> sponsorPet({
    required String sponsorId,
    required String petId,
    required int amount,
    String paymentMethod = 'stripe',
    String? txHash,
  }) async {
    final sponsorship = SponsorshipModel(
      id: 'spn_${DateTime.now().millisecondsSinceEpoch}',
      sponsorId: sponsorId,
      petId: petId,
      amount: amount,
      paymentMethod: paymentMethod,
      txHash: txHash,
      createdAt: DateTime.now(),
    );

    _mockSponsorships.add(sponsorship);

    if (_mockPets.containsKey(petId)) {
      final pet = _mockPets[petId]!;
      _mockPets[petId] = pet.copyWith(
        totalSponsoredScore: pet.totalSponsoredScore + amount,
      );
    }

    if (_client != null) {
      try {
        await _client!.from('sponsorships').insert(sponsorship.toJson());
        await _client!.rpc('increment_pet_sponsorship', params: {
          'pet_id': petId,
          'amount': amount,
        });
      } catch (_) {}
    }
  }

  Future<void> updatePostStatus(String postId, PostStatus newStatus) async {
    final idx = _mockPosts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      _mockPosts[idx] = _mockPosts[idx].copyWith(status: newStatus);
    }
  }

  Future<void> reportPost(String postId) async {
    final idx = _mockPosts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      final current = _mockPosts[idx];
      _mockPosts[idx] = current.copyWith(reportCount: current.reportCount + 1);
    }
  }

  // --- Orders Operations ---
  Future<List<RewardOrderModel>> getOrdersForUser(String userId) async {
    return _mockOrders.where((o) => o.userId == userId).toList();
  }

  Future<RewardOrderModel> createOrder(RewardOrderModel order) async {
    _mockOrders.add(order);
    return order;
  }
}
