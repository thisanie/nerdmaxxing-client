import '../models/challenge.dart';
import '../models/user_stats.dart';
import '../models/user_profile.dart';

import 'package:dio/dio.dart';

import 'api_client.dart';
import 'app_cache.dart';

class ProfileService {
  final ApiClient api;
  ProfileService(this.api);

  Future<UserProfile> getProfile(String username) async {
    final data = await api.get('/users/$username');
    await AppCache.write('profile_$username', data);
    return UserProfile.fromJson(data);
  }

  Future<UserProfile?> getCachedProfile(String username) async {
    final data = await AppCache.read('profile_$username');
    return data is Map
        ? UserProfile.fromJson(Map<String, dynamic>.from(data))
        : null;
  }

  Future<UserStats> getMyStats() async {
    final data = await api.get('/users/me/stats');
    await AppCache.write('my_stats', data);
    return UserStats.fromJson(data);
  }

  Future<UserStats?> getCachedMyStats() async {
    final data = await AppCache.read('my_stats');
    return data is Map
        ? UserStats.fromJson(Map<String, dynamic>.from(data))
        : null;
  }

  Future<void> updateUsername(String username) async {
    await api.patch('/users/me/username', data: {'username': username});
  }

  Future<UserProfile> updateProfile({
    String? name,
    String? bio,
    MultipartFile? avatar,
  }) async {
    final data = await api.patch(
      '/users/me/profile',
      data: FormData.fromMap({'name': name, 'bio': bio, 'avatar': ?avatar}),
    );
    return UserProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Challenge>> listMyCompletedChallenges() async {
    final data = await api.get('/users/me/challenges/completed');
    await AppCache.write('my_completed_challenges', data);
    return (data as List).map((e) => Challenge.fromJson(e)).toList();
  }

  Future<List<Challenge>?> getCachedMyCompletedChallenges() async {
    final data = await AppCache.read('my_completed_challenges');
    return data is List
        ? data
              .whereType<Map>()
              .map((item) => Challenge.fromJson(Map<String, dynamic>.from(item)))
              .toList()
        : null;
  }

  Future<List<Challenge>> listMyCreatedChallenges() async {
    final data = await api.get('/users/me/challenges/created');
    await AppCache.write('my_created_challenges', data);
    return (data as List).map((e) => Challenge.fromJson(e)).toList();
  }

  Future<List<Challenge>?> getCachedMyCreatedChallenges() async {
    final data = await AppCache.read('my_created_challenges');
    return data is List
        ? data
              .whereType<Map>()
              .map((item) => Challenge.fromJson(Map<String, dynamic>.from(item)))
              .toList()
        : null;
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
