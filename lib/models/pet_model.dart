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

  /// Official badge validity duration in days (deactivates if not renewed)
  static const int verificationValidityDays = 40;

  /// Base check whether this pet has ever had a verification certificate
  bool get isVerifiedBase {
    if (nftMintAddress == null || nftMintAddress!.isEmpty) return false;
    return nftMintAddress!.startsWith('SolVerified_') ||
        nftMintAddress!.startsWith('Verified_') ||
        (nftMintAddress!.length >= 32 &&
            !nftMintAddress!.startsWith('SolMint') &&
            !nftMintAddress!.startsWith('PawSol'));
  }

  /// Extracted verification timestamp if verified with timestamp
  DateTime? get verifiedAt {
    if (nftMintAddress == null || nftMintAddress!.isEmpty) return null;
    try {
      if (nftMintAddress!.startsWith('SolVerified_') || nftMintAddress!.startsWith('Verified_')) {
        final parts = nftMintAddress!.split('_');
        if (parts.length >= 2) {
          final timestamp = int.tryParse(parts[1]);
          if (timestamp != null && timestamp > 0) {
            return DateTime.fromMillisecondsSinceEpoch(timestamp);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Expiration date of the verification badge (verifiedAt + 40 days)
  DateTime? get verificationExpiresAt {
    final vAt = verifiedAt;
    if (vAt != null) {
      return vAt.add(const Duration(days: verificationValidityDays));
    }
    if (isVerifiedBase) {
      return createdAt.add(const Duration(days: verificationValidityDays));
    }
    return null;
  }

  /// Days remaining until the verification badge deactivates
  int get verificationDaysRemaining {
    final expires = verificationExpiresAt;
    if (expires == null) return 0;
    final diff = expires.difference(DateTime.now()).inDays;
    return diff >= 0 ? diff : 0;
  }

  /// Whether the verification badge has exceeded the 40-day validity window
  bool get isVerificationExpired {
    if (!isVerifiedBase) return false;
    final expires = verificationExpiresAt;
    if (expires != null) {
      return DateTime.now().isAfter(expires);
    }
    return false;
  }

  /// Whether this pet holds an ACTIVE official verified blue star badge
  /// (Deactivates automatically after 40 days if not renewed)
  bool get isVerified {
    if (!isVerifiedBase) return false;
    return !isVerificationExpired;
  }

  /// Static helper to check whether an nftMintAddress is verified and not expired
  static bool checkVerificationAddress(String? address, [DateTime? fallbackDate]) {
    if (address == null || address.isEmpty) return false;
    final isBase = address.startsWith('SolVerified_') ||
        address.startsWith('Verified_') ||
        (address.length >= 32 &&
            !address.startsWith('SolMint') &&
            !address.startsWith('PawSol'));
    if (!isBase) return false;

    // Check 40-day expiration
    try {
      if (address.startsWith('SolVerified_') || address.startsWith('Verified_')) {
        final parts = address.split('_');
        if (parts.length >= 2) {
          final timestamp = int.tryParse(parts[1]);
          if (timestamp != null && timestamp > 0) {
            final verifiedDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
            final expires = verifiedDate.add(const Duration(days: verificationValidityDays));
            return DateTime.now().isBefore(expires);
          }
        }
      }
    } catch (_) {}

    if (fallbackDate != null) {
      final expires = fallbackDate.add(const Duration(days: verificationValidityDays));
      return DateTime.now().isBefore(expires);
    }

    return true;
  }

  /// Deterministic or on-chain Dynamic Solana Wallet Address for this pet
  String get dynamicWalletAddress {
    if (nftMintAddress != null &&
        nftMintAddress!.isNotEmpty &&
        !nftMintAddress!.startsWith('SolMint') &&
        !nftMintAddress!.startsWith('PawSol')) {
      return nftMintAddress!;
    }
    const base58Chars = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    final hash = ('pet_${name.toLowerCase()}_${id.replaceAll("-", "")}').hashCode.abs();
    final sb = StringBuffer();
    int cur = hash;
    for (int i = 0; i < 44; i++) {
      cur = (cur * 1664525 + 1013904223) & 0x7FFFFFFF;
      sb.write(base58Chars[cur % base58Chars.length]);
    }
    return sb.toString();
  }

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
