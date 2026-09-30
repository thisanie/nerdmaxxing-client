import '../models/discover.dart';
import '../models/challenge.dart';
import 'api_client.dart';

class DiscoverService {
  final ApiClient api;
  DiscoverService(this.api);

  Future<DiscoverFeed> getFeed() async {
    final data = await api.get('/discover');
    return DiscoverFeed.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<DiscoverSearchResult> search(
    String query, {
    String type = 'all',
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final data = await api.get(
        '/discover/search',
        query: {'q': query, 'type': type, 'limit': limit, 'offset': offset},
      );
      return DiscoverSearchResult.fromJson(
        Map<String, dynamic>.from(data as Map),
      );
    } on ApiException catch (error) {
      if (error.statusCode == null || error.statusCode! < 500) rethrow;
      return _searchFeed(await getFeed(), query);
    }
  }

  DiscoverSearchResult _searchFeed(DiscoverFeed feed, String query) {
    final needle = query.trim().toLowerCase();
    bool matches(String? value) =>
        value?.toLowerCase().contains(needle) == true;

    final users = <String, DiscoverUser>{};
    for (final nerd in feed.topNerds) {
      if (matches(nerd.username) || matches(nerd.displayName)) {
        users[nerd.userId] = DiscoverUser(
          id: nerd.userId,
          username: nerd.username,
          displayName: nerd.displayName,
          avatarUrl: nerd.avatarUrl,
        );
      }
    }

    final challenges = <String, Challenge>{};
    final candidates = [
      if (feed.featured != null) feed.featured!,
      ...feed.trending,
      ...feed.newChallenges,
      ...feed.recommended,
      ...feed.legendary,
      ...feed.unexpected,
    ];
    for (final challenge in candidates) {
      if (matches(challenge.title) ||
          matches(challenge.shortDescription) ||
          matches(challenge.fullDescription)) {
        challenges[challenge.id] = challenge;
      }
    }

    return DiscoverSearchResult(
      users: users.values.toList(),
      challenges: challenges.values.toList(),
    );
  }
}
