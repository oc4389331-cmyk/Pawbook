import 'package:flutter_test/flutter_test.dart';
import 'package:pawtbook/controllers/feed_controller.dart';
import 'package:pawtbook/models/pet_model.dart';
import 'package:pawtbook/models/post_model.dart';

void main() {
  group('Safety & Moderation Pipeline Unit Tests', () {
    late FeedController feedController;
    late PetModel samplePet;

    setUp(() {
      feedController = FeedController();
      samplePet = PetModel(
        id: 'pet_demo_1',
        ownerId: 'usr_demo_123',
        name: 'Luna',
        createdAt: DateTime.now(),
      );
    });

    test('Media moderation approves safe content (pending_review -> active)', () async {
      final post = await feedController.createPetPost(
        pet: samplePet,
        mediaBytes: [1, 2, 3],
        filename: 'safe_dog.jpg',
        mediaType: 'image',
        caption: 'Happy dog at the park!',
        forceModerationDecision: 'approve',
      );

      expect(post, isNotNull);
      expect(post!.status, equals(PostStatus.active));
      expect(feedController.posts.any((p) => p.id == post.id), isTrue);
    });

    test('Media moderation rejects policy violating content (pending_review -> rejected)', () async {
      expect(
        () async => await feedController.createPetPost(
          pet: samplePet,
          mediaBytes: [1, 2, 3],
          filename: 'unsafe.jpg',
          mediaType: 'image',
          caption: 'Inappropriate content',
          forceModerationDecision: 'reject',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Community reporting 3 times auto-hides post from active feed', () async {
      await feedController.fetchActivePosts();
      expect(feedController.posts.isNotEmpty, isTrue);

      final targetPostId = feedController.posts.first.id;
      await feedController.reportPost(targetPostId);
      await feedController.reportPost(targetPostId);
      await feedController.reportPost(targetPostId);

      expect(feedController.posts.any((p) => p.id == targetPostId), isFalse);
    });
  });
}
