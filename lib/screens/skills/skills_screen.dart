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
            child: AppErrorView(
              error: error,
              onRetry: () => ref.refresh(myStatsProvider.future),
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
    final selectedForeground = isDark ? AppColors.dark : AppColors.primary;
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

/*
            body: stats.when(
              loading: () => RefreshIndicator(
                onRefresh: refreshStats,
                child: const _RefreshableState(child: CircularProgressIndicator()),
              ),
              error: (error, _) => RefreshIndicator(
                onRefresh: refreshStats,
                child: _RefreshableState(
                  child: AppErrorView(error: error, onRetry: refreshStats),
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
                          _RankSummary(stats: value, onRefresh: refreshStats),
                          _LeaderboardTab(rank: value.rank),
                        ],
                      ),
                    ),
                  ],
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
              dividerColor: Colors.transparent,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            ),
          );
        }
      }

      class _RankSummary extends StatelessWidget {
        final UserStats stats;
        final Future<void> Function() onRefresh;

        const _RankSummary({required this.stats, required this.onRefresh});

        @override
        Widget build(BuildContext context) {
          final scheme = Theme.of(context).colorScheme;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
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
            ),
          );
        }
      }
*/

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
  String _period = 'ALL TIME';
  String? _playerRank;

  @override
  Widget build(BuildContext context) {
    final filters = (
      period: _apiPeriod,
      metric: _metric.name,
      playerRank: _playerRank,
    );
    final leaderboard = ref.watch(leaderboardProvider(filters));

    final periodLabel = switch (_period) {
      'THIS MONTH' => 'This month',
      'ALL TIME' => 'All time',
      _ => 'This week',
    };

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await ref.refresh(leaderboardProvider(filters).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _RankHeader(rank: widget.rank),
                const SizedBox(height: 4),
                Text(
                  'See who is putting in the work.',
                  style: AppFonts.body(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                _FilterStrip(
                  period: _period,
                  metric: _metric,
                  onPeriodChanged: (period) => setState(() => _period = period),
                  onMetricChanged: (metric) => setState(() => _metric = metric),
                  playerRank: _playerRank,
                  onPlayerRankChanged: (rank) =>
                      setState(() => _playerRank = rank),
                ),
                const SizedBox(height: 16),
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
                            _LeaderboardHeader(
                              metric: _metric,
                              period: periodLabel,
                            ),
                            const SizedBox(height: 4),
                            _LeaderboardPodium(
                              entries: data.entries.take(3).toList(),
                              metric: _metric,
                            ),
                            for (final entry in data.entries.skip(3))
                              _LeaderboardRow(
                                entry: entry,
                                metric: _metric,
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
        leaderboard.when(
          data: (data) => _ViewerPosition(
            leaderboard: data,
            fallbackRank: widget.rank,
            metric: _metric,
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
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
        _FilterRow(
          children: [
            for (final option in ['THIS WEEK', 'THIS MONTH', 'ALL TIME'])
              _FilterChip(
                label: switch (option) {
                  'THIS WEEK' => 'This week',
                  'THIS MONTH' => 'This month',
                  _ => 'All time',
                },
                selected: period == option,
                onTap: () => onPeriodChanged(option),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _FilterRow(
          children: [
            _FilterChip(
              label: 'Aura',
              selected: metric == _LeaderboardMetric.aura,
              emphasized: true,
              onTap: () => onMetricChanged(_LeaderboardMetric.aura),
            ),
            _FilterChip(
              label: 'Completed',
              selected: metric == _LeaderboardMetric.completed,
              emphasized: true,
              onTap: () => onMetricChanged(_LeaderboardMetric.completed),
            ),
            _FilterChip(
              label: 'Streak',
              selected: metric == _LeaderboardMetric.streak,
              emphasized: true,
              onTap: () => onMetricChanged(_LeaderboardMetric.streak),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _FilterRow(
          children: [
            _FilterChip(
              label: 'All',
              selected: playerRank == null,
              onTap: () => onPlayerRankChanged(null),
            ),
            for (final rank in ['E', 'D', 'C', 'B', 'A', 'S'])
              _FilterChip(
                label: rank,
                selected: playerRank == rank,
                onTap: () => onPlayerRankChanged(rank),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  final List<Widget> children;

  const _FilterRow({required this.children});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: _spaceChildren(children)),
  );

  List<Widget> _spaceChildren(List<Widget> children) => [
    for (var index = 0; index < children.length; index++) ...[
      if (index > 0) const SizedBox(width: 8),
      children[index],
    ],
  ];
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool emphasized;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final selectedBackground = emphasized
        ? (isDark ? HomePalette.primary : HomePalette.ink)
        : HomePalette.primaryMuted(brightness);
    final selectedForeground = emphasized
        ? (isDark ? HomePalette.ink : HomePalette.primary)
        : (isDark ? HomePalette.primary : HomePalette.lightLink);
    final background = selected ? selectedBackground : scheme.surface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(
            color: selected ? background : scheme.outline,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppFonts.body(
            color: selected ? selectedForeground : scheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
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

String _leaderboardMetricSuffix(_LeaderboardMetric metric) => switch (metric) {
  _LeaderboardMetric.aura => ' AP',
  _LeaderboardMetric.completed => '',
  _LeaderboardMetric.streak => 'd',
};

String _leaderboardDisplayName(LeaderboardEntry entry) {
  final displayName = entry.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;
  final username = entry.username?.trim();
  return username == null || username.isEmpty ? 'Unknown player' : username;
}

String _leaderboardInitials(String name) {
  final initials = name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
  return initials.isEmpty ? '?' : initials;
}

void _openLeaderboardProfile(BuildContext context, LeaderboardEntry entry) {
  final username = entry.username;
  if (username == null || username.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ProfileScreen(username: username)),
  );
}

class _LeaderboardPodium extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final _LeaderboardMetric metric;

  const _LeaderboardPodium({required this.entries, required this.metric});

  @override
  Widget build(BuildContext context) {
    final visualOrder = entries.length == 3
        ? [entries[1], entries[0], entries[2]]
        : entries;
    return SizedBox(
      height: 198,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final entry in visualOrder)
            Expanded(child: _PodiumPlayer(entry: entry, metric: metric)),
        ],
      ),
    );
  }
}

class _PodiumPlayer extends StatelessWidget {
  final LeaderboardEntry entry;
  final _LeaderboardMetric metric;

  const _PodiumPlayer({required this.entry, required this.metric});

  @override
  Widget build(BuildContext context) {
    final isWinner = entry.rank == 1;
    final name = _leaderboardDisplayName(entry);
    final blockColor = switch (entry.rank) {
      1 => HomePalette.primary,
      2 => HomePalette.mint,
      _ => HomePalette.peach,
    };
    final blockHeight = switch (entry.rank) {
      1 => 58.0,
      2 => 42.0,
      _ => 32.0,
    };
    return InkWell(
      onTap: () => _openLeaderboardProfile(context, entry),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LeaderboardAvatar(
              imageUrl: entry.avatarUrl,
              name: name,
              size: isWinner ? 66 : 52,
              winner: isWinner,
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.body(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${entry.metricValue}${_leaderboardMetricSuffix(metric)}',
              style: AppFonts.body(
                color: isWinner
                    ? HomePalette.link(Theme.of(context).brightness)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              height: blockHeight,
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '${entry.rank}',
                style: AppFonts.body(
                  color: HomePalette.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool winner;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const _LeaderboardAvatar({
    required this.imageUrl,
    required this.name,
    required this.size,
    this.winner = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final url = imageUrl?.trim();
    final initials = _leaderboardInitials(name);
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? HomePalette.surfaceAlt(brightness),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: AppFonts.body(
            color: foregroundColor ?? scheme.onSurface,
            fontSize: size * 0.32,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    final child = url == null || url.isEmpty
        ? fallback
        : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(winner ? 2 : 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: winner ? HomePalette.primary : scheme.outline,
        ),
      ),
      child: ClipOval(child: child),
    );
  }
}

class _PlayerRankTag extends StatelessWidget {
  final String rank;

  const _PlayerRankTag({required this.rank});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: HomePalette.primaryMuted(brightness),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        rank,
        style: AppFonts.body(
          color: HomePalette.link(brightness),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ViewerPosition extends StatelessWidget {
  final Leaderboard leaderboard;
  final String fallbackRank;
  final _LeaderboardMetric metric;

  const _ViewerPosition({
    required this.leaderboard,
    required this.fallbackRank,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    final viewer = leaderboard.viewer;
    LeaderboardEntry? currentEntry;
    for (final entry in leaderboard.entries) {
      if (entry.isCurrentUser ||
          (viewer != null &&
              viewer.userId.isNotEmpty &&
              entry.userId == viewer.userId)) {
        currentEntry = entry;
        break;
      }
    }
    if (viewer == null && currentEntry == null) {
      return const SizedBox.shrink();
    }

    final brightness = Theme.of(context).brightness;
    final background = brightness == Brightness.dark
        ? HomePalette.primary
        : HomePalette.ink;
    final foreground = brightness == Brightness.dark
        ? HomePalette.ink
        : HomePalette.primary;
    final displayName = currentEntry == null
        ? 'You'
        : _leaderboardDisplayName(currentEntry);
    final username = currentEntry?.username;
    final playerRank = currentEntry?.playerRank ?? fallbackRank;
    final viewerRank = currentEntry?.rank ?? viewer?.rank ?? 0;
    final value = currentEntry?.metricValue ?? viewer?.metricValue ?? 0;
    final initials = _leaderboardInitials(displayName);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          if (currentEntry == null)
            CircleAvatar(
              radius: 18,
              backgroundColor: foreground,
              child: Text(
                initials,
                style: AppFonts.body(
                  color: background,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            _LeaderboardAvatar(
              imageUrl: currentEntry.avatarUrl,
              name: displayName,
              size: 36,
              backgroundColor: foreground,
              foregroundColor: background,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'You · #${viewerRank > 0 ? viewerRank : '—'}',
                  style: AppFonts.body(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${username == null || username.isEmpty ? '' : '@$username · '}$playerRank Rank',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.body(
                    color: foreground.withValues(alpha: 0.72),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$value${_leaderboardMetricSuffix(metric)}',
            style: AppFonts.body(
              color: foreground,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
    final displayName = _leaderboardDisplayName(entry);
    final username = entry.username;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outline)),
      ),
      child: InkWell(
        onTap: () => _openLeaderboardProfile(context, entry),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  entry.rank.toString().padLeft(2, '0'),
                  style: AppFonts.body(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _LeaderboardAvatar(
                imageUrl: entry.avatarUrl,
                name: displayName,
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.body(
                              color: scheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _PlayerRankTag(rank: entry.playerRank),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      username == null || username.isEmpty
                          ? 'Leaderboard player'
                          : '@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.body(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${entry.metricValue}${_leaderboardMetricSuffix(metric)}',
                style: AppFonts.body(
                  color: scheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
