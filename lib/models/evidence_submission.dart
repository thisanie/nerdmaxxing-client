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
  final int? auraAwarded;
  final int? dayStreak;

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
    this.auraAwarded,
    this.dayStreak,
  });

  factory EvidenceSubmission.fromJson(Map<String, dynamic> json) {
    final rawAuraAwarded =
      json['aura_rewarded'] ?? json['aura_rewared'] ?? json['aura_awarded'];
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
      auraAwarded: (rawAuraAwarded as num?)?.toInt(),
      dayStreak: (json['day_streak'] as num?)?.toInt(),
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

class EvidenceQueuePage {
  final List<EvidenceSubmission> items;
  final int total;
  final int limit;
  final int offset;

  const EvidenceQueuePage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory EvidenceQueuePage.fromJson(Map<String, dynamic> json) {
    return EvidenceQueuePage(
      items: (json['items'] as List? ?? [])
          .whereType<Map>()
          .map((item) => EvidenceSubmission.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }
}
