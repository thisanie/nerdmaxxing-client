import '../models/user_skill.dart';
import 'api_client.dart';

class SkillsService {
  final ApiClient api;
  SkillsService(this.api);

  Future<List<UserSkill>> listMine() async {
    final data = await api.get('/skills/me');
    return (data as List).map((e) => UserSkill.fromJson(e)).toList();
  }
}
