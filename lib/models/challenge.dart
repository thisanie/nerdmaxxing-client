class ChallengeResource {
  final String id;
  final String title;
  final String url;
  final String resourceType;
  final String rationale;
  final int orderIndex;

  ChallengeResource({
    required this.id,
    required this.title,
    required this.url,
    required this.resourceType,
    required this.rationale,
    required this.orderIndex,
  });

  factory ChallengeResource.fromJson(Map<String, dynamic> json) {
    return ChallengeResource(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      resourceType: json['resource_type'] ?? 'LINK',
      rationale: json['rationale'] ?? '',
      orderIndex: json['order_index'] ?? 0,
    );
  }

  Map<String, dynamic> toCreateJson() => {
    'title': title,
    'url': url,
    'resource_type': resourceType,
    'rationale': rationale,
    'order_index': orderIndex,
  };
}

class Challenge {
  final String id;
  final String title;
  final String? imageUrl;
  final List<ChallengeResource> resources;
  final String slug;
  final String shortDescription;
  final String fullDescription;
  final String creatorId;
  final String difficultyLevel;
  final int auraPoints;
  final String status;
  final String visibility;
  final int? estimatedEffortMinMinutes;
  final int? estimatedEffortMaxMinutes;
  final int? estimatedDurationMinutes;
  final String verificationType;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final int? enrollmentCount;

  Challenge({
    required this.id,
    required this.title,
    this.imageUrl,
    required this.resources,
    required this.slug,
    required this.shortDescription,
    required this.fullDescription,
    required this.creatorId,
    required this.difficultyLevel,
    required this.auraPoints,
    required this.status,
    required this.visibility,
    this.estimatedEffortMinMinutes,
    this.estimatedEffortMaxMinutes,
    this.estimatedDurationMinutes,
    required this.verificationType,
    this.createdAt,
    this.updatedAt,
    this.publishedAt,
    this.enrollmentCount,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      imageUrl: json['image_url'],
      resources: (json['resources'] as List? ?? [])
          .map((e) => ChallengeResource.fromJson(e))
          .toList(),
      slug: json['slug'] ?? '',
      shortDescription: json['short_description'] ?? '',
      fullDescription: json['full_description'] ?? '',
      creatorId: json['creator_id']?.toString() ?? '',
      difficultyLevel: json['difficulty_level'] ?? 'BEGINNER',
      auraPoints: _readInt(json, const ['aura_points']) ?? 0,
      status: json['status'] ?? 'PUBLISHED',
      visibility: json['visibility'] ?? 'PUBLIC',
      estimatedEffortMinMinutes: json['estimated_effort_min_minutes'],
      estimatedEffortMaxMinutes: json['estimated_effort_max_minutes'],
      estimatedDurationMinutes: _readInt(json, const [
        'estimated_duration_minutes',
      ]),
      verificationType: json['verification_type'] ?? 'SELF_REPORTED',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'])
          : null,
      enrollmentCount: _readInt(json, const [
        'enrollment_count',
        'participant_count',
        'joined_count',
        'participants_count',
      ]),
    );
  }

  static int? _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  String get effortLabel {
    if (estimatedEffortMinMinutes == null &&
        estimatedEffortMaxMinutes == null &&
        estimatedDurationMinutes == null) {
      return 'Flexible';
    }
    String fmt(int minutes) {
      if (minutes < 60) return '${minutes}m';
      final h = minutes / 60;
      return h == h.roundToDouble()
          ? '${h.round()}h'
          : '${h.toStringAsFixed(1)}h';
    }

    if (estimatedEffortMinMinutes != null &&
        estimatedEffortMaxMinutes != null) {
      return '${fmt(estimatedEffortMinMinutes!)} - ${fmt(estimatedEffortMaxMinutes!)}';
    }
    return fmt(
      estimatedEffortMinMinutes ??
          estimatedEffortMaxMinutes ??
          estimatedDurationMinutes!,
    );
  }
}
