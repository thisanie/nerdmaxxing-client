class LeaderboardEntry {
  final int rank;
  final String userId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String playerRank;
  final int auraPoints;
  final int completedChallengeCount;
  final int dayStreak;
  final int metricValue;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.playerRank,
    required this.auraPoints,
    required this.completedChallengeCount,
    required this.dayStreak,
    required this.metricValue,
    required this.isCurrentUser,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    int readInt(String key) => (json[key] as num?)?.toInt() ?? 0;

    return LeaderboardEntry(
      rank: readInt('rank'),
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      playerRank: json['player_rank'] as String? ?? 'E',
      auraPoints: readInt('aura_points'),
      completedChallengeCount: readInt('completed_challenge_count'),
      dayStreak: readInt('day_streak'),
      metricValue: readInt('metric_value'),
      isCurrentUser: json['is_current_user'] as bool? ?? false,
    );
  }
}

class LeaderboardViewer {
  final int rank;
  final int metricValue;
  final String userId;

  const LeaderboardViewer({
    required this.rank,
    required this.metricValue,
    required this.userId,
  });

  factory LeaderboardViewer.fromJson(Map<String, dynamic> json) {
    return LeaderboardViewer(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      metricValue: (json['metric_value'] as num?)?.toInt() ?? 0,
      userId: json['user_id'] as String? ?? '',
    );
  }
}

class Leaderboard {
  final String period;
  final String metric;
  final List<LeaderboardEntry> entries;
  final LeaderboardViewer? viewer;
  final int total;

  const Leaderboard({
    required this.period,
    required this.metric,
    required this.entries,
    required this.viewer,
    required this.total,
  });

  factory Leaderboard.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? const [];
    final rawViewer = json['viewer'];
    return Leaderboard(
      period: json['period'] as String? ?? 'week',
      metric: json['metric'] as String? ?? 'aura',
      entries: rawEntries
          .whereType<Map<String, dynamic>>()
          .map(LeaderboardEntry.fromJson)
          .toList(),
      viewer: rawViewer is Map<String, dynamic>
          ? LeaderboardViewer.fromJson(rawViewer)
          : null,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}