import 'group.dart';

class ProfileSkill {
  final String id;
  final String name;
  final DateTime? unlockedAt;

  ProfileSkill({required this.id, required this.name, this.unlockedAt});

  factory ProfileSkill.fromJson(Map<String, dynamic> json) {
    return ProfileSkill(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.tryParse(json['unlocked_at'])
          : null,
    );
  }
}

class UserSummary {
  final String id;
  final String? username;
  final String? name;
  final String? avatarUrl;

  UserSummary({required this.id, this.username, this.name, this.avatarUrl});

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['id']?.toString() ?? '',
      username: json['username'],
      name: json['name'],
      avatarUrl: json['avatar_url'],
    );
  }
}

class UserProfile {
  final String id;
  final String? username;
  final String? name;
  final String? bio;
  final String? avatarUrl;
  final int auraPoints;
  final int followerCount;
  final int followingCount;
  final int skillsCount;
  final int completedChallengesCount;
  final int createdChallengesCount;
  final List<ProfileSkill> skills;
  final List<Group> groups;
  final bool isFollowing;

  UserProfile({
    required this.id,
    this.username,
    this.name,
    this.bio,
    this.avatarUrl,
    required this.auraPoints,
    required this.followerCount,
    required this.followingCount,
    required this.skillsCount,
    required this.completedChallengesCount,
    required this.createdChallengesCount,
    required this.skills,
    required this.groups,
    required this.isFollowing,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    int readInt(String key) => (json[key] as num?)?.toInt() ?? 0;

    return UserProfile(
      id: json['id']?.toString() ?? '',
      username: json['username'],
      name: json['name'],
      bio: json['bio'],
      avatarUrl: json['avatar_url'],
      auraPoints: readInt('aura_points'),
      followerCount: readInt('follower_count'),
      followingCount: readInt('following_count'),
      skillsCount: readInt('skills_count'),
      completedChallengesCount: readInt('completed_challenges_count'),
      createdChallengesCount: readInt('created_challenges_count'),
      skills: (json['skills'] as List? ?? [])
          .map((e) => ProfileSkill.fromJson(e))
          .toList(),
      groups: (json['groups'] as List? ?? [])
          .map((e) => Group.fromJson(e))
          .toList(),
      isFollowing: json['is_following'] ?? false,
    );
  }

  UserProfile copyWith({bool? isFollowing, int? followerCount}) {
    return UserProfile(
      id: id,
      username: username,
      name: name,
      bio: bio,
      avatarUrl: avatarUrl,
      auraPoints: auraPoints,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount,
      skillsCount: skillsCount,
      completedChallengesCount: completedChallengesCount,
      createdChallengesCount: createdChallengesCount,
      skills: skills,
      groups: groups,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}
