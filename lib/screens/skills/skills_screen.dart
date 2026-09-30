import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/leaderboard.dart';
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
          data: (value) => DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const _RankTabs(),
                Expanded(
                  child: TabBarView(
                    children: [
                      _RankSummary(stats: value),
                      const _LeaderboardTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RankTabs extends StatelessWidget {
  const _RankTabs();

  @override
  Widget build(BuildContext context) {
    return TabBar(
      tabs: const [
        Tab(text: 'SUMMARY'),
        Tab(text: 'LEADERBOARD'),
      ],
      labelColor: Theme.of(context).colorScheme.onSurface,
      unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
      indicatorColor: AppColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Theme.of(context).colorScheme.outline,
    );
  }
}

class _RankSummary extends StatelessWidget {
  final UserStats stats;

  const _RankSummary({required this.stats});

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
        const SizedBox(height: 12),
        Text(
          stats.nextRank == null
              ? 'S RANK // MAXIMUM AURA'
              : '${stats.rank} RANK // ${stats.rankProgress}% TO ${stats.nextRank}',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 11,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (stats.nextRank != null) ...[
          const SizedBox(height: 5),
          Text(
            '${stats.auraToNextRank} aura to ${stats.nextRank} rank',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
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
            _StatTile(label: 'RANK', value: stats.rank, icon: Icons.workspace_premium_outlined),
          ],
        ),
      ],
    );
  }

}

enum _LeaderboardMetric { aura, completed, streak }

class _LeaderboardTab extends ConsumerStatefulWidget {
  const _LeaderboardTab();

  @override
  ConsumerState<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends ConsumerState<_LeaderboardTab> {
  _LeaderboardMetric _metric = _LeaderboardMetric.aura;
  String _period = 'THIS WEEK';
  String? _playerRank;

  @override
  Widget build(BuildContext context) {
    final leaderboard = ref.watch(
      leaderboardProvider(
        (
          period: _apiPeriod,
          metric: _metric.name,
          playerRank: _playerRank,
        ),
      ),
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const Text(
          'THE RANKS',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'See who is\nputting in the work.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: .98,
              ),
        ),
        const SizedBox(height: 24),
        _FilterStrip(
          period: _period,
          metric: _metric,
          onPeriodChanged: (period) => setState(() => _period = period),
          onMetricChanged: (metric) => setState(() => _metric = metric),
          playerRank: _playerRank,
          onPlayerRankChanged: (rank) => setState(() => _playerRank = rank),
        ),
        const SizedBox(height: 24),
        _LeaderboardHeader(metric: _metric, period: _period),
        const SizedBox(height: 10),
        leaderboard.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Text(
              'Could not load the leaderboard.\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
          data: (data) => data.entries.isEmpty
              ? const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Center(child: Text('No players found for these filters.')),
                )
              : Column(
                  children: [
                    for (final entry in data.entries)
                      _LeaderboardRow(entry: entry, metric: _metric),
                  ],
                ),
        ),
      ],
    );
  }

  String get _apiPeriod => switch (_period) {
        'THIS MONTH' => 'month',
        'ALL TIME' => 'all_time',
        _ => 'week',
      };
}

class _FilterStrip extends StatelessWidget {
  final String period;
  final _LeaderboardMetric metric;
  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<_LeaderboardMetric> onMetricChanged;
  final String? playerRank;
  final ValueChanged<String?> onPlayerRankChanged;

  const _FilterStrip({
    required this.period,
    required this.metric,
    required this.onPeriodChanged,
    required this.onMetricChanged,
    required this.playerRank,
    required this.onPlayerRankChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterLabel('TIME PERIOD'),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in ['THIS WEEK', 'THIS MONTH', 'ALL TIME']) ...[
                if (option != 'THIS WEEK') const SizedBox(width: 8),
                _FilterChip(
                  label: option,
                  selected: period == option,
                  onTap: () => onPeriodChanged(option),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _FilterLabel('RANK BY'),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'AURA',
                selected: metric == _LeaderboardMetric.aura,
                onTap: () => onMetricChanged(_LeaderboardMetric.aura),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'COMPLETED',
                selected: metric == _LeaderboardMetric.completed,
                onTap: () => onMetricChanged(_LeaderboardMetric.completed),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'STREAK',
                selected: metric == _LeaderboardMetric.streak,
                onTap: () => onMetricChanged(_LeaderboardMetric.streak),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _FilterLabel('PLAYER RANK'),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'ALL',
                selected: playerRank == null,
                onTap: () => onPlayerRankChanged(null),
              ),
              for (final rank in ['E', 'D', 'C', 'B', 'A', 'S']) ...[
                const SizedBox(width: 8),
                _FilterChip(
                  label: rank,
                  selected: playerRank == rank,
                  onTap: () => onPlayerRankChanged(rank),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterLabel extends StatelessWidget {
  final String text;

  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderStrong,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.dark : AppColors.textSecondary,
            fontSize: 10,
            letterSpacing: .8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _LeaderboardHeader extends StatelessWidget {
  final _LeaderboardMetric metric;
  final String period;

  const _LeaderboardHeader({required this.metric, required this.period});

  @override
  Widget build(BuildContext context) {
    final label = switch (metric) {
      _LeaderboardMetric.aura => 'AURA',
      _LeaderboardMetric.completed => 'DONE',
      _LeaderboardMetric.streak => 'DAYS',
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          period,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final _LeaderboardMetric metric;

  const _LeaderboardRow({
    required this.entry,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = entry.displayName ?? entry.username ?? 'Unknown player';
    final handle = entry.username == null ? '' : '@${entry.username}';
    final initials = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final suffix = switch (metric) {
      _LeaderboardMetric.aura => ' AP',
      _LeaderboardMetric.completed => '',
      _LeaderboardMetric.streak => 'd',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: entry.isCurrentUser ? AppColors.primaryMuted : AppColors.surface,
        border: Border.all(
          color: entry.isCurrentUser ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              entry.rank.toString().padLeft(2, '0'),
              style: TextStyle(
                color: entry.rank == 1 ? AppColors.primary : AppColors.textSecondary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: entry.rank == 1 ? AppColors.primary : AppColors.borderStrong,
              ),
            ),
            child: Text(
              initials,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '$handle  ·  ${entry.playerRank} RANK',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${entry.metricValue}$suffix',
            style: TextStyle(
              color: entry.isCurrentUser ? AppColors.primary : AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
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
