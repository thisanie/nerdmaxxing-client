import '../models/group.dart';
import '../models/group_message.dart';
import 'api_client.dart';

class GroupsService {
  final ApiClient api;
  GroupsService(this.api);

  Future<List<Group>> listPublic({int limit = 20, int offset = 0}) async {
    final data = await api.get(
      '/groups',
      query: {'limit': limit, 'offset': offset},
    );
    return (data as List).map((e) => Group.fromJson(e)).toList();
  }

  Future<List<Group>> listMine() async {
    final data = await api.get('/groups/me');
    return (data as List).map((e) => Group.fromJson(e)).toList();
  }

  Future<Group> create({
    required String name,
    String? description,
    String visibility = 'PUBLIC',
  }) async {
    final data = await api.post(
      '/groups',
      data: {
        'name': name,
        'description': description,
        'visibility': visibility,
      },
    );
    return Group.fromJson(data);
  }

  Future<void> join(String groupId) async {
    await api.post('/groups/$groupId/join');
  }

  Future<void> leave(String groupId) async {
    await api.delete('/groups/$groupId/leave');
  }

  Future<List<GroupMessage>> listMessages(
    String groupId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await api.get(
      '/groups/$groupId/messages',
      query: {'limit': limit, 'offset': offset},
    );
    final rawItems = data is Map
        ? (data['messages'] ?? data['items'] ?? data['data'] ?? const [])
        : data;
    if (rawItems is! List) return const [];
    return rawItems
        .whereType<Map>()
        .map((item) => GroupMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<GroupMessage> createMessage(
    String groupId, {
    required String body,
  }) async {
    final data = await api.post(
      '/groups/$groupId/messages',
      data: {'body': body},
    );
    return GroupMessage.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
