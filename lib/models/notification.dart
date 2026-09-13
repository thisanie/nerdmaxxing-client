import 'dart:convert';

class AppNotification {
  final String id;
  final String type;
  final String body;
  final bool isRead;
  final DateTime? createdAt;
  final Map<String, dynamic> data;
  final String? invitationStatus;

  AppNotification({
    required this.id,
    required this.type,
    required this.body,
    required this.isRead,
    required this.createdAt,
    required this.data,
    this.invitationStatus,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawDataValue =
      json['data'] ?? json['metadata'] ?? json['payload'] ?? json['extra_data'];
    final rawData = rawDataValue is String
      ? _decodeMap(rawDataValue)
      : rawDataValue;
    final rawChallenge =
      json['challenge'] ?? (rawData is Map ? rawData['challenge'] : null);
    final rawActor =
      json['actor'] ?? (rawData is Map ? rawData['actor'] : null);
    final actorData = rawActor is Map
      ? rawActor.cast<String, dynamic>()
      : const <String, dynamic>{};
    final challengeData = rawChallenge is Map
        ? rawChallenge.cast<String, dynamic>()
        : const <String, dynamic>{};
    final mergedData = <String, dynamic>{
      if (rawData is Map) ...rawData.cast<String, dynamic>(),
      ...challengeData,
      ...actorData,
      if (actorData['id'] != null && json['actor_id'] == null)
        'actor_id': actorData['id'],
      if (actorData['username'] != null && json['actor_username'] == null)
        'actor_username': actorData['username'],
      if (actorData['name'] != null && json['actor_name'] == null)
        'actor_name': actorData['name'],
      if (json['invitation_id'] != null) 'invitation_id': json['invitation_id'],
      if (json['challenge_slug'] != null) 'challenge_slug': json['challenge_slug'],
      if (json['challenge_title'] != null) 'challenge_title': json['challenge_title'],
      if (json['challenge_id'] != null) 'challenge_id': json['challenge_id'],
      if (json['related_id'] != null) 'related_id': json['related_id'],
      if (json['entity_id'] != null) 'entity_id': json['entity_id'],
      if (json['resource_id'] != null) 'resource_id': json['resource_id'],
      if (json['target_id'] != null) 'target_id': json['target_id'],
      if (json['actor_id'] != null) 'actor_id': json['actor_id'],
      if (json['actor_username'] != null)
        'actor_username': json['actor_username'],
      if (json['actor_name'] != null) 'actor_name': json['actor_name'],
      if (json['invitation_status'] != null)
        'invitation_status': json['invitation_status'],
    };
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? json['notification_type']?.toString() ?? '',
      body: json['body']?.toString() ?? json['message']?.toString() ?? '',
      isRead: json['is_read'] == true || json['read_at'] != null,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      data: mergedData,
        invitationStatus:
          mergedData['invitation_status']?.toString() ??
          (mergedData['status']?.toString()),
    );
  }

  String? get invitationId =>
      _value('invitation_id') ??
      (_isInvitationType ? _value('related_id') : null);
  String? get challengeId =>
      _value('challenge_id') ??
      _value('resource_id') ??
      _value('target_id');
    String? get challengeSlug =>
      _value('challenge_slug') ??
      _value('challengeSlug') ??
      _value('slug');
  String? get challengeTitle => _value('challenge_title') ?? _value('title');
  String? get actorId => _value('actor_id');
  String? get actorUsername => _value('actor_username');
  String? get actorName =>
      _value('actor_name') ?? _value('name') ?? _value('actor_username');

  bool get isFollow {
    final values = [
      type,
      data['notification_type']?.toString(),
      data['event_type']?.toString(),
    ];
    return values.any((value) => value?.toUpperCase() == 'FOLLOW');
  }

  bool get isChallengeInvitation => _isInvitationType || invitationId != null;

  bool get _isInvitationType =>
      type.toUpperCase().contains('INVITATION') ||
      _value('notification_type')?.toUpperCase().contains('INVITATION') == true ||
      _value('event_type')?.toUpperCase().contains('INVITATION') == true ||
      _value('invitation_status') != null;

  bool get isPendingInvitation =>
      isChallengeInvitation &&
      invitationStatus?.toUpperCase() != 'ACCEPTED' &&
      invitationStatus?.toUpperCase() != 'DECLINED';

  AppNotification copyWith({bool? isRead, String? invitationStatus}) {
    return AppNotification(
      id: id,
      type: type,
      body: body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      data: data,
      invitationStatus: invitationStatus ?? this.invitationStatus,
    );
  }

  String? _value(String key) => data[key]?.toString();

  static Map<String, dynamic>? _decodeMap(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }
}