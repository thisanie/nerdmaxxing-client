import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdmaxxing_client/models/evidence_submission.dart';
import 'package:nerdmaxxing_client/models/notification.dart';
import 'package:nerdmaxxing_client/widgets/achievement_card.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('resolveTheme', () {
    test('uses the requested rank palette', () {
      final theme = resolveTheme(rank: 'E');

      expect(theme.background, const Color(0xFF04060C));
      expect(theme.text, const Color(0xFFF5F5F0));
      expect(theme.muted, const Color(0xFF8B90A3));
      expect(theme.accent, const Color(0xFFFF4D6D));
      expect(theme.title, const Color(0xFFFFE08A));
    });

    test('inverts the S rank palette', () {
      final theme = resolveTheme(rank: 'S');

      expect(theme.background, const Color(0xFFC6FF00));
      expect(theme.text, const Color(0xFF04060C));
      expect(theme.muted, const Color.fromARGB(158, 4, 6, 12));
      expect(theme.accent, const Color(0xFF04060C));
      expect(theme.title, const Color(0xFF04060C));
    });

    test('uses dark or light fill override rules', () {
      final light = resolveTheme(rank: 'E', fill: const Color(0xFFC6FF00));
      final dark = resolveTheme(rank: 'E', fill: const Color(0xFF04060C));

      expect(light.background, const Color(0xFFC6FF00));
      expect(light.text, const Color(0xFF04060C));
      expect(light.accent, const Color(0xFF04060C));
      expect(light.title, const Color(0xFF04060C));
      expect(dark.text, const Color(0xFFF5F5F0));
      expect(dark.muted, const Color(0xFFA9AEC0));
      expect(dark.accent, const Color(0xFFFF4D6D));
      expect(dark.title, const Color(0xFFFFE08A));
    });
  });

  test('evidence approval parses backend aura_rewarded and day_streak keys', () {
    final submission = EvidenceSubmission.fromJson({
      'id': 'submission-1',
      'status': 'VERIFIED',
      'aura_rewarded': 150,
      'day_streak': 4,
    });

    expect(submission.auraAwarded, 150);
    expect(submission.dayStreak, 4);
  });

  test('evidence approval accepts the previous aura_awarded key', () {
    final submission = EvidenceSubmission.fromJson({
      'id': 'submission-1',
      'status': 'VERIFIED',
      'aura_awarded': 120,
      'day_streak': 3,
    });

    expect(submission.auraAwarded, 120);
    expect(submission.dayStreak, 3);
  });

  test('evidence approval accepts the previous aura_rewared typo', () {
    final submission = EvidenceSubmission.fromJson({
      'id': 'submission-1',
      'status': 'VERIFIED',
      'aura_rewared': 80,
      'day_streak': 2,
    });

    expect(submission.auraAwarded, 80);
    expect(submission.dayStreak, 2);
  });

  test('evidence notification extracts submission reward data', () {
    final notification = AppNotification.fromJson({
      'id': 'notification-1',
      'type': 'EVIDENCE_APPROVED',
      'body': 'Your challenge evidence was approved.',
      'is_read': false,
      'data': {
        'submission_id': 'submission-1',
        'challenge_title': 'Hold a handstand',
        'aura_rewarded': 150,
        'day_streak': 4,
      },
    });

    expect(notification.isEvidenceApproved, isTrue);
    expect(notification.evidenceSubmissionId, 'submission-1');
    expect(notification.data['aura_rewarded'], 150);
    expect(notification.data['day_streak'], 4);
  });

  testWidgets('renders long titles and usernames without layout errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: AchievementCard(
                type: CardType.challenge,
                title: 'Solve a Rubik’s Cube blindfolded without peeking',
                rank: 'A',
                aura: 500,
                username: 'a_really_long_username_that_keeps_going',
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('quest cards omit challenge-only content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: AchievementCard(
              type: CardType.quest,
              title: 'Learn 10 Spanish words',
              result: '30 sec',
              rank: 'S',
              aura: 40,
              username: 'aniket',
            ),
          ),
        ),
      ),
    );

    expect(find.text('personal best fr'), findsNothing);
    expect(find.text('locked in'), findsNothing);
    expect(find.text('S'), findsNothing);
  });

  testWidgets('exports the card as a PNG', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: AchievementCard(
                key: key,
                type: CardType.quest,
                title: 'Learn 10 Spanish words',
                aura: 40,
                username: 'aniket',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bytes = await exportCardPng(key);
    expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
  });
}