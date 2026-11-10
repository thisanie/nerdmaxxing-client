class UserActivityDay {
  final String date;
  final bool active;

  const UserActivityDay({required this.date, required this.active});

  factory UserActivityDay.fromJson(Map<String, dynamic> json) {
    return UserActivityDay(
      date: json['date'] as String? ?? '',
      active: json['active'] == true,
    );
  }
}

class UserStats {
  final int activeChallengeCount;
  final int completedChallengeCount;
  final int dayStreak;
  final int auraPoints;
  final String rank;
  final int rankProgress;
  final String? nextRank;
  final int auraToNextRank;
  final List<UserActivityDay> activityDays;

  const UserStats({
    required this.activeChallengeCount,
    required this.completedChallengeCount,
    required this.dayStreak,
    required this.auraPoints,
    required this.rank,
    required this.rankProgress,
    required this.nextRank,
    required this.auraToNextRank,
    this.activityDays = const [],
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    int readInt(String key) => (json[key] as num?)?.toInt() ?? 0;

    return UserStats(
      activeChallengeCount: readInt('active_challenge_count'),
      completedChallengeCount: readInt('completed_challenge_count'),
      dayStreak: readInt('day_streak'),
      auraPoints: readInt('aura_points'),
      rank: json['rank'] as String? ?? 'E',
      rankProgress: readInt('rank_progress'),
      nextRank: json['next_rank'] as String?,
      auraToNextRank: readInt('aura_to_next_rank'),
      activityDays: (json['activity_days'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => UserActivityDay.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
    );
  }
}
