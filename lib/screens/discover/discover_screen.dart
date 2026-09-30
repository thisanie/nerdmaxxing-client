import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer, Provider;

import '../../models/challenge.dart';
import '../../models/progress_log.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_state_providers.dart';
import '../../providers/notification_badge_provider.dart';
import '../../models/participation.dart';
import '../../services/challenges_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../challenge/challenge_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  UserProfile? _profile;
  Map<String, Challenge> _challengesById = {};
  Challenge? _mostPopularChallenge;
  Participation? _resumeParticipation;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHomeData();
      context.read<NotificationBadgeController>().refresh();
    });
  }

  Future<void> _loadHomeData() async {
    final auth = context.read<AuthProvider>();
    final username = auth.username;
    final profileFuture = username != null && username.isNotEmpty
        ? context.read<ProfileService>().getProfile(username)
        : null;
    final challengesFuture = context.read<ChallengesService>().list(limit: 100);
    try {
      await ref.read(participationControllerProvider.future);
      final profile = profileFuture == null ? null : await profileFuture;
      final challenges = await challengesFuture;
      if (!mounted) return;
      final challengeMap = {
        for (final challenge in challenges) challenge.id: challenge,
      };
      final mostPopular = challenges
          .where((challenge) => challenge.enrollmentCount != null)
          .fold<Challenge?>(
            null,
            (popular, challenge) =>
                popular == null ||
                    challenge.enrollmentCount! > popular.enrollmentCount!
                ? challenge
                : popular,
          );
      final active = (ref.read(participationControllerProvider).valueOrNull ?? [])
          .where((p) => p.status != 'COMPLETED' && p.status != 'REMOVED')
          .toList();
      final resumeParticipation = _selectResumeParticipation(active);
      setState(() {
        _profile = profile ?? _profile;
        _challengesById = challengeMap;
        _mostPopularChallenge = mostPopular;
        _resumeParticipation = resumeParticipation;
      });
    } catch (_) {
      // The discovery feed remains usable if the home summary is unavailable.
    }
  }

  static Participation? _selectResumeParticipation(
    List<Participation> participations,
  ) {
    if (participations.isEmpty) return null;

    final attempted = participations
        .where((participation) => participation.lastActivityAt != null)
        .toList()
      ..sort(_newestActivityFirst);
    if (attempted.isNotEmpty) return attempted.first;

    final joined = [...participations]..sort(_newestJoinedFirst);
    return joined.first;
  }

  static int _newestActivityFirst(Participation a, Participation b) {
    final aDate = a.lastActivityAt;
    final bDate = b.lastActivityAt;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  }

  static int _newestJoinedFirst(Participation a, Participation b) {
    final aDate = a.startedAt;
    final bDate = b.startedAt;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final participation = ref.watch(participationControllerProvider);
    final participationItems = participation.valueOrNull ?? const [];
    final name = _profile?.name ?? auth.displayName ?? auth.username ?? 'Pablo';
    final active = participationItems
        .where((p) => p.status != 'COMPLETED' && p.status != 'REMOVED')
        .take(2)
        .toList();
    final stats = ref.watch(myStatsProvider).valueOrNull;
    final resumeProgressState = _resumeParticipation == null
      ? null
      : ref.watch(progressLogsProvider(_resumeParticipation!.id));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 60,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(
          alpha: _isScrolled ? 0.88 : 1,
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: _HomeBrandHeader(
          onNotificationsTap: () {
            final badge = context.read<NotificationBadgeController>();
            badge.markAllRead();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationsScreen(),
              ),
            ).then((_) => context.read<NotificationBadgeController>().refresh());
          },
        ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          final isScrolled = notification.metrics.pixels > 4;
          if (isScrolled != _isScrolled) {
            setState(() => _isScrolled = isScrolled);
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadHomeData();
          },
          color: Theme.of(context).colorScheme.onSurface,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Greeting(
                      name: name,
                      streak: stats?.dayStreak ?? 0,
                    ),
                    const SizedBox(height: 22),
                    _StatsRow(
                      active: stats?.activeChallengeCount ?? 0,
                      aura: stats?.auraPoints ?? 0,
                      completed: stats?.completedChallengeCount ?? 0,
                    ),
                    const SizedBox(height: 16),
                    _ResumeCard(
                      challenge: _resumeParticipation == null
                          ? null
                          : _challengesById[_resumeParticipation!.challengeId],
                      progress: resumeProgressState?.valueOrNull ?? const [],
                      isLoading: resumeProgressState?.isLoading ?? false,
                      onTap: _resumeParticipation == null
                          ? null
                          : () => _openParticipation(_resumeParticipation!),
                    ),
                    const SizedBox(height: 36),
                    const _SectionHeader(title: 'Your challenges', action: 'View all'),
                    const SizedBox(height: 14),
                    if (active.isEmpty)
                      const _EmptyChallengeRow()
                    else
                      ...active.map(
                        (item) => _ChallengeRow(
                          participation: item,
                          challenge: _challengesById[item.challengeId],
                          onTap: () => _openParticipation(item),
                        ),
                      ),
                    const SizedBox(height: 28),
                    const _SectionHeader(title: 'Maybe try next', action: 'Discover'),
                    const SizedBox(height: 14),
                    _NudgeCard(
                      challenge: _mostPopularChallenge,
                      onTap: _mostPopularChallenge == null
                          ? null
                          : () => _openChallenge(_mostPopularChallenge!),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  void _openParticipation(Participation participation) {
    final challenge = _challengesById[participation.challengeId];
    if (challenge == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChallengeDetailScreen(
          slug: challenge.slug,
          initialChallenge: challenge,
        ),
      ),
    );
  }

  void _openChallenge(Challenge challenge) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChallengeDetailScreen(
          slug: challenge.slug,
          initialChallenge: challenge,
        ),
      ),
    );
  }
}

