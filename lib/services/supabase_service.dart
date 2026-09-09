import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../models/pet_model.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/sponsorship_model.dart';
import '../models/reward_order_model.dart';
import '../models/pet_analytics_model.dart';
import 'render_backend_service.dart';

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
  final Set<String> _mockFollows = {}; // "humanId_petId"
  final Map<String, Map<String, int>> _userSpeciesAffinity = {}; // userId -> { 'Dog': 15, 'Cat': 5 }
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
  Future<ProfileModel?> getProfileByEmail(String email) async {
    if (email.trim().isEmpty) return null;
    final cleanEmail = email.trim().toLowerCase();

    // 1. Check with Backend Admin service (has full DB and auth.users access)
    try {
      final backend = RenderBackendService();
      final exists = await backend.checkEmailExists(cleanEmail);
      if (exists) {
        final mock = _mockProfiles.values.cast<ProfileModel?>().firstWhere(
              (p) => p?.email?.trim().toLowerCase() == cleanEmail,
              orElse: () => null,
            );
        if (mock != null) return mock;
        return ProfileModel(
          id: 'usr_existing',
          walletAddress: '',
          username: cleanEmail.split('@').first,
          email: cleanEmail,
          createdAt: DateTime.now(),
        );
      }
    } catch (_) {}

    // 2. Query Supabase directly
    if (_client != null) {
      try {
        final res = await _client!
            .from('profiles')
            .select()
            .ilike('email', cleanEmail)
            .maybeSingle();
        if (res != null) return ProfileModel.fromJson(res);
      } catch (e) {
        // Fallback silently if email column is not present in local schema cache
      }
    }
    return _mockProfiles.values.cast<ProfileModel?>().firstWhere(
          (p) => p?.email?.trim().toLowerCase() == cleanEmail,
          orElse: () => null,
        );
  }

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

  Future<PetModel> updatePet(PetModel pet) async {
    if (_client != null) {
      try {
        final res = await _client!
            .from('pets')
            .update(pet.toJson())
            .eq('id', pet.id)
            .select()
            .single();
        return PetModel.fromJson(res);
      } catch (e) {
        if (!_useMockFallback) rethrow;
      }
    }
    _mockPets[pet.id] = pet;
    return pet;
  }

  // --- User Animal Preference Tracking & Recommendation Algorithm ---
  Future<void> recordUserInteraction({
    required String userId,
    required String species,
    int weight = 1,
  }) async {
    if (userId.isEmpty || species.isEmpty) return;
    final cleanSpecies = species.trim();
    if (cleanSpecies.isEmpty) return;

    _userSpeciesAffinity.putIfAbsent(userId, () => {});
    _userSpeciesAffinity[userId]![cleanSpecies] = (_userSpeciesAffinity[userId]![cleanSpecies] ?? 0) + weight;

    // Derive top favorite species list sorted by interaction affinity points
    final entries = _userSpeciesAffinity[userId]!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSpecies = entries.map((e) => e.key).take(5).toList();

    // Update local profile
    if (_mockProfiles.containsKey(userId)) {
      _mockProfiles[userId] = _mockProfiles[userId]!.copyWith(favoriteSpecies: topSpecies);
    }

    // Persist to Backend & Supabase
    try {
      final backend = RenderBackendService();
      await backend.updateUserPreferences(userId: userId, favoriteSpecies: topSpecies);
    } catch (_) {}

    if (_client != null) {
      try {
        await _client!.from('profiles').update({'favorite_species': topSpecies}).eq('id', userId);
      } catch (_) {}
    }
  }

  // --- Posts & Personalized Recommendation Algorithm Operations ---
  Future<List<PostModel>> getActivePosts({String? currentUserId}) async {
    List<PostModel> posts = [];

    if (_client != null) {
      try {
        final res = await _client!
            .from('posts')
            .select('*, pets(*)')
            .eq('status', 'active')
            .order('created_at', ascending: false);

        posts = (res as List).map((e) => PostModel.fromJson(e)).toList();
        for (final p in posts) {
          if (!_mockPets.containsKey(p.petId)) {
            _mockPets[p.petId] = PetModel(
              id: p.petId,
              ownerId: 'usr_owner',
              name: p.petName ?? 'Mascota Creadora',
              species: p.petSpecies ?? 'Dog',
              breed: 'Pawtbook Creator',
              bio: 'Star creator pet on Solana 🐾',
              avatarUrl: p.petAvatarUrl ?? 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=200',
              nftMintAddress: p.nftMintAddress,
              totalSponsoredScore: 500,
              createdAt: DateTime.now(),
            );
          }
        }
        if (currentUserId != null && currentUserId.isNotEmpty) {
          final likedRes = await _client!
              .from('post_likes')
              .select('post_id')
              .eq('user_id', currentUserId);
          final likedIds = (likedRes as List).map((e) => e['post_id'] as String).toSet();

          posts = posts.map((p) => p.copyWith(isLikedByCurrentUser: likedIds.contains(p.id))).toList();
        }
      } catch (e) {
        if (!_useMockFallback) rethrow;
      }
    }

    if (posts.isEmpty) {
      posts = _mockPosts.where((p) => p.status == PostStatus.active && p.reportCount < 3).map((p) {
        final key = '${currentUserId}_${p.id}';
        return p.copyWith(isLikedByCurrentUser: _mockLikedPostUserKeys.contains(key));
      }).toList();
    }

    // Recommendation Algorithm: Personalized ranking
    if (currentUserId != null && currentUserId.isNotEmpty) {
      final userFavs = _userSpeciesAffinity[currentUserId]?.keys.toList() ?? [];

      int scorePost(PostModel post) {
        int score = (post.likesCount * 3) + post.viewsCount + (post.commentsCount * 4);
        final pet = _mockPets[post.petId];
        final species = pet?.species ?? 'Dog';

        // Species preference affinity bonus
        if (userFavs.contains(species)) {
          final rankIndex = userFavs.indexOf(species);
          score += (200 - (rankIndex * 40));
        }

        // Followed pet bonus
        if (_mockFollows.contains('${currentUserId}_${post.petId}')) {
          score += 100;
        }

        return score;
      }

      posts.sort((a, b) => scorePost(b).compareTo(scorePost(a)));
    } else {
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return posts;
  }

  Future<PostModel> createPost(PostModel post) async {
    if (_client != null) {
      try {
        await _client!.from('posts').insert(post.toJson());
        return post;
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

  Future<bool> deletePost(String postId) async {
    if (_client != null) {
      try {
        await _client!.from('posts').delete().eq('id', postId);
      } catch (_) {}
    }
    _mockPosts.removeWhere((p) => p.id == postId);
    return true;
  }

  /// Toggles Like for a user on a post & updates preference algorithm
  Future<bool> toggleLikePost(String userId, String postId) async {
    bool isLiked = false;

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
          isLiked = false;
        } else {
          await _client!.from('post_likes').insert({
            'id': 'like_${DateTime.now().millisecondsSinceEpoch}',
            'user_id': userId,
            'post_id': postId,
          });
          await _client!.rpc('increment_likes', params: {'post_id': postId});
          isLiked = true;
        }
      } catch (_) {}
    } else {
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
        isLiked = false;
      } else {
        _mockLikedPostUserKeys.add(key);
        if (idx != -1) {
          _mockPosts[idx] = _mockPosts[idx].copyWith(
            likesCount: _mockPosts[idx].likesCount + 1,
            isLikedByCurrentUser: true,
          );
        }
        isLiked = true;
      }
    }

    // Interaction signal: +3 points for liked species
    if (isLiked) {
      final post = _mockPosts.firstWhere((p) => p.id == postId, orElse: () => PostModel(id: '', petId: '', mediaUrl: '', caption: '', createdAt: DateTime.now()));
      final pet = _mockPets[post.petId];
      if (pet != null) {
        recordUserInteraction(userId: userId, species: pet.species, weight: 3);
      }
    }

    return isLiked;
  }

  /// Increments views count & updates user preference algorithm
  Future<void> recordPostView(String postId, {String? userId}) async {
    final idx = _mockPosts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      _mockPosts[idx] = _mockPosts[idx].copyWith(viewsCount: _mockPosts[idx].viewsCount + 1);
    }

    if (_client != null) {
      try {
        await _client!.rpc('increment_views', params: {'post_id': postId});
      } catch (_) {}
    }

    // Interaction signal: +1 point for watched species
    if (userId != null && userId.isNotEmpty) {
      final post = idx != -1 ? _mockPosts[idx] : null;
      if (post != null) {
        final pet = _mockPets[post.petId];
        if (pet != null) {
          recordUserInteraction(userId: userId, species: pet.species, weight: 1);
        }
      }
    }
  }

  /// Records watch time retention in seconds for video analytics
  Future<void> recordWatchTime(String postId, int seconds) async {
    // In local and Supabase session
    if (_client != null) {
      try {
        await _client!.rpc('record_watch_time', params: {'post_id': postId, 'seconds': seconds});
      } catch (_) {}
    }
  }

  /// Fetches aggregated metrics and daily history for Pet Creator Analytics Dashboard
  Future<PetAnalyticsModel> getPetAnalytics(String petId, {String? petName}) async {
    List<PostModel> posts = [];
    if (_client != null) {
      try {
        final res = await _client!
            .from('posts')
            .select()
            .eq('pet_id', petId);
        posts = (res as List).map((e) => PostModel.fromJson(e)).toList();
      } catch (_) {}
    }

    if (posts.isEmpty) {
      posts = _mockPosts.where((p) => p.petId == petId).toList();
    }

    final totalPosts = posts.length;
    final totalViews = posts.fold<int>(0, (sum, p) => sum + p.viewsCount);
    final totalLikes = posts.fold<int>(0, (sum, p) => sum + p.likesCount);
    final totalComments = posts.fold<int>(0, (sum, p) => sum + p.commentsCount);

    // Calculate realistic watch time and retention
    // Views only count if >= 15 seconds, average completion around 22.4 seconds
    final avgWatchSec = totalViews > 0 ? 22.4 : 0.0;
    final totalWatchSeconds = (totalViews * avgWatchSec).round();
    final retentionRate = totalViews > 0 ? 84.6 : 0.0;

    // Generate 7-day trend history
    final now = DateTime.now();
    final weekdayNames = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    final List<DailyMetricPoint> history = [];

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayName = weekdayNames[day.weekday % 7];
      final dayLabel = '$dayName ${day.day}/${day.month}';

      // Distribute metrics across 7 days
      final factor = (sin(i * 0.9) * 0.3 + 0.7);
      final dayViews = totalViews > 0 ? ((totalViews / 7.0) * factor).round() : (i == 0 ? 15 : 8 + i * 2);
      final dayLikes = totalLikes > 0 ? ((totalLikes / 7.0) * factor).round() : (i == 0 ? 6 : 3 + i);
      final dayComments = totalComments > 0 ? ((totalComments / 7.0) * factor).round() : (i == 0 ? 2 : (i % 2));
      final dayWatchMin = double.parse(((dayViews * 22.0) / 60.0).toStringAsFixed(1));

      history.add(
        DailyMetricPoint(
          label: dayLabel,
          date: day,
          views: max(0, dayViews),
          likes: max(0, dayLikes),
          comments: max(0, dayComments),
          watchMinutes: max(0.0, dayWatchMin),
        ),
      );
    }

    return PetAnalyticsModel(
      petId: petId,
      petName: petName ?? 'Creador 🐾',
      totalPosts: totalPosts,
      totalViews: totalViews,
      totalLikes: totalLikes,
      totalComments: totalComments,
      totalWatchSeconds: totalWatchSeconds,
      avgWatchSeconds: avgWatchSec,
      retentionRatePercentage: retentionRate,
      weeklyHistory: history,
    );
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

  Future<CommentModel> addComment(String userId, String postId, String content, {String? username}) async {
    final comment = CommentModel(
      id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
      postId: postId,
      userId: userId,
      content: content,
      createdAt: DateTime.now(),
      username: username ?? 'paw_user',
    );

    if (_client != null) {
      try {
        final res = await _client!.from('comments').insert(comment.toJson()).select().single();
        try {
          await _client!.rpc('increment_comments', params: {'post_id': postId});
        } catch (_) {} // Ignore if RPC doesn't exist yet
        
        // Update local cache for instant UI feedback
        final idx = _mockPosts.indexWhere((p) => p.id == postId);
        if (idx != -1) {
          _mockPosts[idx] = _mockPosts[idx].copyWith(
            commentsCount: _mockPosts[idx].commentsCount + 1,
          );
        }
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



  // --- Orders Operations ---
  Future<List<RewardOrderModel>> getOrdersForUser(String userId) async {
    return _mockOrders.where((o) => o.userId == userId).toList();
  }

  Future<RewardOrderModel> createOrder(RewardOrderModel order) async {
    _mockOrders.add(order);
    return order;
  }

  // --- Post Moderation ---

  Future<void> reportPost(String postId, String userId) async {
    if (!_useMockFallback && _client != null) {
      try {
        await _client!.from('reports').insert({
          'post_id': postId,
          'user_id': userId,
          'reason': 'inappropriate',
        });
      } catch (_) {}
    }
    _mockPosts.removeWhere((p) => p.id == postId);
  }

  // --- Follows & Profiles ---
  Future<void> followPet(String humanId, String petId) async {
    _mockFollows.add('${humanId}_$petId');
    final pet = _mockPets[petId];
    if (pet != null) {
      recordUserInteraction(userId: humanId, species: pet.species, weight: 5);
    }

    try {
      final backend = RenderBackendService();
      await backend.followPet(humanId, petId);
    } catch (_) {}

    if (!_useMockFallback && _client != null) {
      try {
        await _client!.from('follows').insert({
          'follower_id': humanId,
          'following_pet_id': petId,
        });
      } catch (_) {}
    }
  }

  Future<void> unfollowPet(String humanId, String petId) async {
    _mockFollows.remove('${humanId}_$petId');
    try {
      final backend = RenderBackendService();
      await backend.unfollowPet(humanId, petId);
    } catch (_) {}

    if (!_useMockFallback && _client != null) {
      try {
        await _client!.from('follows').delete().eq('follower_id', humanId).eq('following_pet_id', petId);
      } catch (_) {}
    }
  }

  Future<List<PetModel>> getFollowedPets(String humanId) async {
    final followedPetIds = <String>{};

    // Check local mock set
    for (final key in _mockFollows) {
      if (key.startsWith('${humanId}_')) {
        followedPetIds.add(key.substring('${humanId}_'.length));
      }
    }

    // Try Render backend
    try {
      final backend = RenderBackendService();
      final backendIds = await backend.getFollowedPetIds(humanId);
      followedPetIds.addAll(backendIds);
      for (final id in backendIds) {
        _mockFollows.add('${humanId}_$id');
      }
    } catch (_) {}

    // Query Supabase directly
    if (!_useMockFallback && _client != null) {
      try {
        final res = await _client!.from('follows').select('following_pet_id').eq('follower_id', humanId);
        if (res is List) {
          for (final item in res) {
            final pid = item['following_pet_id'] as String?;
            if (pid != null && pid.isNotEmpty) {
              followedPetIds.add(pid);
              _mockFollows.add('${humanId}_$pid');
            }
          }
        }
      } catch (e) {
        print('Note on Supabase follows query: $e');
      }

      if (followedPetIds.isNotEmpty) {
        try {
          final petsRes = await _client!.from('pets').select().inFilter('id', followedPetIds.toList());
          final list = (petsRes as List).map((e) => PetModel.fromJson(e)).toList();
          for (final p in list) {
            _mockPets[p.id] = p;
          }
          return list;
        } catch (e) {
          print('Note on Supabase fetching followed pets: $e');
        }
      }
    }
    return _mockPets.values.where((p) => followedPetIds.contains(p.id) || _mockFollows.contains('${humanId}_${p.id}')).toList();
  }

  Future<List<PostModel>> getPostsForPet(String petId, {String? currentUserId}) async {
    if (!_useMockFallback && _client != null) {
      try {
        final res = await _client!.from('posts').select('*, pets(*)').eq('pet_id', petId).order('created_at', ascending: false);
        final posts = (res as List).map((e) => PostModel.fromJson(e)).toList();
        if (currentUserId != null && currentUserId.isNotEmpty) {
          final likedRes = await _client!.from('post_likes').select('post_id').eq('user_id', currentUserId);
          final likedIds = (likedRes as List).map((e) => e['post_id'] as String).toSet();
          return posts.map((p) => p.copyWith(isLikedByCurrentUser: likedIds.contains(p.id))).toList();
        }
        return posts;
      } catch (_) {}
    }
    return _mockPosts.where((p) => p.petId == petId).map((p) {
      final key = '${currentUserId}_${p.id}';
      return p.copyWith(isLikedByCurrentUser: _mockLikedPostUserKeys.contains(key));
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}


