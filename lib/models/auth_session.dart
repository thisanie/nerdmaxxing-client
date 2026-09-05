class AuthSession {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String? username;
  final bool needsUsername;
  final bool isNewUser;
  final String? displayName;
  final String? avatarUrl;

  AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    this.username,
    required this.needsUsername,
    required this.isNewUser,
    this.displayName,
    this.avatarUrl,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
      userId: json['user_id']?.toString() ?? '',
      username: json['username'],
      needsUsername: json['needs_username'] ?? false,
      isNewUser: json['is_new_user'] ?? false,
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
    );
  }

  AuthSession copyWith({String? username, bool? needsUsername}) {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      username: username ?? this.username,
      needsUsername: needsUsername ?? this.needsUsername,
      isNewUser: isNewUser,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
  }
}
