import 'challenge.dart';

class ChallengeProgressSnapshot {
  final Object? currentValue;
  final Object? targetValue;
  final String unit;
  final int completedResourceCount;
  final int totalResourceCount;
  final int completedMilestoneCount;
  final int totalMilestoneCount;
  final int loggedMinutes;
  final String challengeStatus;
  final bool readyForProof;

  const ChallengeProgressSnapshot({
    this.currentValue,
    this.targetValue,
    required this.unit,
    this.completedResourceCount = 0,
    this.totalResourceCount = 0,
    this.completedMilestoneCount = 0,
    this.totalMilestoneCount = 0,
    this.loggedMinutes = 0,
    this.challengeStatus = 'ACTIVE',
    this.readyForProof = false,
  });

  factory ChallengeProgressSnapshot.fromJson(Map<String, dynamic> json) {
    return ChallengeProgressSnapshot(
      currentValue: json['current_value'],
      targetValue: json['target_value'],
      unit: json['unit']?.toString() ?? '',
      completedResourceCount: (json['completed_resource_count'] as num?)?.toInt() ?? 0,
      totalResourceCount: (json['total_resource_count'] as num?)?.toInt() ?? 0,
      completedMilestoneCount: (json['completed_milestone_count'] as num?)?.toInt() ?? 0,
      totalMilestoneCount: (json['total_milestone_count'] as num?)?.toInt() ?? 0,
      loggedMinutes: (json['logged_minutes'] as num?)?.toInt() ?? 0,
      challengeStatus: json['challenge_status']?.toString() ?? 'ACTIVE',
      readyForProof: json['ready_for_proof'] == true,
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
  final int completedResourceCount;
  final int totalResourceCount;
  final int loggedMinutes;
  final List<ChallengeResource> resources;

  const ChallengeMilestone({
    required this.id,
    required this.orderIndex,
    required this.title,
    required this.description,
    required this.status,
    this.currentValue,
    this.targetValue,
    this.completedResourceCount = 0,
    this.totalResourceCount = 0,
    this.loggedMinutes = 0,
    this.resources = const [],
  });

  factory ChallengeMilestone.fromJson(
    Map<String, dynamic> json, {
    List<ChallengeResource> resourceCatalog = const [],
  }) {
    double? readOptional(String key) {
      final value = json[key];
      return value is num ? value.toDouble() : double.tryParse('$value');
    }

    final resources = (json['resources'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map((item) {
          final resourceId = item['resource_id']?.toString();
          if (resourceId != null && resourceId.isNotEmpty) {
            for (final resource in resourceCatalog) {
              if (resource.id == resourceId) return resource.withProgress(item);
            }
          }
          return ChallengeResource.fromJson(item);
        })
        .where((resource) => resource.title.isNotEmpty || resource.url.isNotEmpty)
        .toList();

    return ChallengeMilestone(
      id: json['id']?.toString() ?? '',
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'LOCKED',
      currentValue: readOptional('current_value'),
      targetValue: readOptional('target_value'),
      completedResourceCount: (json['completed_resource_count'] as num?)?.toInt() ?? 0,
      totalResourceCount: (json['total_resource_count'] as num?)?.toInt() ?? resources.length,
      loggedMinutes: (json['logged_minutes'] as num?)?.toInt() ?? 0,
      resources: resources,
    );
  }
}

class ChallengeAttempt {
  final String id;
  final Map<String, double> metrics;
  final DateTime? createdAt;

  const ChallengeAttempt({
    required this.id,
    this.metrics = const {},
    this.createdAt,
  });

  factory ChallengeAttempt.fromJson(Map<String, dynamic> json) {
    final rawMetrics = json['metrics'];
    final metrics = <String, double>{};
    if (rawMetrics is Map) {
      for (final entry in rawMetrics.entries) {
        final value = entry.value;
        if (value is num) {
          metrics[entry.key.toString()] = value.toDouble();
        } else {
          final parsed = double.tryParse('$value');
          if (parsed != null) metrics[entry.key.toString()] = parsed;
        }
      }
    }
    return ChallengeAttempt(
      id: json['id']?.toString() ?? '',
      metrics: metrics,
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
  final List<ChallengeRequirement> requirements;
  final int requiredRuns;
  final String instructions;

  const ChallengeVerification({
    required this.type,
    this.requirements = const [],
    required this.requiredRuns,
    required this.instructions,
  });

  factory ChallengeVerification.fromJson(Map<String, dynamic> json) {
    final rawRequirements = json['requirements'];
    return ChallengeVerification(
      type: json['type']?.toString() ?? 'SELF_REPORTED',
      requirements: rawRequirements is List
          ? rawRequirements
              .whereType<Map>()
              .map((item) => ChallengeRequirement.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const [],
      requiredRuns: (json['required_runs'] as num?)?.toInt() ?? 1,
      instructions: json['instructions']?.toString() ?? '',
    );
  }

  static const empty = ChallengeVerification(
    type: 'SELF_REPORTED',
    requiredRuns: 1,
    instructions: '',
  );
}

class ChallengeDetail {
  final Challenge challenge;
  final List<ChallengeMetric> metrics;
  final List<ChallengeRequirement> requirements;
  final List<ChallengeMilestone> milestones;
  final List<ChallengeAttempt> attempts;
  final List<ChallengeParticipant> participants;
  final int participantCount;
  final int completedParticipantCount;
  final ChallengeProgressSnapshot progress;
  final ChallengeVerification verification;

  const ChallengeDetail({
    required this.challenge,
    this.metrics = const [],
    this.requirements = const [],
    this.milestones = const [],
    this.attempts = const [],
    this.participants = const [],
    this.participantCount = 0,
    this.completedParticipantCount = 0,
    this.progress = ChallengeProgressSnapshot.empty,
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

    final progress = json['progress'] is Map
        ? ChallengeProgressSnapshot.fromJson(
            Map<String, dynamic>.from(json['progress'] as Map),
          )
        : ChallengeProgressSnapshot.empty;

    final verification = json['verification'] is Map
        ? ChallengeVerification.fromJson(
            Map<String, dynamic>.from(json['verification'] as Map),
          )
        : ChallengeVerification.empty;

    final challenge = Challenge.fromJson(challengeJson);

    return ChallengeDetail(
      challenge: challenge,
        metrics: listOfMaps('metrics')
          .map(ChallengeMetric.fromJson)
          .where((metric) => metric.key.isNotEmpty)
          .toList(),
      requirements: listOfMaps('requirements')
          .map(ChallengeRequirement.fromJson)
          .toList(),
      milestones: listOfMaps('milestones')
          .map(
            (milestone) => ChallengeMilestone.fromJson(
              milestone,
              resourceCatalog: challenge.resources,
            ),
          )
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
        progress: progress,
      verification: verification,
    );
  }

  factory ChallengeDetail.fromChallenge(Challenge challenge) => ChallengeDetail(
        challenge: challenge,
        metrics: challenge.metrics,
        requirements: challenge.requirements,
        participantCount: challenge.enrollmentCount ?? 0,
      );

  ChallengeMetric? get primaryMetric {
    for (final metric in metricDefinitions) {
      if (metric.isPrimary) return metric;
    }
    return metricDefinitions.isEmpty ? null : metricDefinitions.first;
  }

  List<ChallengeMetric> get metricDefinitions {
    final merged = <String, ChallengeMetric>{
      for (final metric in challenge.metrics)
        if (metric.key.isNotEmpty) metric.key: metric,
    };
    for (final metric in metrics) {
      if (metric.key.isEmpty) continue;
      final existing = merged[metric.key];
      merged[metric.key] = existing == null ? metric : existing.merge(metric);
    }
    return merged.values.toList();
  }

  List<ChallengeRequirement> get effectiveRequirements {
    if (requirements.isNotEmpty) return requirements;
    if (verification.requirements.isNotEmpty) return verification.requirements;
    return challenge.requirements;
  }
}
