class GroupMessageAuthor {
  final String id;
  final String? username;
  final String? name;
  final String? avatarUrl;

  const GroupMessageAuthor({
    required this.id,
    this.username,
    this.name,
    this.avatarUrl,
  });

  factory GroupMessageAuthor.fromJson(Map<String, dynamic> json) {
    return GroupMessageAuthor(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString(),
      name: json['name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
    );
  }

  String get displayName => name?.isNotEmpty == true
      ? name!
      : username?.isNotEmpty == true
      ? username!
      : 'Member';
}

class GroupMessage {
  final String id;
  final String groupId;
  final GroupMessageAuthor author;
  final String type;
  final String body;
  final DateTime? createdAt;
  final GroupChallengeInvitationPayload? challengeInvitation;

  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.author,
    this.type = 'TEXT',
    required this.body,
    this.createdAt,
    this.challengeInvitation,
  });

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    final rawAuthor = json['author'];
    return GroupMessage(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      author: rawAuthor is Map
          ? GroupMessageAuthor.fromJson(Map<String, dynamic>.from(rawAuthor))
          : const GroupMessageAuthor(id: ''),
      type: json['type']?.toString() ?? 'TEXT',
      body: json['body']?.toString() ?? '',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      challengeInvitation: json['challenge_invitation'] is Map
          ? GroupChallengeInvitationPayload.fromJson(
              Map<String, dynamic>.from(json['challenge_invitation'] as Map),
            )
          : null,
    );
  }
}

class GroupChallengeInvitationPayload {
  final String id;
  final String challengeId;
  final String challengeSlug;
  final String challengeTitle;
  final String status;
  final String myResponse;
  final GroupInvitationResponseCounts responseCounts;

  const GroupChallengeInvitationPayload({
    required this.id,
    required this.challengeId,
    required this.challengeSlug,
    required this.challengeTitle,
    required this.status,
    required this.myResponse,
    required this.responseCounts,
  });

  factory GroupChallengeInvitationPayload.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['response_counts'];
    return GroupChallengeInvitationPayload(
      id: json['id']?.toString() ?? '',
      challengeId: json['challenge_id']?.toString() ?? '',
      challengeSlug: json['challenge_slug']?.toString() ?? '',
      challengeTitle: json['challenge_title']?.toString() ?? 'Challenge',
      status: json['status']?.toString() ?? 'OPEN',
      myResponse: json['my_response']?.toString() ?? 'PENDING',
      responseCounts: rawCounts is Map
          ? GroupInvitationResponseCounts.fromJson(
              Map<String, dynamic>.from(rawCounts),
            )
          : const GroupInvitationResponseCounts(),
    );
  }

  bool get isPendingForCurrentUser =>
      myResponse.toUpperCase() == 'PENDING' && status.toUpperCase() == 'OPEN';
}

class GroupInvitationResponseCounts {
  final int pending;
  final int accepted;
  final int declined;

  const GroupInvitationResponseCounts({
    this.pending = 0,
    this.accepted = 0,
    this.declined = 0,
  });

  factory GroupInvitationResponseCounts.fromJson(Map<String, dynamic> json) {
    return GroupInvitationResponseCounts(
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      accepted: (json['accepted'] as num?)?.toInt() ?? 0,
      declined: (json['declined'] as num?)?.toInt() ?? 0,
    );
  }
}
