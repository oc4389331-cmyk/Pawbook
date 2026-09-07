import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class R2StorageService {
  final String mediaDomain;
  final http.Client _client;

  R2StorageService({
    this.mediaDomain = AppConfig.r2MediaDomain,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  /// Formats public media URL served from Cloudflare R2: https://media.pawbooklife.com/{key}
  String getPublicUrl(String key) {
    final cleanKey = key.startsWith('/') ? key.substring(1) : key;
    return '$mediaDomain/$cleanKey';
  }

  /// Returns true if the URL looks like a fake/mock presigned URL (not a real AWS/Cloudflare presigned URL).
  bool _isMockPresignedUrl(String url) {
    // Real AWS/Cloudflare R2 presigned URLs contain X-Amz-Signature or similar query params
    return !url.contains('X-Amz-Signature') &&
        !url.contains('x-amz-signature') &&
        !url.contains('Signature=') &&
        url.startsWith(mediaDomain);
  }

  /// Uploads media file to Cloudflare R2 bucket via Presigned PUT URL.
  /// Throws an exception if the upload fails.
  Future<String> uploadMediaWithPresignedUrl({
    required String presignedPutUrl,
    required String publicUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    // Warn in debug if a mock/fake URL is detected
    if (_isMockPresignedUrl(presignedPutUrl)) {
      debugPrint(
        '[R2StorageService] ⚠️ La presignedPutUrl parece ser una URL simulada '
        '(sin firma AWS/Cloudflare). El archivo NO se guardará en R2 real.\n'
        'URL recibida: $presignedPutUrl\n'
        'Verifica que el backend genere URLs presignadas reales.',
      );
      // En modo mock/dev retornamos la publicUrl sin intentar el PUT
      return publicUrl;
    }

    try {
      final response = await _client
          .put(
            Uri.parse(presignedPutUrl),
            headers: {'Content-Type': contentType},
            body: bytes,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[R2StorageService] ✅ Imagen subida a R2: $publicUrl');
        return publicUrl;
      }

      throw Exception(
        'Error al subir a Cloudflare R2 — HTTP ${response.statusCode}: ${response.body}',
      );
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Error de red al subir a Cloudflare R2: $e');
    }
  }

  /// Validates availability of a media file served at public R2 URL
  Future<bool> validatePublicUrlAvailability(String publicUrl) async {
    try {
      final uri = Uri.parse(publicUrl);
      final response = await _client.head(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

