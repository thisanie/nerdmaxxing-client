import 'user_profile.dart';

class DiscussionComment {
  final String id;
  final String? challengeId;
  final String body;
  final String type;
  final UserSummary author;
  final int replyCount;
  final bool resolved;
  final bool deleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DiscussionComment({
    required this.id,
    this.challengeId,
    required this.body,
    required this.type,
    required this.author,
    required this.replyCount,
    required this.resolved,
    required this.deleted,
    this.createdAt,
    this.updatedAt,
  });

  factory DiscussionComment.fromJson(Map<String, dynamic> json) {
    final rawAuthor = json['author'] ?? json['user'];
    final author = rawAuthor is Map
        ? UserSummary.fromJson(Map<String, dynamic>.from(rawAuthor))
        : UserSummary(
            id:
                json['author_id']?.toString() ??
                json['user_id']?.toString() ??
                '',
            username:
                json['author_username']?.toString() ??
                json['username']?.toString(),
            name:
                json['author_name']?.toString() ??
                json['display_name']?.toString(),
            avatarUrl:
                json['author_avatar_url']?.toString() ??
                json['avatar_url']?.toString(),
          );
    return DiscussionComment(
      id: json['id']?.toString() ?? '',
      challengeId: json['challenge_id']?.toString(),
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? 'COMMENT',
      author: author,
      replyCount: (json['reply_count'] as num?)?.toInt() ?? 0,
      resolved: json['is_resolved'] == true || json['resolved'] == true,
      deleted: json['is_deleted'] == true || json['deleted'] == true,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  DiscussionComment copyWith({String? body, bool? resolved, bool? deleted}) {
    return DiscussionComment(
      id: id,
      challengeId: challengeId,
      body: body ?? this.body,
      type: type,
      author: author,
      replyCount: replyCount,
      resolved: resolved ?? this.resolved,
      deleted: deleted ?? this.deleted,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());
}

class DiscussionPage {
  final List<DiscussionComment> items;
  final String? nextCursor;

  const DiscussionPage({required this.items, this.nextCursor});
}
