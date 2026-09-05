import '../models/evidence_submission.dart';
import 'api_client.dart';

class EvidenceService {
  final ApiClient api;
  EvidenceService(this.api);

  Future<EvidenceSubmission> submit(
    String participantId, {
    required String explanation,
    String? textContent,
    String? externalUrl,
  }) async {
    final data = await api.post('/evidence/participation/$participantId', data: {
      'explanation': explanation,
      if (textContent != null && textContent.isNotEmpty) 'text_content': textContent,
      if (externalUrl != null && externalUrl.isNotEmpty) 'external_url': externalUrl,
    });
    return EvidenceSubmission.fromJson(data);
  }

  Future<EvidenceSubmission> selfVerify(String submissionId) async {
    final data = await api.post('/evidence/$submissionId/self-verify');
    return EvidenceSubmission.fromJson(data);
  }
}
