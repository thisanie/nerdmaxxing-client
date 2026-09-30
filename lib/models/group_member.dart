class GroupMember {
  final String id;
  final String? username;
  final String? name;
  final String? avatarUrl;
  final String? status;

  const GroupMember({
    required this.id,
    this.username,
    this.name,
    this.avatarUrl,
    this.status,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    final nested = json['user'] ?? json['member'] ?? json['profile'];
    final user = nested is Map
        ? Map<String, dynamic>.from(nested)
        : json;
    return GroupMember(
      id: (user['id'] ?? json['user_id'] ?? json['member_id'])?.toString() ?? '',
      username: (user['username'] ?? user['user_name'])?.toString(),
      name: (user['name'] ?? user['display_name'])?.toString(),
      avatarUrl: (user['avatar_url'] ?? user['avatar'])?.toString(),
      status: json['status']?.toString(),
    );
  }

  String get displayName => name?.isNotEmpty == true
      ? name!
      : username?.isNotEmpty == true
      ? username!
      : 'Member';
}