import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/challenge.dart';
import 'api_client.dart';

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
    return (data as List).map((e) => Challenge.fromJson(e)).toList();
  }

  Future<Challenge> getBySlug(String slug) async {
    final data = await api.get('/challenges/$slug');
    return Challenge.fromJson(data);
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
