import '../models/evidence_submission.dart';
import 'api_client.dart';
import 'app_cache.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';

class EvidenceService {
  final ApiClient api;
  EvidenceService(this.api);

  Future<EvidenceSubmission?> getStatus(
    String challengeId, {
    String? cacheKey,
  }) async {
    try {
      final data = await api.get('/evidence/status/$challengeId');
      final submission = _parseStatus(data);
      await _cacheStatus(cacheKey ?? challengeId, submission);
      return submission;
    } on ApiException catch (error) {
      if (error.isNotFound) {
        await _cacheStatus(cacheKey ?? challengeId, null);
        return null;
      }
      rethrow;
    }
  }

  Future<EvidenceSubmission?> getCachedStatus(String cacheKey) async {
    final data = await AppCache.read('evidence_status_$cacheKey');
    if (data is Map && data['submitted'] == false) return null;
    return data is Map
      ? _parseStatus(data)
        : null;
  }

  Future<void> cacheStatus(EvidenceSubmission submission) async {
    await _cacheStatus(submission.participantId, submission);
  }

  Future<EvidenceSubmission> submit(
    String participantId, {
    required String explanation,
    String? textContent,
    String? externalUrl,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final data = await api.post(
      '/evidence/participation/$participantId',
      data: FormData.fromMap({
        'explanation': explanation,
        if (textContent != null && textContent.isNotEmpty)
          'text_content': textContent,
        if (externalUrl != null && externalUrl.isNotEmpty)
          'external_url': externalUrl,
        if (fileBytes != null)
          'file': MultipartFile.fromBytes(
            fileBytes,
            filename: fileName ?? 'evidence-file',
          ),
      }),
    );
    final submission = EvidenceSubmission.fromJson(data);
    await cacheStatus(submission);
    return submission;
  }

  Future<EvidenceSubmission> selfVerify(String submissionId) async {
    final data = await api.post('/evidence/$submissionId/self-verify');
    final submission = EvidenceSubmission.fromJson(data);
    await cacheStatus(submission);
    return submission;
  }

  Future<void> _cacheStatus(
    String cacheKey,
    EvidenceSubmission? submission,
  ) async {
    if (cacheKey.isEmpty) return;
    await AppCache.write(
      'evidence_status_$cacheKey',
      submission == null
          ? <String, dynamic>{'submitted': false}
          : {
              'id': submission.id,
              'challenge_id': submission.challengeId,
              'participant_id': submission.participantId,
              'user_id': submission.userId,
              'status': submission.status,
              'explanation': submission.explanation,
              'submitted_at': submission.submittedAt?.toIso8601String(),
              'reviewed_at': submission.reviewedAt?.toIso8601String(),
            },
    );
  }

  EvidenceSubmission? _parseStatus(dynamic data) {
    if (data is List) {
      return data.isEmpty ? null : _parseStatus(data.first);
    }
    if (data is! Map) return null;
    final json = Map<String, dynamic>.from(data);
    if (json['submitted'] == false || json['has_submission'] == false) {
      return null;
    }
    for (final key in ['submission', 'evidence', 'data']) {
      final nested = json[key];
      if (nested is Map) return _parseStatus(nested);
    }
    if (json['id'] == null && json['submission_id'] != null) {
      json['id'] = json['submission_id'];
    }
    if (json['id'] == null) return null;
    return EvidenceSubmission.fromJson(json);
  }
}
