import 'package:flutter/material.dart';

import '../widgets/achievement_card.dart';

class AchievementCardDemoScreen extends StatelessWidget {
  const AchievementCardDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Achievement cards')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: const [
          _DemoCardSection(
            label: 'CHALLENGE',
            card: AchievementCard(
              type: CardType.challenge,
              title: 'Hold a handstand',
              result: '30 sec',
              rank: 'B',
              aura: 150,
              username: 'aniket',
            ),
          ),
          SizedBox(height: 28),
          _DemoCardSection(
            label: 'DAILY QUEST',
            card: AchievementCard(
              type: CardType.quest,
              title: 'Learn 10 Spanish words',
              aura: 40,
              username: 'aniket',
            ),
          ),
          SizedBox(height: 28),
          _DemoCardSection(
            label: 'LONG TITLE',
            card: AchievementCard(
              type: CardType.challenge,
              title: 'Solve a Rubik’s Cube blindfolded without peeking',
              rank: 'A',
              aura: 500,
              username: 'a_really_long_username_that_keeps_going',
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoCardSection extends StatelessWidget {
  final String label;
  final Widget card;

  const _DemoCardSection({required this.label, required this.card});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        card,
      ],
    );
  }
}