class _HomeBrandHeader extends StatelessWidget {
  final VoidCallback onNotificationsTap;

  const _HomeBrandHeader({required this.onNotificationsTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'NERD',
              style: AppFonts.body(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacingEm: 0.05,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'MAXXING',
                style: AppFonts.body(
                  color: AppColors.dark,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacingEm: 0.05,
                ),
              ),
            ),
          ],
        ),
        Consumer<NotificationBadgeController>(
          builder: (context, badge, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onNotificationsTap,
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_none_rounded),
                color: colorScheme.onSurface,
                visualDensity: VisualDensity.compact,
              ),
              if (badge.unreadCount > 0)
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  final String name;
  final int streak;

  const _Greeting({required this.name, required this.streak});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hey $name',
          style: AppFonts.body(
            color: colorScheme.onSurface,
            fontSize: 34,
            fontWeight: FontWeight.w500,
            height: 1.1,
            letterSpacingEm: -0.02,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Keep learning. Keep levelling up.',
                style: AppFonts.body(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: ShapeDecoration(
                color: colorScheme.surface,
                shape: StadiumBorder(side: BorderSide(color: colorScheme.outline)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 16,
                    color: AppColors.puzzle,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$streak day streak',
                    style: AppFonts.body(
                      color: colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int active;
  final int aura;
  final int completed;

  const _StatsRow({
    required this.active,
    required this.aura,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outline),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(child: _Stat(value: '$active', label: 'Active')),
            VerticalDivider(width: 1, color: scheme.outline),
            Expanded(child: _Stat(value: '$aura', label: 'Aura')),
            VerticalDivider(width: 1, color: scheme.outline),
            Expanded(child: _Stat(value: '$completed', label: 'Completed')),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Text(
            value,
            style: AppFonts.body(
              color: colorScheme.onSurface,
              fontSize: 30,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppFonts.body(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;

  const _SectionHeader({required this.title, required this.action});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Expanded(child: _SectionTitle(title)),
      Text(
        action,
        style: AppFonts.body(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: AppFonts.body(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: 22,
      fontWeight: FontWeight.w500,
      letterSpacingEm: -0.01,
    ),
  );
}

class _ResumeCard extends StatelessWidget {
  final Challenge? challenge;
  final List<ProgressLog> progress;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ResumeCard({
    required this.challenge,
    required this.progress,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = challenge?.title ?? 'No active challenge yet';
    final loggedMinutes = progress.fold(
      0,
      (total, log) => total + log.minutesSpent,
    );
    final targetMinutes =
        challenge?.estimatedDurationMinutes ??
        challenge?.estimatedEffortMaxMinutes ??
        challenge?.estimatedEffortMinMinutes;
    final progressValue = targetMinutes == null || targetMinutes <= 0
        ? 0.0
        : (loggedMinutes / targetMinutes).clamp(0.0, 1.0).toDouble();
    const onDark = Color(0xFFF6F6F1);
    const mutedOnDark = Color(0xFF9A9A92);
    return Material(
      color: AppColors.dark,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONTINUE WHERE YOU LEFT OFF',
                style: AppFonts.label(color: AppColors.primary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: AppFonts.body(
                  color: onDark,
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  height: 1.15,
                  letterSpacingEm: -0.01,
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: isLoading ? null : progressValue,
                  minHeight: 6,
                  backgroundColor: const Color(0xFF2E2E2B),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    targetMinutes == null
                        ? '${_formatMinutes(loggedMinutes)} logged'
                        : '${(progressValue * 100).round()}% to goal',
                    style: AppFonts.body(color: mutedOnDark, fontSize: 14),
                  ),
                  Text(
                    isLoading
                        ? 'Loading progress...'
                        : '${_formatMinutes(loggedMinutes)} logged',
                    style: AppFonts.body(color: mutedOnDark, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF3A3A36)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      challenge == null ? 'Discover a challenge' : 'Resume challenge',
                      style: AppFonts.body(
                        color: onDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Icon(Icons.arrow_forward, color: onDark, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes == 0
        ? '${hours}h'
        : '${hours}h ${remainingMinutes}m';
  }
}

class _ChallengeRow extends StatelessWidget {
  final Participation participation;
  final Challenge? challenge;
  final VoidCallback onTap;

  const _ChallengeRow({
    required this.participation,
    required this.challenge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPaused = participation.status == 'PAUSED';
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    challenge?.title.toLowerCase().contains('chess') == true
                        ? Icons.extension_outlined
                        : Icons.grid_view_rounded,
                    color: colorScheme.onSurface,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge?.title ?? 'Your challenge',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.body(
                          color: colorScheme.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _StatusPill(
                            label: isPaused ? 'Paused' : 'Active',
                            paused: isPaused,
                          ),
                          _InfoChip(
                            icon: Icons.bolt,
                            label: '${challenge?.auraPoints ?? 0} aura',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData? icon;
  final String label;

  const _InfoChip({this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: AppFonts.body(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool paused;

  const _StatusPill({required this.label, required this.paused});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = paused
        ? (isDark ? const Color(0xFF4A3B12) : const Color(0xFFFFE7A3))
        : (isDark ? AppColors.primaryMuted : AppColors.limeWash);
    final fg = paused
        ? (isDark ? const Color(0xFFFFD98A) : const Color(0xFF7A5A00))
        : (isDark ? AppColors.primary : const Color(0xFF55700F));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: AppFonts.body(color: fg, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _EmptyChallengeRow extends StatelessWidget {
  const _EmptyChallengeRow();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'No active challenges yet. Pick one in Discover.',
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13.5),
      ),
    );
  }
}

class _NudgeCard extends StatelessWidget {
  final Challenge? challenge;
  final VoidCallback? onTap;

  const _NudgeCard({required this.challenge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.limeWash,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.local_fire_department_outlined,
                  color: AppColors.lightTextPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge == null ? 'NO CHALLENGES YET' : '#1 MOST JOINED',
                      style: AppFonts.label(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      challenge?.title ?? 'Discover a challenge',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.body(
                        color: colorScheme.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (challenge?.auraPoints != null ||
                        challenge?.enrollmentCount != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (challenge?.auraPoints != null)
                            _InfoChip(
                              icon: Icons.bolt,
                              label: '${challenge!.auraPoints} aura',
                            ),
                          if (challenge?.enrollmentCount != null)
                            Text(
                              '${challenge!.enrollmentCount} joined',
                              style: AppFonts.body(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
