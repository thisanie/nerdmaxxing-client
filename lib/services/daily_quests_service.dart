import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../models/daily_quest.dart';
import 'api_client.dart';

class DailyQuestsService {
  final ApiClient api;

  DailyQuestsService(this.api);

  Future<String> getLocalTimezone() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      return 'UTC';
    }
  }

  Future<DailyQuestToday> getToday({String? timezone}) async {
    final resolvedTimezone = timezone ?? await getLocalTimezone();
    final data = await api.get(
      '/daily-quests/today',
      query: {'timezone': resolvedTimezone},
    );
    return DailyQuestToday.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<DailyQuestAttempt> startToday({String? timezone}) async {
    final resolvedTimezone = timezone ?? await getLocalTimezone();
    final data = await api.post(
      '/daily-quests/today/start?timezone='
      '${Uri.encodeQueryComponent(resolvedTimezone)}',
    );
    return _parseAttempt(data, fallbackStatus: 'IN_PROGRESS');
  }

  Future<DailyQuestAttempt> submitQuiz(
    List<int> answers, {
    String? timezone,
  }) async {
    final resolvedTimezone = timezone ?? await getLocalTimezone();
    final data = await api.post(
      '/daily-quests/today/quiz?timezone='
      '${Uri.encodeQueryComponent(resolvedTimezone)}',
      data: {'answers': answers},
    );
    return _parseAttempt(data, fallbackStatus: 'IN_PROGRESS');
  }

  Future<DailyQuestAttempt> submitEvidence({
    required Uint8List bytes,
    required String filename,
    required String verificationType,
    String? timezone,
  }) async {
    final normalizedType = verificationType.toUpperCase();
    final limitBytes = normalizedType == 'VIDEO'
        ? 50 * 1024 * 1024
        : 10 * 1024 * 1024;
    if (bytes.length > limitBytes) {
      final limitLabel = normalizedType == 'VIDEO' ? '50 MiB' : '10 MiB';
      throw ApiException(null, 'Choose a file smaller than $limitLabel.');
    }

    final resolvedTimezone = timezone ?? await getLocalTimezone();
    final data = await api.post(
      '/daily-quests/today/evidence?timezone='
      '${Uri.encodeQueryComponent(resolvedTimezone)}',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );
    return _parseAttempt(data, fallbackStatus: 'PENDING_REVIEW');
  }

  DailyQuestAttempt _parseAttempt(
    Object? data, {
    required String fallbackStatus,
  }) {
    if (data is Map) {
      final response = Map<String, dynamic>.from(data);
      final attempt = response['attempt'] ??
          response['current_attempt'] ??
          response['result'];
      if (attempt is Map) {
        return DailyQuestAttempt.fromJson(Map<String, dynamic>.from(attempt));
      }
      if (response.containsKey('status') ||
          response.containsKey('state') ||
          response.containsKey('score') ||
          response.containsKey('score_percent') ||
          response.containsKey('passed') ||
          response.containsKey('completed')) {
        return DailyQuestAttempt.fromJson(response);
      }
    }
    return DailyQuestAttempt(status: fallbackStatus);
  }
}