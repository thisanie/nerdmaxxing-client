import '../models/challenge.dart';
import '../models/user_profile.dart';
import 'api_client.dart';

class ProfileService {
  final ApiClient api;
  ProfileService(this.api);

  Future<UserProfile> getProfile(String username) async {
    final data = await api.get('/users/$username');
    return UserProfile.fromJson(data);
  }

  Future<List<Challenge>> listMyCompletedChallenges() async {
    final data = await api.get('/users/me/challenges/completed');
    return (data as List).map((e) => Challenge.fromJson(e)).toList();
  }
}
