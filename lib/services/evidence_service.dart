import '../models/evidence_submission.dart';
import 'api_client.dart';
import 'app_cache.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';

class EvidenceService {
  final ApiClient api;
  EvidenceService(this.api);

  Future<bool> hasSubmitted(
    String challengeId, {
    String? cacheKey,
  }) async {
    try {
      final data = await api.get('/evidence/status/$challengeId');
      final submitted = data is Map && data['has_submitted'] == true;
      await _cacheSubmittedFlag(cacheKey ?? challengeId, submitted);
      return submitted;
    } on ApiException catch (error) {
      if (error.isNotFound && cacheKey != null) {
        return await getCachedSubmittedFlag(cacheKey) ?? false;
      }
      rethrow;
    }
  }

  Future<bool?> getCachedSubmittedFlag(String cacheKey) async {
    final data = await AppCache.read('evidence_submitted_$cacheKey');
    return data is Map && data['has_submitted'] is bool
        ? data['has_submitted'] as bool
        : null;
  }

  Future<EvidenceSubmission?> getSubmission(String submissionId) async {
    final data = await api.get('/evidence/$submissionId');
    final submission = _parseSubmission(data);
    if (submission != null) await cacheStatus(submission);
    return submission;
  }

  Future<EvidenceApprovalStatus> getApprovalStatus(String submissionId) async {
    final data = await api.get('/evidence/$submissionId/is-approved');
    return EvidenceApprovalStatus.fromJson(Map<String, dynamic>.from(data));
  }

  Future<EvidenceSubmission?> getCachedStatus(String cacheKey) async {
    final data = await AppCache.read('evidence_status_$cacheKey');
    if (data is Map && data['submitted'] == false) return null;
    return data is Map
      ? _parseSubmission(data)
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
    await _cacheSubmittedFlag(submission.participantId, true);
    await cacheStatus(submission);
    return submission;
  }

  Future<EvidenceSubmission> selfVerify(String submissionId) async {
    final data = await api.post('/evidence/$submissionId/self-verify');
    final submission = EvidenceSubmission.fromJson(data);
    await cacheStatus(submission);
    return submission;
  }

  Future<EvidenceSubmission> verify(
    String submissionId, {
    required String decision,
    String? note,
  }) async {
    final data = await api.post(
      '/evidence/$submissionId/verify',
      data: {'decision': decision, 'note': note},
    );
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

  Future<void> _cacheSubmittedFlag(String cacheKey, bool submitted) async {
    if (cacheKey.isEmpty) return;
    await AppCache.write(
      'evidence_submitted_$cacheKey',
      {'has_submitted': submitted},
    );
  }

  EvidenceSubmission? _parseSubmission(dynamic data) {
    if (data is! Map) return null;
    final json = Map<String, dynamic>.from(data);
    if (json['id'] == null) return null;
    return EvidenceSubmission.fromJson(json);
  }
}
