import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/challenge.dart';
import '../../services/api_client.dart';
import '../../services/challenges_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/challenge_card.dart';
import '../challenge/challenge_detail_screen.dart';

class CategoryChallengesScreen extends StatelessWidget {
  final String name;
  final String? slug;

  const CategoryChallengesScreen({
    super.key,
    required this.name,
    required this.slug,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: FutureBuilder<List<Challenge>>(
        future: context.read<ChallengesService>().list(category: slug),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'Could not load this skill right now.';
            return Center(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.danger),
              ),
            );
          }
          final challenges = snapshot.data ?? const <Challenge>[];
          if (challenges.isEmpty) {
            return const Center(
              child: Text('No challenges in this skill yet.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: challenges.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final challenge = challenges[index];
              return ChallengeCard(
                challenge: challenge,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChallengeDetailScreen(slug: challenge.slug),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
