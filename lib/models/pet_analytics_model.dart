class DailyMetricPoint {
  final String label; // e.g. 'Lun', 'Mar', '10 Sep'
  final DateTime date;
  final int views;
  final int likes;
  final int comments;
  final double watchMinutes;

  DailyMetricPoint({
    required this.label,
    required this.date,
    required this.views,
    required this.likes,
    required this.comments,
    required this.watchMinutes,
  });
}

class VideoAnalyticsItem {
  final String postId;
  final String caption;
  final String mediaUrl;
  final String mediaType;
  final DateTime createdAt;
  final int viewsCount;
  final int likesCount;
  final int commentsCount;
  final int totalWatchSeconds;
  final double avgWatchSeconds;
  final double retentionRatePercentage;
  final List<DailyMetricPoint> history;

  VideoAnalyticsItem({
    required this.postId,
    required this.caption,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    required this.viewsCount,
    required this.likesCount,
    required this.commentsCount,
    required this.totalWatchSeconds,
    required this.avgWatchSeconds,
    required this.retentionRatePercentage,
    required this.history,
  });

  String get formattedTotalWatchTime {
    if (totalWatchSeconds < 60) return '${totalWatchSeconds}s';
    if (totalWatchSeconds < 3600) return '${(totalWatchSeconds / 60).toStringAsFixed(1)} min';
    return '${(totalWatchSeconds / 3600).toStringAsFixed(1)} hrs';
  }

  String get formattedAvgWatchTime {
    if (avgWatchSeconds < 60) return '${avgWatchSeconds.toStringAsFixed(1)}s';
    return '${(avgWatchSeconds / 60).toStringAsFixed(1)} min';
  }
}

class PetAnalyticsModel {
  final String petId;
  final String petName;
  final int totalPosts;
  final int totalViews;
  final int totalLikes;
  final int totalComments;
  final int totalWatchSeconds;
  final double avgWatchSeconds;
  final double retentionRatePercentage; // % of viewers reaching >= 15 seconds
  final List<DailyMetricPoint> globalHistory;
  final List<VideoAnalyticsItem> videoBreakdown;

  PetAnalyticsModel({
    required this.petId,
    required this.petName,
    required this.totalPosts,
    required this.totalViews,
    required this.totalLikes,
    required this.totalComments,
    required this.totalWatchSeconds,
    required this.avgWatchSeconds,
    required this.retentionRatePercentage,
    required this.globalHistory,
    required this.videoBreakdown,
  });

  String get formattedTotalWatchTime {
    if (totalWatchSeconds < 60) return '${totalWatchSeconds}s';
    if (totalWatchSeconds < 3600) return '${(totalWatchSeconds / 60).toStringAsFixed(1)} min';
    return '${(totalWatchSeconds / 3600).toStringAsFixed(1)} hrs';
  }

  String get formattedAvgWatchTime {
    if (avgWatchSeconds < 60) return '${avgWatchSeconds.toStringAsFixed(1)}s';
    return '${(avgWatchSeconds / 60).toStringAsFixed(1)} min';
  }
}
