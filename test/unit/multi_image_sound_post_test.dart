import 'package:flutter_test/flutter_test.dart';
import 'package:pawtbook/models/post_model.dart';

void main() {
  group('Multi-Image Posts & Sound Selection Unit Tests', () {
    test('PostModel correctly handles multiple media URLs and sound metadata', () {
      final post = PostModel(
        id: 'post_multi_1',
        petId: 'pet_luna',
        mediaUrl: 'https://media.pawbooklife.com/img1.jpg',
        mediaUrls: [
          'https://media.pawbooklife.com/img1.jpg',
          'https://media.pawbooklife.com/img2.jpg',
          'https://media.pawbooklife.com/img3.jpg',
        ],
        mediaType: 'image',
        caption: 'Luna at the beach! 🐾',
        soundUrl: 'https://cdn.pixabay.com/audio/sample.mp3',
        soundTitle: 'Upbeat Corporate Ukulele',
        createdAt: DateTime(2026, 9, 13),
      );

      expect(post.hasMultipleImages, isTrue);
      expect(post.allMediaUrls.length, equals(3));
      expect(post.hasSound, isTrue);
      expect(post.soundTitle, equals('Upbeat Corporate Ukulele'));
    });

    test('PostModel allMediaUrls falls back to single mediaUrl when mediaUrls is empty', () {
      final singlePost = PostModel(
        id: 'post_single_1',
        petId: 'pet_milo',
        mediaUrl: 'https://media.pawbooklife.com/single.jpg',
        mediaUrls: const [],
        mediaType: 'image',
        createdAt: DateTime(2026, 9, 13),
      );

      expect(singlePost.hasMultipleImages, isFalse);
      expect(singlePost.allMediaUrls, equals(['https://media.pawbooklife.com/single.jpg']));
      expect(singlePost.hasSound, isFalse);
    });

    test('PostModel fromJson and toJson persist media_urls, sound_url and sound_title', () {
      final json = {
        'id': 'post_json_test',
        'pet_id': 'pet_123',
        'media_url': 'https://media.pawbooklife.com/1.jpg',
        'media_urls': [
          'https://media.pawbooklife.com/1.jpg',
          'https://media.pawbooklife.com/2.jpg',
          'https://media.pawbooklife.com/3.jpg',
          'https://media.pawbooklife.com/4.jpg',
          'https://media.pawbooklife.com/5.jpg',
        ],
        'media_type': 'image',
        'caption': '5 photos post',
        'likes_count': 10,
        'views_count': 100,
        'comments_count': 5,
        'tags': ['fun', 'pets'],
        'status': 'active',
        'sound_url': 'https://cdn.pixabay.com/sound.mp3',
        'sound_title': 'Happy Whistling',
        'created_at': '2026-09-13T12:00:00.000Z',
      };

      final post = PostModel.fromJson(json);
      expect(post.mediaUrls.length, equals(5));
      expect(post.hasMultipleImages, isTrue);
      expect(post.soundUrl, equals('https://cdn.pixabay.com/sound.mp3'));
      expect(post.soundTitle, equals('Happy Whistling'));

      final outJson = post.toJson();
      expect(outJson['media_urls'], equals(json['media_urls']));
      expect(outJson['sound_url'], equals('https://cdn.pixabay.com/sound.mp3'));
      expect(outJson['sound_title'], equals('Happy Whistling'));
    });

    test('PostModel copyWith updates sound and multi-image fields correctly', () {
      final initial = PostModel(
        id: 'post_copy',
        petId: 'pet_copy',
        mediaUrl: 'https://media.pawbooklife.com/original.jpg',
        createdAt: DateTime(2026, 9, 13),
      );

      final updated = initial.copyWith(
        mediaUrls: ['https://media.pawbooklife.com/a.jpg', 'https://media.pawbooklife.com/b.jpg'],
        soundUrl: 'https://cdn.pixabay.com/audio/guitar.mp3',
        soundTitle: 'Chill Acoustic Guitar',
      );

      expect(updated.hasMultipleImages, isTrue);
      expect(updated.allMediaUrls.length, equals(2));
      expect(updated.soundUrl, equals('https://cdn.pixabay.com/audio/guitar.mp3'));
      expect(updated.soundTitle, equals('Chill Acoustic Guitar'));
    });

    test('PostModel correctly stores sound URL and sound title', () {
      final postWithSound = PostModel(
        id: 'post_sound_test',
        petId: 'pet_luna',
        mediaUrl: 'https://media.pawbooklife.com/img.jpg',
        mediaUrls: ['https://media.pawbooklife.com/img.jpg'],
        soundUrl: 'https://cdn.pixabay.com/download/audio/2022/01/18/audio_d0c6ff1fbc.mp3',
        soundTitle: 'Upbeat Corporate Ukulele',
        createdAt: DateTime(2026, 9, 13),
      );

      expect(postWithSound.hasSound, isTrue);
      expect(postWithSound.soundUrl, contains('pixabay.com'));
      expect(postWithSound.soundTitle, equals('Upbeat Corporate Ukulele'));
    });
  });
}
