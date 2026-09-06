import 'challenge.dart';

class DiscoverCategory {
  final String id;
  final String name;
  final String slug;
  final String icon;
  final int? challengeCount;

  const DiscoverCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.icon,
    this.challengeCount,
  });

  factory DiscoverCategory.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? json['title'] ?? 'Explore').toString();
    return DiscoverCategory(
      id: json['id']?.toString() ?? name,
      name: name,
      slug: (json['slug'] ?? json['key'] ?? name).toString(),
      icon: (json['icon'] ?? json['emoji'] ?? '✦').toString(),
      challengeCount: _toInt(json['challenge_count'] ?? json['count']),
    );
  }

  static int? _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class DiscoverFeed {
  final Challenge? featured;
  final List<Challenge> trending;
  final List<DiscoverCategory> categories;
  final List<Challenge> newChallenges;
  final List<Challenge> recommended;
  final List<Challenge> legendary;
  final List<Challenge> unexpected;

  const DiscoverFeed({
    this.featured,
    this.trending = const [],
    this.categories = const [],
    this.newChallenges = const [],
    this.recommended = const [],
    this.legendary = const [],
    this.unexpected = const [],
  });

  factory DiscoverFeed.fromJson(Map<String, dynamic> json) {
    List<Challenge> challenges(String key) {
      final value = json[key];
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((item) => Challenge.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    final featuredValue = json['featured'];
    return DiscoverFeed(
      featured: featuredValue is Map
          ? Challenge.fromJson(Map<String, dynamic>.from(featuredValue))
          : null,
      trending: challenges('trending'),
      categories:
          (json['categories'] is List ? json['categories'] as List : const [])
              .whereType<Map>()
              .map(
                (item) =>
                    DiscoverCategory.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(),
      newChallenges: challenges('new_challenges'),
      recommended: challenges('recommended'),
      legendary: challenges('legendary'),
      unexpected: challenges('unexpected'),
    );
  }
}
