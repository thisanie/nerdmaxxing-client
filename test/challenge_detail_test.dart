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

  test('parses provider, evidence rules, completion, and verification state', () {
    final detail = ChallengeDetail.fromJson({
      'challenge': {
        'id': 'chess-rated-game',
        'title': 'Complete a rated game',
        'resources': [],
        'slug': 'chess-rated-game',
        'short_description': 'Play one rated game.',
        'full_description': '',
        'creator_id': 'creator',
        'difficulty_level': 'BEGINNER',
        'aura_points': 20,
        'status': 'PUBLISHED',
        'visibility': 'PUBLIC',
        'verification_type': 'EXTERNAL_ACCOUNT',
      },
      'verification': {
        'type': 'EXTERNAL_ACCOUNT',
        'kind': 'EXTERNAL_ACCOUNT',
        'instructions': 'Connect your account.',
        'required_runs': 1,
        'provider': {
          'id': 'chess_com',
          'name': 'Chess.com',
          'connect_url': 'https://example.test/connect',
          'connected': true,
          'account': {
            'provider_user_id': 'player-1',
            'username': 'demo_player',
            'verified_at': '2026-10-08T12:00:00Z',
          },
        },
        'evidence': {
          'allowed_types': ['ACCOUNT_CONNECTION'],
          'requires_file': false,
          'requires_explanation': false,
        },
        'completion': {
          'mode': 'AUTOMATIC',
          'requires_review': false,
        },
      },
      'verification_state': {
        'status': 'READY',
        'can_retry': false,
      },
    });

    expect(detail.verification.kind, 'EXTERNAL_ACCOUNT');
    expect(detail.verification.provider?.account?.username, 'demo_player');
    expect(detail.verification.evidence.requiresFile, isFalse);
    expect(detail.verification.completion.mode, 'AUTOMATIC');
    expect(detail.verificationState.status, 'READY');
  });

  test('uses challenge verification type when nested verification is absent', () {
    final detail = ChallengeDetail.fromJson({
      'challenge': {
        'id': 'handstand',
        'title': 'Handstand',
        'resources': [],
        'slug': 'handstand',
        'short_description': 'Hold a handstand.',
        'full_description': '',
        'creator_id': 'creator',
        'difficulty_level': 'BEGINNER',
        'aura_points': 20,
        'status': 'PUBLISHED',
        'visibility': 'PUBLIC',
        'verification_type': 'VIDEO_VERIFIED',
      },
      'verification': null,
    });

    expect(detail.verification.type, 'VIDEO_VERIFIED');
    expect(detail.verification.kind, 'VIDEO_VERIFIED');
  });
}
