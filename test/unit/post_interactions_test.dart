import 'package:flutter_test/flutter_test.dart';
import 'package:pawtbook/controllers/feed_controller.dart';
import 'package:pawtbook/models/comment_model.dart';
import 'package:pawtbook/models/post_model.dart';
import 'package:pawtbook/services/profanity_filter_service.dart';
import 'package:pawtbook/services/supabase_service.dart';

void main() {
  group('Post Interactions & Profanity Filter Tests', () {
    late SupabaseService supabaseService;
    late FeedController feedController;

    setUp(() {
      supabaseService = SupabaseService(useMockFallback: true);
      feedController = FeedController();
    });

    test('Post Like: toggleLikePost triggers immediate 0ms UI update with notifyListeners', () async {
      // Fetch initial active posts
      await feedController.fetchActivePosts();
      expect(feedController.posts.isNotEmpty, isTrue);

      final initialPost = feedController.posts.first;
      final initialLikes = initialPost.likesCount;
      final wasLiked = initialPost.isLikedByCurrentUser;

      int notifyCount = 0;
      feedController.addListener(() {
        notifyCount++;
      });

      // 1. Tapping Like
      await feedController.toggleLikePost('test_user_1', initialPost.id);

      final updatedPost = feedController.posts.firstWhere((p) => p.id == initialPost.id);
      expect(updatedPost.isLikedByCurrentUser, equals(!wasLiked));
      expect(updatedPost.likesCount, equals(wasLiked ? initialLikes - 1 : initialLikes + 1));
      expect(notifyCount, greaterThanOrEqualTo(1));

      // 2. Tapping Like again (unliking)
      await feedController.toggleLikePost('test_user_1', initialPost.id);

      final revertedPost = feedController.posts.firstWhere((p) => p.id == initialPost.id);
      expect(revertedPost.isLikedByCurrentUser, equals(wasLiked));
      expect(revertedPost.likesCount, equals(initialLikes));
    });

    test('Comment Count: addCommentToPost increments commentsCount on post immediately', () async {
      await feedController.fetchActivePosts();
      final post = feedController.posts.first;
      final initialCommentsCount = post.commentsCount;

      int notifyCount = 0;
      feedController.addListener(() {
        notifyCount++;
      });

      // Add comment via FeedController
      final newComment = await feedController.addCommentToPost(
        userId: 'test_user_1',
        postId: post.id,
        content: '¡Qué hermosa mascota! 🐾',
        username: 'PetFan99',
      );

      final updatedPost = feedController.posts.firstWhere((p) => p.id == post.id);
      expect(updatedPost.commentsCount, equals(initialCommentsCount + 1));
      expect(newComment.content, equals('¡Qué hermosa mascota! 🐾'));
      expect(newComment.username, equals('PetFan99'));
      expect(notifyCount, greaterThanOrEqualTo(1));

      // Add second comment
      await feedController.addCommentToPost(
        userId: 'test_user_2',
        postId: post.id,
        content: 'Totalmente de acuerdo',
      );

      final secondUpdatedPost = feedController.posts.firstWhere((p) => p.id == post.id);
      expect(secondUpdatedPost.commentsCount, equals(initialCommentsCount + 2));
    });

    test('Profanity Filter: correctly detects profanities across dialects, accents and obfuscations', () {
      // Spanish profanity without accents
      expect(ProfanityFilterService.hasProfanity('eres un puto'), isTrue);
      expect(ProfanityFilterService.hasProfanity('que mierda de video'), isTrue);
      expect(ProfanityFilterService.hasProfanity('eres un pendejo'), isTrue);
      expect(ProfanityFilterService.hasProfanity('vete a la verga'), isTrue);

      // Spanish profanity with accents
      expect(ProfanityFilterService.hasProfanity('eres muy estúpido'), isTrue);
      expect(ProfanityFilterService.hasProfanity('menudo imbécil'), isTrue);
      expect(ProfanityFilterService.hasProfanity('eres un cabrón'), isTrue);

      // Spacing obfuscations & leetspeak
      expect(ProfanityFilterService.hasProfanity('p u t a'), isTrue);
      expect(ProfanityFilterService.hasProfanity('p.u.t.a'), isTrue);
      expect(ProfanityFilterService.hasProfanity('puuuuta'), isTrue);
      expect(ProfanityFilterService.hasProfanity('fuck this'), isTrue);
      expect(ProfanityFilterService.hasProfanity('what a b1tch'), isTrue);

      // Innocent pet comments must NOT trigger false positives
      expect(ProfanityFilterService.hasProfanity('¡Qué hermoso perrito!'), isFalse);
      expect(ProfanityFilterService.hasProfanity('Me encanta su collar y su pelaje 🐶'), isFalse);
      expect(ProfanityFilterService.hasProfanity('Hola amigo, lindo gatito'), isFalse);
      expect(ProfanityFilterService.hasProfanity('Disfrutando el parque con mi mascota'), isFalse);
    });

    test('Profanity Filter: sanitize replaces banned words with asterisks', () {
      final sanitized = ProfanityFilterService.sanitize('que mierda de dia');
      expect(sanitized.contains('mierda'), isFalse);
      expect(sanitized.contains('******'), isTrue);
    });

    test('Comment Model & SupabaseService: comment likes count and user toggle', () async {
      final comment = CommentModel(
        id: 'cmt_like_test_1',
        postId: 'post_demo_multi',
        userId: 'usr_author',
        content: 'Primer comentario',
        createdAt: DateTime.now(),
        likesCount: 0,
        isLikedByCurrentUser: false,
      );

      final json = comment.toJson();
      expect(json['likes_count'], equals(0));

      final restored = CommentModel.fromJson({
        ...json,
        'likes_count': 5,
        'is_liked_by_current_user': true,
      });
      expect(restored.likesCount, equals(5));
      expect(restored.isLikedByCurrentUser, isTrue);

      // Toggle like in SupabaseService
      final isLiked1 = await supabaseService.toggleLikeComment('usr_liker', 'cmt_like_test_1');
      expect(isLiked1, isTrue);

      // Fetch comments decorated with like state
      final comments = await supabaseService.getCommentsForPost('post_demo_multi', currentUserId: 'usr_liker');
      // When liked, toggle again
      final isLiked2 = await supabaseService.toggleLikeComment('usr_liker', 'cmt_like_test_1');
      expect(isLiked2, isFalse);
    });
  });
}
