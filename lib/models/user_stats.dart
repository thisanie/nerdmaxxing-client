class UserStats {
  final int activeChallengeCount;
  final int completedChallengeCount;
  final int dayStreak;
  final int auraPoints;

  const UserStats({
    required this.activeChallengeCount,
    required this.completedChallengeCount,
    required this.dayStreak,
    required this.auraPoints,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    int readInt(String key) => (json[key] as num?)?.toInt() ?? 0;

    return UserStats(
      activeChallengeCount: readInt('active_challenge_count'),
      completedChallengeCount: readInt('completed_challenge_count'),
      dayStreak: readInt('day_streak'),
      auraPoints: readInt('aura_points'),
    );
  }
}
