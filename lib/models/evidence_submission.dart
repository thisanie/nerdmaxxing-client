class EvidenceSubmission {
  final String id;
  final String challengeId;
  final String participantId;
  final String userId;
  final String status;
  final String? explanation;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  EvidenceSubmission({
    required this.id,
    required this.challengeId,
    required this.participantId,
    required this.userId,
    required this.status,
    this.explanation,
    this.submittedAt,
    this.reviewedAt,
  });

  factory EvidenceSubmission.fromJson(Map<String, dynamic> json) {
    return EvidenceSubmission(
      id: json['id']?.toString() ?? '',
      challengeId: json['challenge_id']?.toString() ?? '',
      participantId: json['participant_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      status: json['status'] ?? 'PENDING',
      explanation: json['explanation'],
      submittedAt: json['submitted_at'] != null ? DateTime.tryParse(json['submitted_at']) : null,
      reviewedAt: json['reviewed_at'] != null ? DateTime.tryParse(json['reviewed_at']) : null,
    );
  }
}
