import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../models/pet_model.dart';
import '../models/post_model.dart';
import '../models/reward_order_model.dart';

class SupabaseService {
  SupabaseClient? _client;
  final bool _useMockFallback;

  // In-memory mock database for dev/testing when Supabase backend is unreachable
  final Map<String, ProfileModel> _mockProfiles = {};
  final Map<String, PetModel> _mockPets = {};
  final List<PostModel> _mockPosts = [];
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
        mediaUrl: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=800',
        mediaType: 'image',
        caption: 'First day at the park! #Pawtbook #SolanaPets',
        likesCount: 24,
        status: PostStatus.active,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        petName: 'Luna',
        petAvatarUrl: 'https://images.unsplash.com/photo-1552053831-71594a27632d?w=400',
        nftMintAddress: 'SolLuna777...Mint',
      ),
      PostModel(
        id: 'post_demo_2',
        petId: 'pet_demo_2',
        mediaUrl: 'https://images.unsplash.com/photo-1573865526739-10659fec78a5?w=800',
        mediaType: 'image',
        caption: 'Chilling on a Sunday afternoon 🐱☕',
        likesCount: 18,
        status: PostStatus.active,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        petName: 'Milo',
        petAvatarUrl: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=400',
        nftMintAddress: 'SolMilo888...Mint',
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

  // --- Posts Operations (Strict Safety: Active Status Only & RLS check) ---
  Future<List<PostModel>> getActivePosts() async {
    if (_client != null) {
      try {
        final res = await _client!
            .from('posts')
            .select('*, pets(*)')
            .eq('status', 'active')
            .order('created_at', ascending: false);
        return (res as List).map((e) => PostModel.fromJson(e)).toList();
      } catch (e) {
        if (!_useMockFallback) rethrow;
      }
    }
    return _mockPosts.where((p) => p.status == PostStatus.active && p.reportCount < 3).toList()
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

  Future<void> sponsorPet(String petId, int pawtScoreAmount) async {
    if (_mockPets.containsKey(petId)) {
      final pet = _mockPets[petId]!;
      _mockPets[petId] = PetModel(
        id: pet.id,
        ownerId: pet.ownerId,
        name: pet.name,
        species: pet.species,
        breed: pet.breed,
        bio: pet.bio,
        avatarUrl: pet.avatarUrl,
        nftMintAddress: pet.nftMintAddress,
        totalSponsoredScore: pet.totalSponsoredScore + pawtScoreAmount,
        createdAt: pet.createdAt,
      );
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
