import '../models/discover.dart';
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
    final data = await api.get(
      '/discover/search',
      query: {
        'q': query,
        'type': type,
        'limit': limit,
        'offset': offset,
      },
    );
    return DiscoverSearchResult.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }
}
