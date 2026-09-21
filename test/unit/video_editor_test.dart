import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawtbook/config/app_config.dart';
import 'package:pawtbook/views/screens/video_editor_screen.dart';

void main() {
  group('Pawtbook Video Studio & Editor Unit Tests', () {
    test('VideoFilterPresets contains standard TikTok filters', () {
      expect(videoFilterPresets.length, greaterThanOrEqualTo(6));
      expect(videoFilterPresets.any((f) => f.name == 'Normal'), isTrue);
      expect(videoFilterPresets.any((f) => f.name == 'Warm Golden'), isTrue);
      expect(videoFilterPresets.any((f) => f.name == 'Cyber Solana'), isTrue);
      expect(videoFilterPresets.any((f) => f.name == 'Monochrome'), isTrue);
      expect(videoFilterPresets.any((f) => f.name == 'Vibrant Pop'), isTrue);

      for (final filter in videoFilterPresets) {
        if (filter.matrix != null) {
          expect(filter.matrix!.length, equals(20)); // Standard 4x5 ColorFilter matrix
        }
      }
    });

    test('VideoOverlayItem manages positioning, scale and colors', () {
      final overlay = VideoOverlayItem(
        id: 'overlay_test_1',
        type: OverlayType.sticker,
        content: '🐾',
        offset: const Offset(100, 150),
        scale: 1.5,
        rotation: 0.25,
      );

      expect(overlay.id, equals('overlay_test_1'));
      expect(overlay.type, equals(OverlayType.sticker));
      expect(overlay.content, equals('🐾'));
      expect(overlay.offset.dx, equals(100));
      expect(overlay.offset.dy, equals(150));
      expect(overlay.scale, equals(1.5));
    });

    test('VideoEditorResult properly computes duration and handles trimmed metadata', () {
      final result = VideoEditorResult(
        videoBytes: Uint8List.fromList([1, 2, 3, 4]),
        filename: 'my_dog_clip.mp4',
        startSeconds: 2.5,
        endSeconds: 17.5,
        filterName: 'Cyber Solana',
        overlays: [
          VideoOverlayItem(
            id: 'ov_1',
            type: OverlayType.emoji,
            content: '👑',
            offset: const Offset(50, 50),
          ),
          VideoOverlayItem(
            id: 'ov_2',
            type: OverlayType.text,
            content: 'Luna First Walk! 🐕',
            offset: const Offset(100, 200),
            textColor: Colors.yellowAccent,
          ),
        ],
        originalVolume: 0.9,
        musicVolume: 0.7,
      );

      expect(result.filename, equals('my_dog_clip.mp4'));
      expect(result.duration, equals(15.0));
      expect(result.filterName, equals('Cyber Solana'));
      expect(result.overlays.length, equals(2));
      expect(result.originalVolume, equals(0.9));
      expect(result.musicVolume, equals(0.7));
    });

    test('Video duration constraint enforces AppConfig.maxVideoDurationSeconds (30s)', () {
      expect(AppConfig.maxVideoDurationSeconds, equals(30.0));

      // Test a video trimmed to exactly 30s
      final validResult = VideoEditorResult(
        videoBytes: Uint8List.fromList([1, 2, 3]),
        filename: 'valid_clip.mp4',
        startSeconds: 0.0,
        endSeconds: 30.0,
        filterName: 'Normal',
        overlays: const [],
      );
      expect(validResult.duration, equals(30.0));
      expect(validResult.duration <= AppConfig.maxVideoDurationSeconds, isTrue);

      // Test detection of excessive video duration (> 30s)
      final longResult = VideoEditorResult(
        videoBytes: Uint8List.fromList([1, 2, 3]),
        filename: 'long_clip.mp4',
        startSeconds: 0.0,
        endSeconds: 45.0,
        filterName: 'Normal',
        overlays: const [],
      );
      expect(longResult.duration, equals(45.0));
      expect(longResult.duration > AppConfig.maxVideoDurationSeconds, isTrue);
    });

    test('VideoEditorResult supports integrated overlay PNG rasterization', () {
      final mockPngBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]); // PNG magic bytes
      final result = VideoEditorResult(
        videoBytes: Uint8List.fromList([1, 2, 3]),
        filename: 'doggy.mp4',
        startSeconds: 0.0,
        endSeconds: 15.0,
        filterName: 'Warm Golden',
        overlays: [
          VideoOverlayItem(
            id: 'ov_1',
            type: OverlayType.text,
            content: 'Guau! 🐶',
            offset: const Offset(10, 10),
          ),
        ],
        overlayPngBytes: mockPngBytes,
      );

      expect(result.overlayPngBytes, isNotNull);
      expect(result.overlayPngBytes!.length, equals(8));
      expect(result.overlayPngBytes![0], equals(137));
    });
  });
}
