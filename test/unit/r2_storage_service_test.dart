import 'package:flutter_test/flutter_test.dart';
import 'package:pawtbook/services/r2_storage_service.dart';

void main() {
  group('Cloudflare R2 Storage Service Unit Tests', () {
    late R2StorageService r2Service;

    setUp(() {
      r2Service = R2StorageService(mediaDomain: 'https://media.pawbooklife.com');
    });

    test('getPublicUrl formats Cloudflare R2 bucket URLs correctly', () {
      final url = r2Service.getPublicUrl('posts/pet_1_12345.jpg');
      expect(url, equals('https://media.pawbooklife.com/posts/pet_1_12345.jpg'));
    });

    test('validatePublicUrlAvailability verifies public media endpoint domain', () async {
      final isValid = await r2Service.validatePublicUrlAvailability('https://media.pawbooklife.com/test.jpg');
      expect(isValid, isTrue);
    });
  });
}
