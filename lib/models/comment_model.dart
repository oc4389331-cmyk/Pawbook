class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String? username;
  final String? parentId; // ID of the parent comment if this is a reply
  final String? replyToUsername; // Username being replied to

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.username,
    this.parentId,
    this.replyToUsername,
  });

  bool get isReply => parentId != null && parentId!.isNotEmpty;

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] ?? '',
      postId: json['post_id'] ?? '',
      userId: json['user_id'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      username: json['username'] ?? json['profiles']?['username'],
      parentId: json['parent_id'],
      replyToUsername: json['reply_to_username'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      if (parentId != null) 'parent_id': parentId,
      if (replyToUsername != null) 'reply_to_username': replyToUsername,
    };
  }

  CommentModel copyWith({
    String? id,
    String? postId,
    String? userId,
    String? content,
    DateTime? createdAt,
    String? username,
    String? parentId,
    String? replyToUsername,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      username: username ?? this.username,
      parentId: parentId ?? this.parentId,
      replyToUsername: replyToUsername ?? this.replyToUsername,
    );
  }
}
