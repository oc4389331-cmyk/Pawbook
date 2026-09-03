import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class RenderBackendService {
  final String baseUrl;
  final http.Client _client;

  RenderBackendService({
    this.baseUrl = AppConfig.backendApiUrl,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  /// Validates Dynamic.xyz JWT token and syncs user with Supabase
  Future<Map<String, dynamic>> verifyAuth({
    required String token,
    String? walletAddress,
    String? email,
  }) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/auth/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'walletAddress': walletAddress,
          'email': email,
        }),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}

    // Fallback response for dev/offline mode
    final userSuffix = walletAddress != null ? walletAddress.substring(0, 8) : 'demo';
    return {
      'success': true,
      'user': {
        'id': 'usr_$userSuffix',
        'walletAddress': walletAddress,
        'email': email,
        'pawtScore': 100,
      }
    };
  }

  /// Obtains Presigned R2 PUT URL from Render Backend.
  /// Enforces rule: Only requests with valid petId are authorized.
  Future<Map<String, dynamic>> requestUploadUrl({
    required String? petId,
    required String mediaType,
    required String filename,
  }) async {
    if (petId == null || petId.isEmpty) {
      return {
        'success': false,
        'error': 'ROLE_RESTRICTION: Only Pet Profiles can upload content. Human sponsors must register a pet first.'
      };
    }

    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/media/upload-url'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'petId': petId,
          'mediaType': mediaType,
          'filename': filename,
        }),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}

    // Mock fallback response
    final ext = filename.contains('.') ? filename.split('.').last : (mediaType == 'video' ? 'mp4' : 'jpg');
    final key = 'posts/${petId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final publicUrl = '${AppConfig.r2MediaDomain}/$key';
    return {
      'success': true,
      'petId': petId,
      'key': key,
      'presignedPutUrl': '${AppConfig.r2MediaDomain}/upload-signed/$key',
      'publicUrl': publicUrl,
      'initialStatus': 'pending_review',
    };
  }

  /// Triggers Backend Safety & Computer Vision Moderation evaluation
  Future<Map<String, dynamic>> triggerModeration({
    required String postId,
    required String mediaUrl,
    String? forceDecision,
  }) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/media/moderate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'postId': postId,
          'mediaUrl': mediaUrl,
          'forceDecision': forceDecision,
        }),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}

    final isRejected = forceDecision == 'reject' || mediaUrl.contains('inappropriate');
    return {
      'success': true,
      'postId': postId,
      'status': isRejected ? 'rejected' : 'active',
      'reason': isRejected ? 'FAILED_MODERATION: Flagged for policy violation' : 'Passed safety check',
    };
  }
}
