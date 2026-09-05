class Participation {
  final String id;
  final String challengeId;
  final String userId;
  final String status;
  final String completionStatus;
  final String verificationStatus;
  final DateTime? startedAt;
  final DateTime? lastActivityAt;
  final DateTime? completedAt;

  Participation({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.status,
    required this.completionStatus,
    required this.verificationStatus,
    this.startedAt,
    this.lastActivityAt,
    this.completedAt,
  });

  factory Participation.fromJson(Map<String, dynamic> json) {
    return Participation(
      id: json['id']?.toString() ?? '',
      challengeId: json['challenge_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      status: json['status'] ?? 'ACCEPTED',
      completionStatus: json['completion_status'] ?? 'NOT_COMPLETED',
      verificationStatus: json['verification_status'] ?? 'NOT_REQUIRED',
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at']) : null,
      lastActivityAt:
          json['last_activity_at'] != null ? DateTime.tryParse(json['last_activity_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at']) : null,
    );
  }
}
