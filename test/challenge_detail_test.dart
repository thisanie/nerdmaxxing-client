import 'package:flutter_test/flutter_test.dart';
import 'package:nerdmaxxing_client/models/challenge_detail.dart';

void main() {
  test('parses generic metrics, requirements, and metric-map attempts', () {
    final detail = ChallengeDetail.fromJson({
      'challenge': {
        'id': 'run-10k',
        'title': 'Run 10 km',
        'resources': [],
        'slug': 'run-10-km',
        'short_description': 'Complete a 10 km run.',
        'full_description': 'Run the distance at your own pace.',
        'creator_id': 'creator',
        'difficulty_level': 'BEGINNER',
        'aura_points': 20,
        'status': 'PUBLISHED',
        'visibility': 'PUBLIC',
        'verification_type': 'SELF_REPORTED',
        'metrics': [
          {
            'key': 'distance',
            'label': 'Distance',
            'kind': 'DISTANCE',
            'unit': 'km',
            'target': 10,
            'baseline': 0,
            'direction': 'AT_LEAST',
            'is_primary': true,
            'format': 'DECIMAL_1',
          },
        ],
      },
      'metrics': [
        {
          'key': 'distance',
          'current': 6.4,
          'best': 8.2,
        },
      ],
      'requirements': [
        {
          'metric_key': 'distance',
          'operator': 'AT_LEAST',
          'value': 10,
          'unit': 'km',
          'label': 'Complete 10 km',
        },
      ],
      'attempts': [
        {
          'id': 'attempt-1',
          'metrics': {'distance': 6.4},
          'created_at': '2026-09-26T12:00:00Z',
        },
      ],
      'verification': {
        'type': 'SELF_REPORTED',
        'requirements': [
          {
            'metric_key': 'distance',
            'operator': 'AT_LEAST',
            'value': 10,
            'unit': 'km',
            'label': 'Complete 10 km',
          },
        ],
        'required_runs': 1,
        'instructions': 'Submit evidence of the completed run.',
      },
    });

    expect(detail.primaryMetric?.target, 10);
    expect(detail.primaryMetric?.current, 6.4);
    expect(detail.primaryMetric?.unit, 'km');
    expect(detail.effectiveRequirements.single.label, 'Complete 10 km');
    expect(detail.attempts.single.metrics['distance'], 6.4);
  });
}
