class UserSkill {
  final String id;
  final String userId;
  final String sourceChallengeId;
  final String skillName;
  final String verificationStatus;
  final DateTime? earnedAt;

  UserSkill({
    required this.id,
    required this.userId,
    required this.sourceChallengeId,
    required this.skillName,
    required this.verificationStatus,
    this.earnedAt,
  });

  factory UserSkill.fromJson(Map<String, dynamic> json) {
    return UserSkill(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      sourceChallengeId: json['source_challenge_id']?.toString() ?? '',
      skillName: json['skill_name'] ?? '',
      verificationStatus: json['verification_status'] ?? 'VERIFIED',
      earnedAt: json['earned_at'] != null ? DateTime.tryParse(json['earned_at']) : null,
    );
  }
}
