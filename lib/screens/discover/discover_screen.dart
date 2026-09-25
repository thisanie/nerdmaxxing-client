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
      final active =
            (ref.read(participationControllerProvider).valueOrNull ?? [])
              .where((p) => p.status != 'COMPLETED' && p.status != 'REMOVED')
              .toList()
            ..sort(_newestParticipationFirst);
      setState(() {
        _profile = profile ?? _profile;
        _challengesById = challengeMap;
        _mostPopularChallenge = mostPopular;
        _resumeParticipation = active.isEmpty ? null : active.first;
      });
    } catch (_) {
      // The discovery feed remains usable if the home summary is unavailable.
    }
  }

  static int _newestParticipationFirst(Participation a, Participation b) {
    final aDate = a.startedAt ?? a.lastActivityAt;
    final bDate = b.startedAt ?? b.lastActivityAt;
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
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(
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
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
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
                    const SizedBox(height: 18),
                    _StatsRow(
                      active: stats?.activeChallengeCount ?? 0,
                      aura: stats?.auraPoints ?? 0,
                      completed: stats?.completedChallengeCount ?? 0,
                    ),
                    const SizedBox(height: 42),
                    const _SectionTitle('Continue where you left off'),
                    const SizedBox(height: 22),
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
                    const SizedBox(height: 44),
                    const _SectionHeader(title: 'Your challenges', action: 'View all'),
                    const SizedBox(height: 20),
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
                    const SizedBox(height: 44),
                    const _SectionHeader(title: 'Maybe try next', action: 'Discover'),
                    const SizedBox(height: 20),
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
        RichText(
          text: TextSpan(
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
            children: [
              TextSpan(text: 'NERD'),
              TextSpan(
                text: 'MAXXING',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
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
                      color: AppColors.primary,
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
          'Hey $name 👋',
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.05),
        ),
        const SizedBox(height: 8),
        Text(
          'Keep learning. Keep levelling up.',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15),
        ),
        const SizedBox(height: 20),
        Container(height: 1, color: colorScheme.outline),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$streak DAY STREAK',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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
    return Row(
      children: [
        Expanded(child: _Stat(value: '$active', label: 'ACTIVE')),
        Expanded(
          child: _Stat(
            value: '$aura',
            label: 'AURA',
            color: AppColors.primary,
            bordered: true,
            centered: true,
          ),
        ),
        Expanded(
          child: _Stat(
            value: '$completed',
            label: 'COMPLETED',
            bordered: true,
            centered: true,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  final bool bordered;
  final bool centered;

  const _Stat({
    required this.value,
    required this.label,
    this.color,
    this.bordered = false,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(top: 16, left: bordered ? 16 : 0),
      decoration: BoxDecoration(
        border: bordered
            ? Border(left: BorderSide(color: colorScheme.outline))
            : null,
      ),
      child: Column(
        crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w500,
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
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          letterSpacing: .7,
          fontWeight: FontWeight.w500,
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
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.transparent
        : Colors.transparent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CONTINUE CHALLENGE',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                child: LinearProgressIndicator(
                  value: isLoading ? null : progressValue,
                  minHeight: 6,
                  backgroundColor: AppColors.borderStrong,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    targetMinutes == null
                        ? '${_formatMinutes(loggedMinutes)} logged'
                        : '${(progressValue * 100).round()}% to goal',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    isLoading
                        ? 'Loading progress...'
                        : '${_formatMinutes(loggedMinutes)} logged',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      challenge == null ? 'Discover a challenge' : 'RESUME CHALLENGE',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 14,
                        letterSpacing: .8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(Icons.arrow_forward, color: colorScheme.onPrimary, size: 18),
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
    final inkColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.lightTextPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: colorScheme.outline),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Icon(
                  challenge?.title.toLowerCase().contains('chess') == true
                      ? Icons.extension
                      : Icons.grid_view_rounded,
                  color: AppColors.primary,
                  size: 20,
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _StatusPill(
                          label: isPaused ? 'PAUSED' : 'ACTIVE',
                          paused: isPaused,
                        ),
                        const SizedBox(width: 8),
                        if (isPaused)
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: .32,
                                minHeight: 5,
                                backgroundColor: colorScheme.outline,
                                color: AppColors.primaryMuted,
                              ),
                            ),
                          ),
                        if (isPaused) const SizedBox(width: 8),
                        Text(
                          isPaused ? '32%' : 'In progress',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.bolt,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${challenge?.auraPoints ?? 0} aura',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: paused
            ? (isDark ? const Color(0xFF4A3B12) : const Color(0xFFFFE7A3))
            : (isDark ? const Color(0xFF203A15) : const Color(0xFFD7F0C2)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: TextStyle(
            color: paused
                ? (isDark ? const Color(0xFFFFD98A) : const Color(0xFF7A5A00))
                : (isDark ? const Color(0xFF9CE87A) : const Color(0xFF2E5B12)),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colorScheme.outline)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Icon(
                  Icons.local_fire_department_outlined,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge == null
                          ? 'NO CHALLENGES YET'
                          : '#1 MOST JOINED',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      challenge?.title ?? 'Discover a challenge',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (challenge?.auraPoints != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.bolt,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${challenge?.auraPoints ?? 0} aura',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (challenge?.enrollmentCount != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${challenge!.enrollmentCount} joined',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
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
