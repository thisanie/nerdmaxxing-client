import 'challenge.dart';

class DiscoverNerd {
  final int rank;
  final String userId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final int completedCount;
  final int dayStreak;

  const DiscoverNerd({
    required this.rank,
    required this.userId,
    this.username,
    this.displayName,
    this.avatarUrl,
    required this.completedCount,
    required this.dayStreak,
  });

  factory DiscoverNerd.fromJson(Map<String, dynamic> json) {
    int readInt(String key) => (json[key] as num?)?.toInt() ?? 0;

    return DiscoverNerd(
      rank: readInt('rank'),
      userId: (json['user_id'] ?? json['id'])?.toString() ?? '',
      username: json['username']?.toString(),
      displayName: (json['display_name'] ?? json['name'])?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      completedCount: readInt('completed_count'),
      dayStreak: readInt('day_streak'),
    );
  }
}

class DiscoverActivity {
  final String id;
  final String userId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String action;
  final String? challengeId;
  final String? challengeTitle;
  final String? challengeSlug;
  final DateTime? createdAt;

  const DiscoverActivity({
    required this.id,
    required this.userId,
    this.username,
    this.displayName,
    this.avatarUrl,
    required this.action,
    this.challengeId,
    this.challengeTitle,
    this.challengeSlug,
    this.createdAt,
  });

  factory DiscoverActivity.fromJson(Map<String, dynamic> json) {
    return DiscoverActivity(
      id: json['id']?.toString() ?? '',
      userId: (json['user_id'] ?? json['actor_id'])?.toString() ?? '',
      username: json['username']?.toString(),
      displayName: (json['display_name'] ?? json['name'])?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      action: json['action']?.toString() ?? '',
      challengeId: json['challenge_id']?.toString(),
      challengeTitle: json['challenge_title']?.toString(),
      challengeSlug: json['challenge_slug']?.toString(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}

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

class DiscoverUser {
  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  const DiscoverUser({
    required this.id,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  factory DiscoverUser.fromJson(Map<String, dynamic> json) {
    return DiscoverUser(
      id: (json['user_id'] ?? json['id'])?.toString() ?? '',
      username: json['username']?.toString(),
      displayName: (json['display_name'] ?? json['name'])?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}

class DiscoverSearchResult {
  final List<DiscoverUser> users;
  final List<Challenge> challenges;

  const DiscoverSearchResult({
    this.users = const [],
    this.challenges = const [],
  });

  factory DiscoverSearchResult.fromJson(Map<String, dynamic> json) {
    List<T> items<T>(String key, T Function(Map<String, dynamic>) parse) {
      final value = json[key];
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((item) => parse(Map<String, dynamic>.from(item)))
          .toList();
    }

    return DiscoverSearchResult(
      users: items('users', DiscoverUser.fromJson),
      challenges: items('challenges', Challenge.fromJson),
    );
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
  final List<DiscoverNerd> topNerds;
  final List<DiscoverActivity> recentActivity;

  const DiscoverFeed({
    this.featured,
    this.trending = const [],
    this.categories = const [],
    this.newChallenges = const [],
    this.recommended = const [],
    this.legendary = const [],
    this.unexpected = const [],
    this.topNerds = const [],
    this.recentActivity = const [],
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

    List<T> items<T>(String key, T Function(Map<String, dynamic>) parse) {
      final value = json[key];
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((item) => parse(Map<String, dynamic>.from(item)))
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
      topNerds: items('top_nerds', DiscoverNerd.fromJson),
      recentActivity: items('recent_activity', DiscoverActivity.fromJson),
    );
  }
}
