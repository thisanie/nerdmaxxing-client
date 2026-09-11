import '../models/group.dart';
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
}
