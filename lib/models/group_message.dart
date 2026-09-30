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
  final String body;
  final DateTime? createdAt;

  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.author,
    required this.body,
    this.createdAt,
  });

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    final rawAuthor = json['author'];
    return GroupMessage(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      author: rawAuthor is Map
          ? GroupMessageAuthor.fromJson(Map<String, dynamic>.from(rawAuthor))
          : const GroupMessageAuthor(id: ''),
      body: json['body']?.toString() ?? '',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}