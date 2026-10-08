import '../models/user_skill.dart';
import 'api_client.dart';
import 'app_cache.dart';

class SkillsService {
  final ApiClient api;
  SkillsService(this.api);

  Future<List<UserSkill>> listMine() async {
    final data = await api.get('/skills/me');
    await AppCache.write('skills_mine', data);
    return (data as List).map((e) => UserSkill.fromJson(e)).toList();
  }

  Future<List<UserSkill>?> getCachedMine() async {
    final data = await AppCache.read('skills_mine');
    return data is List
        ? data
              .whereType<Map>()
              .map((item) => UserSkill.fromJson(Map<String, dynamic>.from(item)))
              .toList()
        : null;
  }
}
