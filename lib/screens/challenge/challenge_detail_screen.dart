import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/challenge.dart';
import '../../models/participation.dart';
import '../../providers/participation_provider.dart';
import '../../services/api_client.dart';
import '../../services/challenges_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/difficulty_badge.dart';
import '../evidence/submit_evidence_screen.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final String slug;
  final Challenge? initialChallenge;

  const ChallengeDetailScreen({
    super.key,
    required this.slug,
    this.initialChallenge,
  });

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  Challenge? _challenge;
  String? _error;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _challenge = widget.initialChallenge;
    if (_challenge == null) _load();
  }

  Future<void> _load() async {
    try {
      final challenge = await context.read<ChallengesService>().getBySlug(
        widget.slug,
      );
      if (!mounted) return;
      setState(() => _challenge = challenge);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await context.read<ParticipationProvider>().accept(widget.slug);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Challenge accepted. Ready when you are.'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ),
      );
    }
    if (_challenge == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final challenge = _challenge!;
    final participation = context.watch<ParticipationProvider>().forChallenge(
      challenge.id,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: challenge.imageUrl != null
                  ? Image.network(
                      challenge.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: AppColors.surfaceAlt),
                    )
                  : Container(color: AppColors.surfaceAlt),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    challenge.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      DifficultyBadge(level: challenge.difficultyLevel),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.schedule,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        challenge.effortLabel,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    challenge.shortDescription,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  _actionButton(participation),
                  const SizedBox(height: 32),
                  Text(
                    'What you will do',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    challenge.fullDescription,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (challenge.resources.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Text(
                      'Resources',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    ...challenge.resources.map(
                      (r) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                r.rationale,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Text(
                    'Verification',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    challenge.verificationType == 'SELF_REPORTED'
                        ? 'You\'ll confirm you completed this yourself.'
                        : 'This challenge requires verification of your evidence.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(Participation? participation) {
    if (participation == null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _accepting ? null : _accept,
          child: Text(_accepting ? 'Accepting...' : 'Accept Challenge'),
        ),
      );
    }
    final status = participation.status;
    if (status == 'ACCEPTED' || status == 'IN_PROGRESS' || status == 'PAUSED') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  SubmitEvidenceScreen(participation: participation),
            ),
          ),
          child: const Text('Submit Evidence'),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success),
          const SizedBox(width: 8),
          Text('Status: ${status.toString().toLowerCase()}'),
        ],
      ),
    );
  }
}
