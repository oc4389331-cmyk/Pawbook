class ProfileModel {
  final String id;
  final String walletAddress;
  final String username;
  final String? email;
  final String? fullName;
  final String? avatarUrl;
  final String? bio;
  final int pawtScore;
  final DateTime createdAt;

  ProfileModel({
    required this.id,
    required this.walletAddress,
    required this.username,
    this.email,
    this.fullName,
    this.avatarUrl,
    this.bio,
    this.pawtScore = 0,
    required this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] ?? '',
      walletAddress: json['wallet_address'] ?? '',
      username: json['username'] ?? '',
      email: json['email'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
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
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'pawt_score': pawtScore,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? id,
    String? walletAddress,
    String? username,
    String? email,
    String? fullName,
    String? avatarUrl,
    String? bio,
    int? pawtScore,
    DateTime? createdAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      walletAddress: walletAddress ?? this.walletAddress,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      pawtScore: pawtScore ?? this.pawtScore,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
