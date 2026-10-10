import 'challenge.dart';

class ChallengeProgressSnapshot {
  final Object? currentValue;
  final Object? targetValue;
  final Object? baselineValue;
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
    this.baselineValue,
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
      baselineValue: json['baseline_value'],
      unit: json['unit']?.toString() ?? '',
      completedResourceCount:
          (json['completed_resource_count'] as num?)?.toInt() ?? 0,
      totalResourceCount: (json['total_resource_count'] as num?)?.toInt() ?? 0,
      completedMilestoneCount:
          (json['completed_milestone_count'] as num?)?.toInt() ?? 0,
      totalMilestoneCount:
          (json['total_milestone_count'] as num?)?.toInt() ?? 0,
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
        .where(
          (resource) => resource.title.isNotEmpty || resource.url.isNotEmpty,
        )
        .toList();

    return ChallengeMilestone(
      id: json['id']?.toString() ?? '',
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'LOCKED',
      currentValue: readOptional('current_value'),
      targetValue: readOptional('target_value'),
      completedResourceCount:
          (json['completed_resource_count'] as num?)?.toInt() ?? 0,
      totalResourceCount:
          (json['total_resource_count'] as num?)?.toInt() ?? resources.length,
      loggedMinutes: (json['logged_minutes'] as num?)?.toInt() ?? 0,
      resources: resources,
    );
  }
}

class ChallengeAttempt {
  final String id;
  final Map<String, double> metrics;
  final String? note;
  final bool? meetsTarget;
  final DateTime? createdAt;

