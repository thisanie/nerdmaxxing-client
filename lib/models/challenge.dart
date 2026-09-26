class ChallengeResource {
  final String id;
  final String title;
  final String url;
  final String resourceType;
  final String rationale;
  final int orderIndex;
  bool completed;

  ChallengeResource({
    required this.id,
    required this.title,
    required this.url,
    required this.resourceType,
    required this.rationale,
    required this.orderIndex,
    this.completed = false,
  });

  factory ChallengeResource.fromJson(Map<String, dynamic> json) {
    return ChallengeResource(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      resourceType: json['resource_type'] ?? 'LINK',
      rationale: json['rationale'] ?? '',
      orderIndex: json['order_index'] ?? 0,
      completed: json['completed'] == true ||
          json['is_completed'] == true ||
          json['completed_at'] != null,
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

class ChallengeMetric {
  final String key;
  final String label;
  final String kind;
  final String unit;
  final double? target;
  final double? current;
  final double? baseline;
  final double? best;
  final double? average;
  final String direction;
  final bool isPrimary;
  final String format;

  const ChallengeMetric({
    required this.key,
    required this.label,
    required this.kind,
    required this.unit,
    this.target,
    this.current,
    this.baseline,
    this.best,
    this.average,
    required this.direction,
    required this.isPrimary,
    required this.format,
  });

  factory ChallengeMetric.fromJson(Map<String, dynamic> json) {
    double? readDouble(String key) {
      final value = json[key];
      return value is num ? value.toDouble() : double.tryParse('$value');
    }

    return ChallengeMetric(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'COUNT',
      unit: json['unit']?.toString() ?? '',
      target: readDouble('target'),
      current: readDouble('current'),
      baseline: readDouble('baseline'),
      best: readDouble('best'),
      average: readDouble('average'),
      direction: json['direction']?.toString() ?? 'AT_LEAST',
      isPrimary: json['is_primary'] == true,
      format: json['format']?.toString() ?? 'DECIMAL_2',
    );
  }

  ChallengeMetric withValues({
    double? current,
    double? baseline,
    double? best,
    double? average,
  }) {
    return ChallengeMetric(
      key: key,
      label: label,
      kind: kind,
      unit: unit,
      target: target,
      current: current ?? this.current,
      baseline: baseline ?? this.baseline,
      best: best ?? this.best,
      average: average ?? this.average,
      direction: direction,
      isPrimary: isPrimary,
      format: format,
    );
  }

  ChallengeMetric merge(ChallengeMetric other) {
    return ChallengeMetric(
      key: key.isEmpty ? other.key : key,
      label: other.label.isEmpty ? label : other.label,
      kind: other.kind == 'COUNT' && kind != 'COUNT' ? kind : other.kind,
      unit: other.unit.isEmpty ? unit : other.unit,
      target: other.target ?? target,
      current: other.current ?? current,
      baseline: other.baseline ?? baseline,
      best: other.best ?? best,
      average: other.average ?? average,
      direction: other.direction == 'AT_LEAST' && direction != 'AT_LEAST'
          ? direction
          : other.direction,
      isPrimary: other.isPrimary || isPrimary,
      format: other.format == 'DECIMAL_2' && format != 'DECIMAL_2'
          ? format
          : other.format,
    );
  }
}

class ChallengeRequirement {
  final String metricKey;
  final String operator;
  final double? value;
  final String unit;
  final String label;

  const ChallengeRequirement({
    required this.metricKey,
    required this.operator,
    this.value,
    required this.unit,
    required this.label,
  });

  factory ChallengeRequirement.fromJson(Map<String, dynamic> json) {
    final rawValue = json['value'];
    return ChallengeRequirement(
      metricKey: json['metric_key']?.toString() ?? '',
      operator: json['operator']?.toString() ?? 'AT_LEAST',
      value: rawValue is num ? rawValue.toDouble() : double.tryParse('$rawValue'),
      unit: json['unit']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}

class Challenge {
  final String id;
  final String title;
  final String? imageUrl;
  final String? imageKey;
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
  final int? completionCount;
  final bool featured;
  final bool legendary;
  final List<Map<String, dynamic>> categories;
  final List<ChallengeMetric> metrics;
  final List<ChallengeRequirement> requirements;

  Challenge({
    required this.id,
    required this.title,
    this.imageUrl,
    this.imageKey,
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
    this.completionCount,
    this.featured = false,
    this.legendary = false,
    this.categories = const [],
    this.metrics = const [],
    this.requirements = const [],
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      imageUrl: json['image_url'],
      imageKey: json['image_key']?.toString(),
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
        completionCount: _readInt(json, const ['completion_count']),
        featured: json['featured'] == true,
        legendary: json['legendary'] == true,
        categories: (json['categories'] as List? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
        metrics: _readList(json['metrics'])
          .map(ChallengeMetric.fromJson)
            .where((metric) => metric.key.isNotEmpty)
          .toList(),
        requirements: _readList(json['requirements'])
          .map(ChallengeRequirement.fromJson)
          .toList(),
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

  static List<Map<String, dynamic>> _readList(Object? value) {
    return value is List
        ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const [];
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
