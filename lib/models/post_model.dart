enum PostStatus { pendingReview, active, rejected }

class PostModel {
  final String id;
  final String petId;
  final String mediaUrl;
  final String mediaType;
  final String caption;
  final int likesCount;
  final int viewsCount;
  final int commentsCount;
  final List<String> tags;
  final PostStatus status;
  final int reportCount;
  final DateTime createdAt;

  // Joined metadata & local state for UI convenience
  final String? petName;
  final String? petAvatarUrl;
  final String? nftMintAddress;
  final bool isLikedByCurrentUser;

  PostModel({
    required this.id,
    required this.petId,
    required this.mediaUrl,
    this.mediaType = 'video',
    this.caption = '',
    this.likesCount = 0,
    this.viewsCount = 0,
    this.commentsCount = 0,
    this.tags = const [],
    this.status = PostStatus.active,
    this.reportCount = 0,
    required this.createdAt,
    this.petName,
    this.petAvatarUrl,
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

    return PostModel(
      id: json['id'] ?? '',
      petId: json['pet_id'] ?? '',
      mediaUrl: json['media_url'] ?? '',
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
      petName: json['pet_name'] ?? json['pets']?['name'],
      petAvatarUrl: json['pet_avatar_url'] ?? json['pets']?['avatar_url'],
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
      'media_type': mediaType,
      'caption': caption,
      'likes_count': likesCount,
      'views_count': viewsCount,
      'tags': tags,
      'status': statusStr,
      'report_count': reportCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PostModel copyWith({
    String? id,
    String? petId,
    String? mediaUrl,
    String? mediaType,
    String? caption,
    int? likesCount,
    int? viewsCount,
    int? commentsCount,
    List<String>? tags,
    PostStatus? status,
    int? reportCount,
    DateTime? createdAt,
    String? petName,
    String? petAvatarUrl,
    String? nftMintAddress,
    bool? isLikedByCurrentUser,
  }) {
    return PostModel(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      caption: caption ?? this.caption,
      likesCount: likesCount ?? this.likesCount,
      viewsCount: viewsCount ?? this.viewsCount,
      commentsCount: commentsCount ?? this.commentsCount,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      reportCount: reportCount ?? this.reportCount,
      createdAt: createdAt ?? this.createdAt,
      petName: petName ?? this.petName,
      petAvatarUrl: petAvatarUrl ?? this.petAvatarUrl,
      nftMintAddress: nftMintAddress ?? this.nftMintAddress,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
    );
  }
}
