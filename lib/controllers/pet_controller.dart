import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/reward_order_model.dart';
import '../services/supabase_service.dart';

class RewardItem {
  final String id;
  final String title;
  final String description;
  final int pointsCost;
  final String imageUrl;

  RewardItem({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsCost,
    required this.imageUrl,
  });
}

class PetController extends ChangeNotifier {
  final SupabaseService _supabaseService;

  List<RewardOrderModel> _userOrders = [];
  bool _isLoading = false;

  List<RewardOrderModel> get userOrders => List.unmodifiable(_userOrders);
  bool get isLoading => _isLoading;

  final List<RewardItem> availableRewards = [
    RewardItem(
      id: 'rw_1',
      title: 'Pawtbook Custom Leather Collar',
      description: 'Handcrafted premium leather collar with custom Solana NFT badge engraving.',
      pointsCost: 150,
      imageUrl: 'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?w=400',
    ),
    RewardItem(
      id: 'rw_2',
      title: 'Organic Gourmet Pet Treats Box',
      description: '100% natural, grain-free organic treats pack for healthy energy.',
      pointsCost: 80,
      imageUrl: 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?w=400',
    ),
    RewardItem(
      id: 'rw_3',
      title: 'Interactive Smart Laser Toy',
      description: 'Automatic motion-activated laser toy to keep pets active and entertained.',
      pointsCost: 200,
      imageUrl: 'https://images.unsplash.com/photo-1545249390-6bdfa286032f?w=400',
    ),
  ];

  PetController({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService();

  Future<void> fetchUserOrders(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _userOrders = await _supabaseService.getOrdersForUser(userId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> redeemReward({
    required String userId,
    required RewardItem reward,
    required int currentPawtScore,
  }) async {
    if (currentPawtScore < reward.pointsCost) {
      return false;
    }

    final newOrder = RewardOrderModel(
      id: 'ord_${const Uuid().v4().substring(0, 8)}',
      userId: userId,
      rewardName: reward.title,
      pointsCost: reward.pointsCost,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await _supabaseService.createOrder(newOrder);
    _userOrders.insert(0, newOrder);
    notifyListeners();
    return true;
  }
}
