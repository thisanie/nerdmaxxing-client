class EvidenceSubmission {
  final String id;
  final String challengeId;
  final String participantId;
  final String userId;
  final String status;
  final String? explanation;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? textContent;
  final String? externalUrl;
  final String? fileUrl;
  final String? fileName;
  final String? mimeType;
  final String? reviewReason;

  EvidenceSubmission({
    required this.id,
    required this.challengeId,
    required this.participantId,
    required this.userId,
    required this.status,
    this.explanation,
    this.submittedAt,
    this.reviewedAt,
    this.textContent,
    this.externalUrl,
    this.fileUrl,
    this.fileName,
    this.mimeType,
    this.reviewReason,
  });

  factory EvidenceSubmission.fromJson(Map<String, dynamic> json) {
    return EvidenceSubmission(
      id: json['id']?.toString() ?? '',
      challengeId: json['challenge_id']?.toString() ?? '',
      participantId: json['participant_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      status: json['status'] ?? 'PENDING',
      explanation: json['explanation'],
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'])
          : null,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'])
          : null,
      textContent: json['text_content']?.toString(),
      externalUrl: json['external_url']?.toString(),
      fileUrl: json['file_url']?.toString(),
      fileName: json['file_name']?.toString(),
      mimeType: json['mime_type']?.toString(),
      reviewReason: json['review_reason']?.toString(),
    );
  }
}

class EvidenceApprovalStatus {
  final bool isApproved;
  final String? note;

  const EvidenceApprovalStatus({required this.isApproved, this.note});

  factory EvidenceApprovalStatus.fromJson(Map<String, dynamic> json) {
    return EvidenceApprovalStatus(
      isApproved: json['is_approved'] == true,
      note: json['note']?.toString(),
    );
  }
}
