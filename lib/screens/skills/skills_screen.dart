import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_stats.dart';
import '../../providers/app_state_providers.dart';
import '../../theme/app_theme.dart';

class SkillsScreen extends ConsumerWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(myStatsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Rank')),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(myStatsProvider.future),
        child: stats.when(
          loading: () => const _RefreshableState(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => _RefreshableState(
            child: Text(
              'Could not load your rank.\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
          data: (value) => _RankContent(stats: value),
        ),
      ),
    );
  }
}

class _RankContent extends StatelessWidget {
  final UserStats stats;

  const _RankContent({required this.stats});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        const Text(
          'YOUR PROGRESS',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Build your rank\none challenge at a time.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: .98,
              ),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.primaryMuted,
            border: Border.all(color: AppColors.primary.withValues(alpha: .35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.bolt, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                '${stats.auraPoints}',
                style: const TextStyle(
                  fontSize: 58,
                  height: .8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              const Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text(
                  'AURA POINTS',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _StatTile(label: 'DAY STREAK', value: '${stats.dayStreak}', icon: Icons.local_fire_department_outlined),
            const SizedBox(width: 12),
            _StatTile(label: 'COMPLETED', value: '${stats.completedChallengeCount}', icon: Icons.check_circle_outline),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatTile(label: 'ACTIVE', value: '${stats.activeChallengeCount}', icon: Icons.track_changes),
            const SizedBox(width: 12),
            _StatTile(label: 'LEVEL', value: _levelFor(stats.auraPoints), icon: Icons.workspace_premium_outlined),
          ],
        ),
      ],
    );
  }

  String _levelFor(int aura) {
    if (aura >= 1000) return 'LEGEND';
    if (aura >= 500) return 'ELITE';
    if (aura >= 100) return 'RISING';
    return 'ROOKIE';
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 14),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _RefreshableState extends StatelessWidget {
  final Widget child;

  const _RefreshableState({required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Center(child: child),
        ),
      ],
    );
  }
}
