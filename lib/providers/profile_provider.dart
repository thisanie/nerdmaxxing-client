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
      final loadedProfile = await service.getProfile(username);
      final following = isOwnProfile
          ? loadedProfile.isFollowing
          : await service.isFollowing(loadedProfile.id);
      profile = loadedProfile.copyWith(isFollowing: following);
      completedChallenges = isOwnProfile
          ? await service.listMyCompletedChallenges()
          : await service.listCompletedChallenges(username);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFollow() async {
    final current = profile;
    if (current == null || isOwnProfile) return;

    if (current.isFollowing) {
      await service.unfollow(current.id);
    } else {
      await service.follow(current.id);
    }
    profile = current.copyWith(
      isFollowing: !current.isFollowing,
      followerCount: current.followerCount + (current.isFollowing ? -1 : 1),
    );
    notifyListeners();
  }
}
