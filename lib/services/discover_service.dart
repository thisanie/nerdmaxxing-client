import '../models/discover.dart';
import 'api_client.dart';

class DiscoverService {
  final ApiClient api;
  DiscoverService(this.api);

  Future<DiscoverFeed> getFeed() async {
    final data = await api.get('/discover');
    return DiscoverFeed.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
