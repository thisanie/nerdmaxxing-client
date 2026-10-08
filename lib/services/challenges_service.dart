import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/challenge.dart';
import '../models/challenge_detail.dart';
import 'api_client.dart';
import 'app_cache.dart';

class ChallengesService {
  final ApiClient api;
  ChallengesService(this.api);

  Future<List<Challenge>> list({
    int limit = 20,
    int offset = 0,
    String? category,
  }) async {
    final data = await api.get(
      '/challenges',
      query: {'limit': limit, 'offset': offset, 'category': ?category},
    );
    if (offset == 0 && category == null) {
      await AppCache.write('challenges_initial', data);
    }
    return (data as List).map((e) => Challenge.fromJson(e)).toList();
  }

  Future<List<Challenge>?> getCachedInitial() async {
    final data = await AppCache.read('challenges_initial');
    return data is List
        ? data
              .whereType<Map>()
              .map((item) => Challenge.fromJson(Map<String, dynamic>.from(item)))
              .toList()
        : null;
  }

  Future<Challenge> getBySlug(String slug) async {
    final data = await api.get('/challenges/$slug');
    return Challenge.fromJson(data);
  }

  Future<ChallengeDetail> getDetailBySlug(String slug) async {
    final data = await api.get('/challenges/$slug/detail');
    await AppCache.write('challenge_detail_$slug', data);
    return ChallengeDetail.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<ChallengeDetail?> getCachedDetailBySlug(String slug) async {
    final data = await AppCache.read('challenge_detail_$slug');
    return data is Map
        ? ChallengeDetail.fromJson(Map<String, dynamic>.from(data))
        : null;
  }

  Future<bool> getSaveStatus(String slug) async {
    final data = await api.get('/challenges/$slug/save-status');
    if (data is bool) return data;
    if (data is Map) {
      return data['saved'] == true || data['is_saved'] == true;
    }
    return false;
  }

  Future<void> save(String slug) async {
    await api.post('/challenges/$slug/save');
  }

  Future<void> unsave(String slug) async {
    await api.delete('/challenges/$slug/save');
  }

  Future<Challenge> create({
    required String title,
    required Uint8List imageBytes,
    required String imageFilename,
    required List<ChallengeResource> resources,
    required String shortDescription,
    required String fullDescription,
    required String difficultyLevel,
    int? estimatedEffortMinMinutes,
    int? estimatedEffortMaxMinutes,
    required String verificationType,
  }) async {
    final payload = {
      'title': title,
      'image_url': null,
      'resources': resources.map((r) => r.toCreateJson()).toList(),
      'short_description': shortDescription,
      'full_description': fullDescription,
      'difficulty_level': difficultyLevel,
      'estimated_effort_min_minutes': ?estimatedEffortMinMinutes,
      'estimated_effort_max_minutes': ?estimatedEffortMaxMinutes,
      'estimated_duration_minutes': null,
      'category_ids': <String>[],
      'verification_type': verificationType,
    };
    final payloadJson = jsonEncode(payload);
    final data = await api.post(
      '/challenges',
      data: FormData.fromMap({
        'payload': payloadJson,
        'image': MultipartFile.fromBytes(imageBytes, filename: imageFilename),
      }),
    );
    return Challenge.fromJson(data);
  }
}
