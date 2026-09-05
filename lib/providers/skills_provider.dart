import 'package:flutter/foundation.dart';

import '../models/user_skill.dart';
import '../services/skills_service.dart';

class SkillsProvider extends ChangeNotifier {
  final SkillsService service;
  SkillsProvider(this.service);

  List<UserSkill> skills = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      skills = await service.listMine();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
