import 'package:flutter_test/flutter_test.dart';
import 'package:nerdmaxxing_client/models/user_stats.dart';

void main() {
  test('parses activity days from the stats response', () {
    final stats = UserStats.fromJson({
      'active_challenge_count': 1,
      'completed_challenge_count': 2,
      'day_streak': 3,
      'aura_points': 40,
      'activity_days': [
        {'date': '2026-11-09', 'active': false},
        {'date': '2026-11-10', 'active': true},
      ],
    });

    expect(stats.activityDays, hasLength(2));
    expect(stats.activityDays.first.date, '2026-11-09');
    expect(stats.activityDays.first.active, isFalse);
    expect(stats.activityDays.last.date, '2026-11-10');
    expect(stats.activityDays.last.active, isTrue);
  });
}