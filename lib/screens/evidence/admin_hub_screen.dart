import 'package:flutter/material.dart';

import 'admin_challenges_screen.dart';
import 'admin_daily_quests_screen.dart';
import 'admin_daily_quest_evidence_screen.dart';
import 'admin_evidence_screen.dart';

class AdminHubScreen extends StatelessWidget {
  const AdminHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destinations = [
      (
        icon: Icons.today_rounded,
        title: 'Daily Quests',
        subtitle: 'Create drafts and schedule the daily quest.',
        screen: const AdminDailyQuestsScreen(),
      ),
      (
        icon: Icons.rate_review_outlined,
        title: 'Daily Quest evidence',
        subtitle: 'Review submitted photos and videos.',
        screen: const AdminDailyQuestEvidenceScreen(),
      ),
      (
        icon: Icons.auto_awesome_outlined,
        title: 'Major Challenges',
        subtitle: 'Author long-term challenges and milestones.',
        screen: const AdminChallengesScreen(),
      ),
      (
        icon: Icons.fact_check_outlined,
        title: 'Evidence requests',
        subtitle: 'Review user submissions awaiting approval.',
        screen: const AdminEvidenceScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: destinations.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final destination = destinations[index];
          return Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              leading: Icon(
                destination.icon,
                color: theme.colorScheme.primary,
              ),
              title: Text(destination.title),
              subtitle: Text(destination.subtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => destination.screen,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}