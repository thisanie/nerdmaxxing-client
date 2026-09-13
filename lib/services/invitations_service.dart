import 'api_client.dart';

class InviteLink {
  final String url;
  final String inviterId;
  final String inviterUsername;
  final String challengeId;
  final DateTime? expiresAt;

  InviteLink({
    required this.url,
    required this.inviterId,
    required this.inviterUsername,
    required this.challengeId,
    this.expiresAt,
  });

  factory InviteLink.fromJson(Map<String, dynamic> json) {
    return InviteLink(
      url: json['url']?.toString() ?? '',
      inviterId: json['inviter_id']?.toString() ?? '',
      inviterUsername: json['inviter_username']?.toString() ?? '',
      challengeId: json['challenge_id']?.toString() ?? '',
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.tryParse(json['expires_at'].toString()),
    );
  }
}

class InvitationsService {
  final ApiClient api;
  InvitationsService(this.api);

  Future<void> inviteFollower(
    String challengeSlug, {
    required String inviteeId,
  }) async {
    await api.post(
      '/challenges/$challengeSlug/invitations',
      data: {'invitee_id': inviteeId},
    );
  }

  Future<InviteLink> createInviteLink(String challengeSlug) async {
    final data = await api.post('/challenges/$challengeSlug/invite-link');
    return InviteLink.fromJson(data);
  }
}