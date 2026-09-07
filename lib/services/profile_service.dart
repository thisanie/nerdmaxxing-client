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

  Future<void> updateUsername(String username) async {
    await api.patch('/users/me/username', data: {'username': username});
  }

  Future<void> updateProfile({String? name, String? bio}) async {
    await api.patch('/users/me/profile', data: {'name': name, 'bio': bio});
  }

  Future<List<Challenge>> listMyCompletedChallenges() async {
    final data = await api.get('/users/me/challenges/completed');
    return (data as List).map((e) => Challenge.fromJson(e)).toList();
  }

  Future<List<Challenge>> listMyCreatedChallenges() async {
    final data = await api.get('/users/me/challenges/created');
    return (data as List).map((e) => Challenge.fromJson(e)).toList();
  }

  Future<List<Challenge>> listCompletedChallenges(String username) async {
    final data = await api.get('/users/$username/challenges/completed');
    return (data as List).map((e) => Challenge.fromJson(e)).toList();
  }

  Future<bool> isFollowing(String userId) async {
    final data = await api.get('/users/$userId/follow-status');
    if (data is bool) return data;
    if (data is Map) {
      final value = data['is_following'] ?? data['following'];
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
    }
    return false;
  }

  Future<List<UserSummary>> listFollowers(
    String userId, {
    int limit = 100,
    int offset = 0,
  }) async {
    final data = await api.get(
      '/users/$userId/followers',
      query: {'limit': limit, 'offset': offset},
    );
    return (data as List).map((e) => UserSummary.fromJson(e)).toList();
  }

  Future<List<UserSummary>> listFollowing(
    String userId, {
    int limit = 100,
    int offset = 0,
  }) async {
    final data = await api.get(
      '/users/$userId/following',
      query: {'limit': limit, 'offset': offset},
    );
    return (data as List).map((e) => UserSummary.fromJson(e)).toList();
  }

  Future<void> follow(String userId) async {
    await api.post('/users/$userId/follow');
  }

  Future<void> unfollow(String userId) async {
    await api.delete('/users/$userId/follow');
  }
}