  const ChallengeAttempt({
    required this.id,
    this.metrics = const {},
    this.note,
    this.meetsTarget,
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
    final metricKey = json['metric_key']?.toString();
    final rawValue = json['value'];
    if (metricKey != null && metricKey.isNotEmpty) {
      final value = rawValue is num
          ? rawValue.toDouble()
          : double.tryParse('$rawValue');
      if (value != null) metrics[metricKey] = value;
    }
    return ChallengeAttempt(
      id: json['id']?.toString() ?? '',
      metrics: metrics,
      note: json['note']?.toString(),
      meetsTarget: json['meets_target'] is bool
          ? json['meets_target'] as bool
          : null,
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

class VerificationAccount {
  final String providerUserId;
  final String username;
  final String? avatarUrl;
  final DateTime? verifiedAt;

  const VerificationAccount({
    required this.providerUserId,
    required this.username,
    this.avatarUrl,
    this.verifiedAt,
  });

  factory VerificationAccount.fromJson(Map<String, dynamic> json) {
    return VerificationAccount(
      providerUserId: json['provider_user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      verifiedAt: json['verified_at'] == null
          ? null
          : DateTime.tryParse(json['verified_at'].toString()),
    );
  }
}

class VerificationProvider {
  final String id;
  final String name;
  final String connectUrl;
  final bool connected;
  final VerificationAccount? account;

  const VerificationProvider({
    required this.id,
    required this.name,
    required this.connectUrl,
    required this.connected,
    this.account,
  });

  factory VerificationProvider.fromJson(Map<String, dynamic> json) {
    return VerificationProvider(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      connectUrl: json['connect_url']?.toString() ?? '',
      connected: json['connected'] == true,
      account: json['account'] is Map
          ? VerificationAccount.fromJson(
              Map<String, dynamic>.from(json['account'] as Map),
            )
          : null,
    );
  }
}

class VerificationEvidenceRules {
  final List<String> allowedTypes;
  final bool requiresFile;
  final bool requiresExplanation;
  final int? maxFileSizeBytes;
  final int? maxDurationSeconds;
  final List<String> allowedMimeTypes;

  const VerificationEvidenceRules({
    this.allowedTypes = const [],
    this.requiresFile = false,
    this.requiresExplanation = false,
    this.maxFileSizeBytes,
    this.maxDurationSeconds,
    this.allowedMimeTypes = const [],
  });

  factory VerificationEvidenceRules.fromJson(Map<String, dynamic> json) {
    return VerificationEvidenceRules(
      allowedTypes: (json['allowed_types'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      requiresFile: json['requires_file'] == true,
      requiresExplanation: json['requires_explanation'] == true,
      maxFileSizeBytes: (json['max_file_size_bytes'] as num?)?.toInt(),
      maxDurationSeconds: (json['max_duration_seconds'] as num?)?.toInt(),
      allowedMimeTypes: (json['allowed_mime_types'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class VerificationCompletion {
  final String mode;
  final bool requiresReview;

  const VerificationCompletion({
    this.mode = 'SELF_CONFIRMATION',
    this.requiresReview = false,
  });

  factory VerificationCompletion.fromJson(Map<String, dynamic> json) {
    return VerificationCompletion(
      mode: json['mode']?.toString() ?? 'SELF_CONFIRMATION',
      requiresReview: json['requires_review'] == true,
    );
  }
}

class VerificationState {
  final String status;
  final String? submissionId;
  final String? rejectionReason;
  final bool canRetry;

  const VerificationState({
    this.status = 'NOT_STARTED',
    this.submissionId,
    this.rejectionReason,
    this.canRetry = false,
  });

  factory VerificationState.fromJson(Map<String, dynamic> json) {
    return VerificationState(
      status: json['status']?.toString() ?? 'NOT_STARTED',
      submissionId: json['submission_id']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      canRetry: json['can_retry'] == true,
    );
  }

  static const empty = VerificationState();
}

class ChallengeVerification {
  final String type;
  final String kind;
  final List<ChallengeRequirement> requirements;
  final int requiredRuns;
  final String instructions;
  final VerificationProvider? provider;
  final VerificationEvidenceRules evidence;
  final VerificationCompletion completion;

  const ChallengeVerification({
    required this.type,
    this.kind = 'SELF_REPORTED',
    this.requirements = const [],
    required this.requiredRuns,
    required this.instructions,
    this.provider,
    this.evidence = const VerificationEvidenceRules(),
    this.completion = const VerificationCompletion(),
  });

  factory ChallengeVerification.fromJson(Map<String, dynamic> json) {
    final rawRequirements = json['requirements'];
    final type = json['type']?.toString() ?? 'SELF_REPORTED';
    final kind = json['kind']?.toString() ?? type;
    final providerJson = json['provider'];
    return ChallengeVerification(
      type: type,
      kind: kind,
      requirements: rawRequirements is List
          ? rawRequirements
                .whereType<Map>()
                .map(
                  (item) => ChallengeRequirement.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      requiredRuns: (json['required_runs'] as num?)?.toInt() ?? 1,
      instructions: json['instructions']?.toString() ?? '',
      provider: providerJson is Map
          ? VerificationProvider.fromJson(
              Map<String, dynamic>.from(providerJson),
            )
          : type == 'ACCOUNT_VERIFIED'
              ? const VerificationProvider(
                  id: 'chess_com',
                  name: 'Chess.com',
                  connectUrl: '',
                  connected: false,
                )
          : null,
      evidence: json['evidence'] is Map
          ? VerificationEvidenceRules.fromJson(
              Map<String, dynamic>.from(json['evidence'] as Map),
            )
          : const VerificationEvidenceRules(),
      completion: json['completion'] is Map
          ? VerificationCompletion.fromJson(
              Map<String, dynamic>.from(json['completion'] as Map),
            )
          : const VerificationCompletion(),
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
  final VerificationState verificationState;

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
    this.verificationState = VerificationState.empty,
  });

  factory ChallengeDetail.fromJson(Map<String, dynamic> json) {
    final challengeJson = json['challenge'] is Map
        ? Map<String, dynamic>.from(json['challenge'] as Map)
        : json;
    List<Map<String, dynamic>> listOfMaps(String key) {
      final value = json[key];
      return value is List
          ? value
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
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

    final challenge = Challenge.fromJson(challengeJson);
    final verificationJson = json['verification'] is Map
      ? Map<String, dynamic>.from(json['verification'] as Map)
      : <String, dynamic>{'type': challenge.verificationType};
    final verification = ChallengeVerification.fromJson(verificationJson);

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
      attempts: listOfMaps('attempts').map(ChallengeAttempt.fromJson).toList(),
      participants: listOfMaps('participants')
          .map(ChallengeParticipant.fromJson)
          .toList(),
      participantCount: (stats['participant_count'] as num?)?.toInt() ?? 0,
      completedParticipantCount:
          (stats['completed_participant_count'] as num?)?.toInt() ?? 0,
      progress: progress,
      verification: verification,
      verificationState: json['verification_state'] is Map
          ? VerificationState.fromJson(
              Map<String, dynamic>.from(json['verification_state'] as Map),
            )
          : VerificationState.empty,
    );
  }

  factory ChallengeDetail.fromChallenge(Challenge challenge) => ChallengeDetail(
    challenge: challenge,
    metrics: challenge.metrics,
    requirements: challenge.requirements,
    participantCount: challenge.enrollmentCount ?? 0,
    verification: ChallengeVerification(
      type: challenge.verificationType,
      requiredRuns: 1,
      instructions: '',
    ),
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
