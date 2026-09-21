enum PostStatus { pendingReview, active, rejected }

class PostModel {
  final String id;
  final String petId;
  final String mediaUrl;
  final List<String> mediaUrls; // Multi-image support (up to 5)
  final String mediaType;
  final String caption;
  final int likesCount;
  final int viewsCount;
  final int commentsCount;
  final List<String> tags;
  final PostStatus status;
  final int reportCount;
  final DateTime createdAt;
  final String? soundUrl;   // Royalty-free audio URL
  final String? soundTitle; // Song display name

  // Joined metadata & local state for UI convenience
  final String? petName;
  final String? petAvatarUrl;
  final String? petSpecies;
  final String? petOwnerId;
  final String? nftMintAddress;
  final bool isLikedByCurrentUser;

  /// All display URLs: combines mediaUrls (if set) with fallback to mediaUrl
  List<String> get allMediaUrls {
    if (mediaUrls.isNotEmpty) return mediaUrls;
    if (mediaUrl.isNotEmpty) return [mediaUrl];
    return [];
  }

  bool get hasMultipleImages => allMediaUrls.length > 1;
  bool get hasSound => soundUrl != null && soundUrl!.isNotEmpty;

  PostModel({
    required this.id,
    required this.petId,
    required this.mediaUrl,
    this.mediaUrls = const [],
    this.mediaType = 'video',
    this.caption = '',
    this.likesCount = 0,
    this.viewsCount = 0,
    this.commentsCount = 0,
    this.tags = const [],
    this.status = PostStatus.active,
    this.reportCount = 0,
    required this.createdAt,
    this.soundUrl,
    this.soundTitle,
    this.petName,
    this.petAvatarUrl,
    this.petSpecies,
    this.petOwnerId,
    this.nftMintAddress,
    this.isLikedByCurrentUser = false,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    PostStatus statusEnum = PostStatus.active;
    final statusStr = json['status'] as String?;
    if (statusStr == 'pending_review') {
      statusEnum = PostStatus.pendingReview;
    } else if (statusStr == 'rejected') {
      statusEnum = PostStatus.rejected;
    }

    final rawTags = json['tags'];
    List<String> parsedTags = [];
    if (rawTags is List) {
      parsedTags = rawTags.map((e) => e.toString()).toList();
    }

    final rawMediaUrls = json['media_urls'];
    List<String> parsedMediaUrls = [];
    if (rawMediaUrls is List) {
      parsedMediaUrls = rawMediaUrls.map((e) => e.toString()).toList();
    }

    return PostModel(
      id: json['id'] ?? '',
      petId: json['pet_id'] ?? '',
      mediaUrl: json['media_url'] ?? '',
      mediaUrls: parsedMediaUrls,
      mediaType: json['media_type'] ?? 'video',
      caption: json['caption'] ?? '',
      likesCount: (json['likes_count'] ?? 0) as int,
      viewsCount: (json['views_count'] ?? 0) as int,
      commentsCount: (json['comments_count'] ?? 0) as int,
      tags: parsedTags,
      status: statusEnum,
      reportCount: (json['report_count'] ?? 0) as int,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      soundUrl: json['sound_url'],
      soundTitle: json['sound_title'],
      petName: json['pet_name'] ?? json['pets']?['name'],
      petAvatarUrl: json['pet_avatar_url'] ?? json['pets']?['avatar_url'],
      petSpecies: json['pet_species'] ?? json['pets']?['species'] ?? 'Dog',
      petOwnerId: json['pet_owner_id'] ?? json['pets']?['owner_id'],
      nftMintAddress: json['nft_mint_address'] ?? json['pets']?['nft_mint_address'],
      isLikedByCurrentUser: json['is_liked_by_user'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    String statusStr = 'active';
    if (status == PostStatus.pendingReview) statusStr = 'pending_review';
    if (status == PostStatus.rejected) statusStr = 'rejected';

    return {
      'id': id,
      'pet_id': petId,
      'media_url': mediaUrl,
      'media_urls': mediaUrls,
      'media_type': mediaType,
      'caption': caption,
      'likes_count': likesCount,
      'views_count': viewsCount,
      'tags': tags,
      'status': statusStr,
      'report_count': reportCount,
      'sound_url': soundUrl,
      'sound_title': soundTitle,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PostModel copyWith({
    String? id,
    String? petId,
    String? mediaUrl,
    List<String>? mediaUrls,
    String? mediaType,
    String? caption,
    int? likesCount,
    int? viewsCount,
    int? commentsCount,
    List<String>? tags,
    PostStatus? status,
    int? reportCount,
    DateTime? createdAt,
    String? soundUrl,
    String? soundTitle,
    String? petName,
    String? petAvatarUrl,
    String? petSpecies,
    String? petOwnerId,
    String? nftMintAddress,
    bool? isLikedByCurrentUser,
  }) {
    return PostModel(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaType: mediaType ?? this.mediaType,
      caption: caption ?? this.caption,
      likesCount: likesCount ?? this.likesCount,
      viewsCount: viewsCount ?? this.viewsCount,
      commentsCount: commentsCount ?? this.commentsCount,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      reportCount: reportCount ?? this.reportCount,
      createdAt: createdAt ?? this.createdAt,
      soundUrl: soundUrl ?? this.soundUrl,
      soundTitle: soundTitle ?? this.soundTitle,
      petName: petName ?? this.petName,
      petAvatarUrl: petAvatarUrl ?? this.petAvatarUrl,
      petSpecies: petSpecies ?? this.petSpecies,
      petOwnerId: petOwnerId ?? this.petOwnerId,
      nftMintAddress: nftMintAddress ?? this.nftMintAddress,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
    );
  }
}
