import '../models/notification.dart';
import '../models/participation.dart';
import 'api_client.dart';

class NotificationsService {
  final ApiClient api;
  NotificationsService(this.api);

  Future<List<AppNotification>> list({
    bool unreadOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await api.get(
      '/users/me/notifications',
      query: {
        'unread_only': unreadOnly,
        'limit': limit,
        'offset': offset,
      },
    );
    return (data as List)
        .map((item) => AppNotification.fromJson(item))
        .toList();
  }

  Future<void> markRead(String notificationId) async {
    await api.patch('/notifications/$notificationId/read');
  }

  Future<Participation> acceptInvitation(String invitationId) async {
    final data = await api.post('/invitations/$invitationId/accept');
    return Participation.fromJson(data);
  }

  Future<void> declineInvitation(String invitationId) async {
    await api.post('/invitations/$invitationId/decline');
  }
}