import '../models/evidence_submission.dart';
import 'api_client.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';

class EvidenceService {
  final ApiClient api;
  EvidenceService(this.api);

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
    return EvidenceSubmission.fromJson(data);
  }

  Future<EvidenceSubmission> selfVerify(String submissionId) async {
    final data = await api.post('/evidence/$submissionId/self-verify');
    return EvidenceSubmission.fromJson(data);
  }
}
