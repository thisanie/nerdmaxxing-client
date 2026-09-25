import 'challenge.dart';

class ChallengeProgressSnapshot {
  final double currentValue;
  final double targetValue;
  final String unit;
  final double? baselineValue;
  final double? bestValue;
  final double? averageValue;
  final double? accuracyPercent;
  final int attemptCount;
  final int loggedMinutes;

  const ChallengeProgressSnapshot({
    required this.currentValue,
    required this.targetValue,
    required this.unit,
    this.baselineValue,
    this.bestValue,
    this.averageValue,
    this.accuracyPercent,
    this.attemptCount = 0,
    this.loggedMinutes = 0,
  });

  factory ChallengeProgressSnapshot.fromJson(Map<String, dynamic> json) {
    double readDouble(String key, [double fallback = 0]) {
      final value = json[key];
      return value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;
    }

    double? readOptional(String key) {
      final value = json[key];
      return value is num ? value.toDouble() : double.tryParse('$value');
    }

    return ChallengeProgressSnapshot(
      currentValue: readDouble('current_value'),
      targetValue: readDouble('target_value'),
      unit: json['unit']?.toString() ?? '',
      baselineValue: readOptional('baseline_value'),
      bestValue: readOptional('best_value'),
      averageValue: readOptional('average_value'),
      accuracyPercent: readOptional('accuracy_percent'),
      attemptCount: (json['attempt_count'] as num?)?.toInt() ?? 0,
      loggedMinutes: (json['logged_minutes'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = ChallengeProgressSnapshot(
    currentValue: 0,
    targetValue: 0,
    unit: '',
  );
}

class ChallengeMilestone {
  final String id;
  final int orderIndex;
  final String title;
  final String description;
  final String status;
  final double? currentValue;
  final double? targetValue;

  const ChallengeMilestone({
    required this.id,
    required this.orderIndex,
    required this.title,
    required this.description,
    required this.status,
    this.currentValue,
    this.targetValue,
  });

  factory ChallengeMilestone.fromJson(Map<String, dynamic> json) {
    double? readOptional(String key) {
      final value = json[key];
      return value is num ? value.toDouble() : double.tryParse('$value');
    }

    return ChallengeMilestone(
      id: json['id']?.toString() ?? '',
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'LOCKED',
      currentValue: readOptional('current_value'),
      targetValue: readOptional('target_value'),
    );
  }
}

class ChallengeAttempt {
  final String id;
  final double value;
  final String unit;
  final double? accuracyPercent;
  final DateTime? createdAt;

  const ChallengeAttempt({
    required this.id,
    required this.value,
    required this.unit,
    this.accuracyPercent,
    this.createdAt,
  });

  factory ChallengeAttempt.fromJson(Map<String, dynamic> json) {
    double readDouble(String key) {
      final value = json[key];
      return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    }

    final accuracy = json['accuracy_percent'];
    return ChallengeAttempt(
      id: json['id']?.toString() ?? '',
      value: readDouble('value'),
      unit: json['unit']?.toString() ?? '',
      accuracyPercent: accuracy is num
          ? accuracy.toDouble()
          : double.tryParse('$accuracy'),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}

class ChallengeParticipant {
  final String userId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String status;
  final DateTime? completedAt;

  const ChallengeParticipant({
    required this.userId,
    this.username,
    this.displayName,
    this.avatarUrl,
    required this.status,
    this.completedAt,
  });

  factory ChallengeParticipant.fromJson(Map<String, dynamic> json) {
    return ChallengeParticipant(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString(),
      displayName: json['display_name']?.toString() ?? json['name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.tryParse(json['completed_at'].toString()),
    );
  }
}

class ChallengeVerification {
  final String type;
  final double? targetValue;
  final String targetUnit;
  final double? minAccuracyPercent;
  final int requiredRuns;
  final String instructions;

  const ChallengeVerification({
    required this.type,
    this.targetValue,
    required this.targetUnit,
    this.minAccuracyPercent,
    required this.requiredRuns,
    required this.instructions,
  });

  factory ChallengeVerification.fromJson(Map<String, dynamic> json) {
    final target = json['target_value'];
    final accuracy = json['min_accuracy_percent'];
    return ChallengeVerification(
      type: json['type']?.toString() ?? 'SELF_REPORTED',
      targetValue: target is num ? target.toDouble() : double.tryParse('$target'),
      targetUnit: json['target_unit']?.toString() ?? '',
      minAccuracyPercent: accuracy is num
          ? accuracy.toDouble()
          : double.tryParse('$accuracy'),
      requiredRuns: (json['required_runs'] as num?)?.toInt() ?? 1,
      instructions: json['instructions']?.toString() ?? '',
    );
  }

  static const empty = ChallengeVerification(
    type: 'SELF_REPORTED',
    targetUnit: '',
    requiredRuns: 1,
    instructions: '',
  );
}

class ChallengeDetail {
  final Challenge challenge;
  final ChallengeProgressSnapshot progress;
  final List<ChallengeMilestone> milestones;
  final List<ChallengeAttempt> attempts;
  final List<ChallengeParticipant> participants;
  final int participantCount;
  final int completedParticipantCount;
  final ChallengeVerification verification;

  const ChallengeDetail({
    required this.challenge,
    this.progress = ChallengeProgressSnapshot.empty,
    this.milestones = const [],
    this.attempts = const [],
    this.participants = const [],
    this.participantCount = 0,
    this.completedParticipantCount = 0,
    this.verification = ChallengeVerification.empty,
  });

  factory ChallengeDetail.fromJson(Map<String, dynamic> json) {
    final challengeJson = json['challenge'] is Map
        ? Map<String, dynamic>.from(json['challenge'] as Map)
        : json;
    List<Map<String, dynamic>> listOfMaps(String key) {
      final value = json[key];
      return value is List
          ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : const [];
    }

    final stats = json['stats'] is Map
        ? Map<String, dynamic>.from(json['stats'] as Map)
        : const <String, dynamic>{};
    final verification = json['verification'] is Map
        ? ChallengeVerification.fromJson(
            Map<String, dynamic>.from(json['verification'] as Map),
          )
        : ChallengeVerification.empty;

    return ChallengeDetail(
      challenge: Challenge.fromJson(challengeJson),
      progress: json['progress'] is Map
          ? ChallengeProgressSnapshot.fromJson(
              Map<String, dynamic>.from(json['progress'] as Map),
            )
          : ChallengeProgressSnapshot.empty,
      milestones: listOfMaps('milestones')
          .map(ChallengeMilestone.fromJson)
          .toList(),
      attempts: listOfMaps('attempts')
          .map(ChallengeAttempt.fromJson)
          .toList(),
      participants: listOfMaps('participants')
          .map(ChallengeParticipant.fromJson)
          .toList(),
      participantCount: (stats['participant_count'] as num?)?.toInt() ?? 0,
      completedParticipantCount:
          (stats['completed_participant_count'] as num?)?.toInt() ?? 0,
      verification: verification,
    );
  }

  factory ChallengeDetail.fromChallenge(Challenge challenge) => ChallengeDetail(
        challenge: challenge,
        participantCount: challenge.enrollmentCount ?? 0,
      );
}
