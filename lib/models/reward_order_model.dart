class RewardOrderModel {
  final String id;
  final String userId;
  final String rewardName;
  final int pointsCost;
  final String status;
  final DateTime createdAt;

  RewardOrderModel({
    required this.id,
    required this.userId,
    required this.rewardName,
    required this.pointsCost,
    this.status = 'pending',
    required this.createdAt,
  });

  factory RewardOrderModel.fromJson(Map<String, dynamic> json) {
    return RewardOrderModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      rewardName: json['reward_name'] ?? '',
      pointsCost: (json['points_cost'] ?? 0) as int,
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'reward_name': rewardName,
      'points_cost': pointsCost,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
