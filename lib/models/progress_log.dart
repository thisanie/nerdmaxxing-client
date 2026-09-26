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

class ResourceCompletion {
  final String resourceId;
  final String milestoneId;
  final bool completed;
  final bool milestoneCompleted;
  final String milestoneStatus;
  final String challengeStatus;
  final bool readyForProof;

  const ResourceCompletion({
    required this.resourceId,
    required this.milestoneId,
    required this.completed,
    required this.milestoneCompleted,
    required this.milestoneStatus,
    required this.challengeStatus,
    required this.readyForProof,
  });

  factory ResourceCompletion.fromJson(Map<String, dynamic> json) {
    return ResourceCompletion(
      resourceId: json['resource_id']?.toString() ?? '',
      milestoneId: json['milestone_id']?.toString() ?? '',
      completed: json['completed'] == true,
      milestoneCompleted: json['milestone_completed'] == true,
      milestoneStatus: json['milestone_status']?.toString() ?? 'CURRENT',
      challengeStatus: json['challenge_status']?.toString() ?? 'IN_PROGRESS',
      readyForProof: json['ready_for_proof'] == true,
    );
  }
}

class MetricAttempt {
  final String id;
  final String metricKey;
  final double value;
  final String unit;
  final bool meetsTarget;

  const MetricAttempt({
    required this.id,
    required this.metricKey,
    required this.value,
    required this.unit,
    required this.meetsTarget,
  });

  factory MetricAttempt.fromJson(Map<String, dynamic> json) {
    final rawValue = json['value'];
    return MetricAttempt(
      id: json['id']?.toString() ?? '',
      metricKey: json['metric_key']?.toString() ?? '',
      value: rawValue is num ? rawValue.toDouble() : double.tryParse('$rawValue') ?? 0,
      unit: json['unit']?.toString() ?? '',
      meetsTarget: json['meets_target'] == true,
    );
  }
}
