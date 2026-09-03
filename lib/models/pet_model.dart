class PetModel {
  final String id;
  final String ownerId;
  final String name;
  final String species;
  final String breed;
  final String bio;
  final String avatarUrl;
  final String? nftMintAddress;
  final int totalSponsoredScore;
  final DateTime createdAt;

  PetModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.species = 'Dog',
    this.breed = 'Mixed',
    this.bio = '',
    this.avatarUrl = '',
    this.nftMintAddress,
    this.totalSponsoredScore = 0,
    required this.createdAt,
  });

  factory PetModel.fromJson(Map<String, dynamic> json) {
    return PetModel(
      id: json['id'] ?? '',
      ownerId: json['owner_id'] ?? '',
      name: json['name'] ?? '',
      species: json['species'] ?? 'Dog',
      breed: json['breed'] ?? 'Mixed',
      bio: json['bio'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      nftMintAddress: json['nft_mint_address'],
      totalSponsoredScore: (json['total_sponsored_score'] ?? 0) as int,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'species': species,
      'breed': breed,
      'bio': bio,
      'avatar_url': avatarUrl,
      'nft_mint_address': nftMintAddress,
      'total_sponsored_score': totalSponsoredScore,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PetModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? species,
    String? breed,
    String? bio,
    String? avatarUrl,
    String? nftMintAddress,
    int? totalSponsoredScore,
    DateTime? createdAt,
  }) {
    return PetModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      nftMintAddress: nftMintAddress ?? this.nftMintAddress,
      totalSponsoredScore: totalSponsoredScore ?? this.totalSponsoredScore,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
