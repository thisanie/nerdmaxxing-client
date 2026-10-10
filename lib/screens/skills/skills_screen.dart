import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/leaderboard.dart';
import '../../models/user_stats.dart';
import '../../providers/app_state_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error.dart';
import '../profile/profile_screen.dart';

class SkillsScreen extends ConsumerWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(myStatsProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(myStatsProvider.future),
        child: stats.when(
          loading: () =>
              const _RefreshableState(child: CircularProgressIndicator()),
          error: (error, _) => _RefreshableState(
            child: AppErrorView(error: error, onRetry: () => ref.refresh(myStatsProvider.future)),
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
                      _LeaderboardTab(rank: value.rank),
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedForeground = isDark ? AppColors.dark : scheme.surface;
    final selectedBackground = isDark ? AppColors.primary : scheme.onSurface;
    return Container(
      height: 54,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(999),
      ),
      child: TabBar(
        tabs: const [
          Tab(text: 'Summary'),
          Tab(text: 'Leaderboard'),
        ],
        labelColor: selectedForeground,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicator: BoxDecoration(
          color: selectedBackground,
          borderRadius: BorderRadius.circular(999),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: AppFonts.body(color: selectedForeground, fontSize: 16),
        unselectedLabelStyle: AppFonts.body(
          color: scheme.onSurfaceVariant,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _RankSummary extends StatelessWidget {
  final UserStats stats;

  const _RankSummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _RankHeader(rank: stats.rank),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? AppColors.primaryMuted : AppColors.limeWash,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR PROGRESS',
                style: AppFonts.label(color: scheme.onSurface, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Text(
                'Build your rank one challenge at a time.',
                style: AppFonts.display(
                  color: scheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceAlt : scheme.onSurface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${stats.auraPoints}',
                    style: AppFonts.poster(
                      fontSize: 88,
                      color: scheme.onSurface,
                      wdth: 100,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AURA\nPOINTS',
                    style: AppFonts.label(
                      color: scheme.onSurface.withValues(alpha: .7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _RankLadder(stats: stats),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatTile(
              label: 'DAY STREAK',
              value: '${stats.dayStreak}',
              icon: Icons.local_fire_department_rounded,
            ),
            const SizedBox(width: 12),
            _StatTile(
              label: 'COMPLETED',
              value: '${stats.completedChallengeCount}',
              icon: Icons.task_alt_rounded,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatTile(
              label: 'ACTIVE',
              value: '${stats.activeChallengeCount}',
              icon: Icons.radio_button_checked_rounded,
              accent: true,
            ),
            const SizedBox(width: 12),
            _StatTile(
              label: 'RANK',
              value: stats.rank,
              icon: Icons.emoji_events_rounded,
              dark: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _RankHeader extends StatelessWidget {
  final String rank;

  const _RankHeader({required this.rank});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Rank', style: Theme.of(context).textTheme.headlineMedium),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurface,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Rank $rank',
            style: AppFonts.body(
              color: isDark ? AppColors.dark : AppColors.primary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _RankLadder extends StatelessWidget {
  final UserStats stats;

  const _RankLadder({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = Theme.of(context).brightness == Brightness.dark
        ? scheme.primary
        : AppColors.primary;
    const ranks = ['E', 'D', 'C', 'B', 'A', 'S'];
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rank ladder',
                style: AppFonts.body(
                  color: scheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                stats.nextRank == null
                    ? 'MAX RANK'
                    : '${stats.rankProgress}% to ${stats.nextRank}',
                style: AppFonts.body(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 20,
                  right: 20,
                  child: Container(height: 3, color: scheme.outline),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final rank in ranks)
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: rank == stats.rank ? accent : scheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: rank == stats.rank
                                ? scheme.onSurface
                                : scheme.outline,
                            width: rank == stats.rank ? 2 : 1.5,
                          ),
                        ),
                        child: Text(
                          rank,
                          style: AppFonts.body(
                            color: rank == stats.rank
                                ? AppColors.dark
                                : scheme.onSurfaceVariant,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            stats.nextRank == null
                ? 'Maximum aura reached'
                : '${stats.auraToNextRank} aura to ${stats.nextRank} rank',
            style: AppFonts.body(color: scheme.onSurfaceVariant, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

enum _LeaderboardMetric { aura, completed, streak }

class _LeaderboardTab extends ConsumerStatefulWidget {
  final String rank;

  const _LeaderboardTab({required this.rank});

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
      leaderboardProvider((
        period: _apiPeriod,
        metric: _metric.name,
        playerRank: _playerRank,
      )),
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _RankHeader(rank: widget.rank),
        const SizedBox(height: 20),
        Text(
          'THE RANKS',
          style: AppFonts.label(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'See who is putting in the work.',
          style: AppFonts.display(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.05,
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
                  child: Center(
                    child: Text('No players found for these filters.'),
                  ),
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? AppColors.limeWash
                : AppColors.primaryMuted,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FilterLabel('TIME PERIOD'),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final option in [
                      'THIS WEEK',
                      'THIS MONTH',
                      'ALL TIME',
                    ]) ...[
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
                      onTap: () =>
                          onMetricChanged(_LeaderboardMetric.completed),
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
    style: AppFonts.label(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 10,
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBackground = isDark ? AppColors.primary : scheme.onSurface;
    final selectedForeground = isDark ? AppColors.dark : scheme.surface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? selectedBackground : scheme.surface,
          border: Border.all(
            color: selected ? selectedBackground : scheme.outline,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppFonts.body(
            color: selected ? selectedForeground : scheme.onSurfaceVariant,
            fontSize: 14,
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
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
          style: AppFonts.label(
            color: muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: AppFonts.label(
            color: muted,
            fontSize: 13,
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

  const _LeaderboardRow({required this.entry, required this.metric});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? scheme.primary : AppColors.primary;
    final currentUserBackground = isDark ? AppColors.primary : scheme.onSurface;
    final currentUserForeground = isDark ? AppColors.dark : scheme.surface;
    final displayName = entry.displayName ?? entry.username ?? 'Unknown player';
    final username = entry.username;
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
        color: entry.isCurrentUser ? currentUserBackground : scheme.surface,
        border: Border.all(
          color: entry.isCurrentUser ? currentUserBackground : scheme.outline,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: InkWell(
        onTap: username == null || username.isEmpty
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(username: username),
                ),
              ),
        borderRadius: BorderRadius.circular(26),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                entry.rank.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: entry.isCurrentUser
                      ? currentUserForeground
                      : scheme.onSurfaceVariant,
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
                  color: entry.rank == 1 ? accent : scheme.outline,
                ),
              ),
              child: Text(
                initials,
                style: AppFonts.body(
                  color: entry.isCurrentUser
                      ? currentUserForeground
                      : scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: AppFonts.body(
                      color: entry.isCurrentUser
                          ? currentUserForeground
                          : scheme.onSurface,
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$handle  ·  ${entry.playerRank} RANK',
                    style: AppFonts.body(
                      color: entry.isCurrentUser
                          ? currentUserForeground.withValues(alpha: .7)
                          : scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${entry.metricValue}$suffix',
              style: AppFonts.body(
                color: entry.isCurrentUser
                    ? currentUserForeground
                    : scheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool accent;
  final bool dark;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = false,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).brightness == Brightness.dark
        ? scheme.primary
        : AppColors.primary;
    final background = dark
        ? (isDarkTheme ? AppColors.surfaceAlt : scheme.onSurface)
        : accent
        ? accentColor
        : scheme.surface;
    final foreground = dark
        ? accentColor
        : accent
        ? AppColors.dark
        : scheme.onSurface;
    return Expanded(
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: background,
          border: dark || accent
              ? null
              : Border.all(color: scheme.outline, width: 1.5),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground, size: 30),
            const Spacer(),
            Text(
              value,
              style: AppFonts.display(
                color: foreground,
                fontSize: 56,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppFonts.label(
                color: foreground.withValues(alpha: .7),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
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
