import '../models/leaderboard.dart';
import 'api_client.dart';

class LeaderboardService {
  final ApiClient api;

  LeaderboardService(this.api);

  Future<Leaderboard> getLeaderboard({
    String period = 'week',
    String metric = 'aura',
    String? playerRank,
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await api.get(
      '/leaderboard',
      query: {
        'period': period,
        'metric': metric,
        if (playerRank != null) 'player_rank': playerRank,
        'limit': limit,
        'offset': offset,
      },
    );
    return Leaderboard.fromJson(data as Map<String, dynamic>);
  }
}