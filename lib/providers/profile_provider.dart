import 'package:flutter/foundation.dart';

import '../models/challenge.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileService service;
  ProfileProvider(this.service);

  UserProfile? profile;
  List<Challenge> completedChallenges = [];
  bool isOwnProfile = false;
  bool isLoading = false;
  String? errorMessage;

  Future<void> load(String username, {bool isOwnProfile = false}) async {
    this.isOwnProfile = isOwnProfile;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      profile = await service.getProfile(username);
      completedChallenges = isOwnProfile
          ? await service.listMyCompletedChallenges()
          : [];
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
