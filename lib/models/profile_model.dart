class ProfileModel {
  final String id;
  final String walletAddress;
  final String username;
  final int pawtScore;
  final DateTime createdAt;

  ProfileModel({
    required this.id,
    required this.walletAddress,
    required this.username,
    this.pawtScore = 0,
    required this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] ?? '',
      walletAddress: json['wallet_address'] ?? '',
      username: json['username'] ?? '',
      pawtScore: (json['pawt_score'] ?? 0) as int,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wallet_address': walletAddress,
      'username': username,
      'pawt_score': pawtScore,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? id,
    String? walletAddress,
    String? username,
    int? pawtScore,
    DateTime? createdAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      walletAddress: walletAddress ?? this.walletAddress,
      username: username ?? this.username,
      pawtScore: pawtScore ?? this.pawtScore,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
