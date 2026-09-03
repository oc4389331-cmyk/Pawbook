import 'package:flutter_test/flutter_test.dart';
import 'package:pawtbook/models/post_model.dart';
import 'package:pawtbook/services/supabase_service.dart';

void main() {
  group('Supabase RLS & Role Restriction Unit Tests', () {
    late SupabaseService supabaseService;

    setUp(() {
      supabaseService = SupabaseService(useMockFallback: true);
    });

    test('Human profile without registered pet_id cannot create posts (RLS Enforcement)', () async {
      final invalidPost = PostModel(
        id: 'post_invalid_1',
        petId: '', // Empty/Invalid pet_id
        mediaUrl: 'https://media.pawbooklife.com/posts/test.jpg',
        caption: 'Unauthorized human post attempt',
        status: PostStatus.pendingReview,
        createdAt: DateTime.now(),
      );

      expect(
        () async => await supabaseService.createPost(invalidPost),
        throwsA(isA<Exception>()),
      );
    });

    test('Pet profile with valid pet_id can create posts successfully', () async {
      final validPost = PostModel(
        id: 'post_valid_1',
        petId: 'pet_demo_1',
        mediaUrl: 'https://media.pawbooklife.com/posts/valid_pet.jpg',
        caption: 'Valid pet post!',
        status: PostStatus.active,
        createdAt: DateTime.now(),
      );

      final result = await supabaseService.createPost(validPost);
      expect(result.petId, equals('pet_demo_1'));
      expect(result.mediaUrl, contains('media.pawbooklife.com'));
    });
  });
}
