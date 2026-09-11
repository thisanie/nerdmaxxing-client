class ProgressLog {
  final String id;
  final String participantId;
  final String userId;
  final int minutesSpent;
  final String? note;
  final DateTime? createdAt;

  ProgressLog({
    required this.id,
    required this.participantId,
    required this.userId,
    required this.minutesSpent,
    this.note,
    this.createdAt,
  });

  factory ProgressLog.fromJson(Map<String, dynamic> json) {
    return ProgressLog(
      id: json['id']?.toString() ?? '',
      participantId: json['participant_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      minutesSpent: (json['minutes_spent'] as num?)?.toInt() ?? 0,
      note: json['note']?.toString(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}
