import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer, Provider;

import '../../models/challenge.dart';
import '../../models/challenge_detail.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_state_providers.dart';
import '../../providers/notification_badge_provider.dart';
import '../../models/participation.dart';
import '../../models/user_stats.dart';
import '../../services/challenges_service.dart';
import '../../services/participation_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error.dart';
import '../challenge/challenge_detail_screen.dart';
import '../profile/profile_screen.dart';

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
  ChallengeDetail? _resumeDetail;
  Object? _homeError;
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
    if (mounted && _homeError != null) {
      setState(() => _homeError = null);
    }
    final auth = context.read<AuthProvider>();
    final username = auth.username;
    final profileService = context.read<ProfileService>();
    final challengesService = context.read<ChallengesService>();
    final participationService = context.read<ParticipationService>();
    final profileFuture = username != null && username.isNotEmpty
        ? profileService.getProfile(username)
        : null;
    final challengesFuture = challengesService.list(limit: 100);

    final cachedProfile = username != null && username.isNotEmpty
        ? await profileService.getCachedProfile(username)
        : null;
    final cachedChallenges = await challengesService.getCachedInitial();
    final cachedParticipation =
      ref.read(participationControllerProvider).valueOrNull ??
      await participationService.getCachedMine();
    if (mounted &&
      (cachedProfile != null ||
        cachedChallenges != null ||
        cachedParticipation != null)) {
      final cachedItems = cachedChallenges ?? const [];
      final cachedMap = {
        for (final challenge in cachedItems) challenge.id: challenge,
      };
      final cachedActive = (cachedParticipation ?? const [])
        .where((p) => p.status != 'COMPLETED' && p.status != 'REMOVED')
        .toList();
      final cachedPopular = cachedItems
          .where((challenge) => challenge.enrollmentCount != null)
          .fold<Challenge?>(
            null,
            (popular, challenge) =>
                popular == null ||
                    challenge.enrollmentCount! > popular.enrollmentCount!
                ? challenge
                : popular,
          );
      setState(() {
        _profile = cachedProfile ?? _profile;
        if (cachedChallenges != null) {
          _challengesById = cachedMap;
          _mostPopularChallenge = cachedPopular;
        }
        _resumeParticipation = _selectResumeParticipation(cachedActive);
      });
      final cachedResume = _resumeParticipation;
      final cachedResumeChallenge = cachedResume == null
          ? null
          : cachedMap[cachedResume.challengeId];
      if (cachedResumeChallenge != null) {
        final cachedDetail = await challengesService.getCachedDetailBySlug(
          cachedResumeChallenge.slug,
        );
        if (mounted && cachedDetail != null) {
          setState(() => _resumeDetail = cachedDetail);
        }
      }
    }
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
              .toList();
      final resumeParticipation = _selectResumeParticipation(active);
      ChallengeDetail? resumeDetail;
      final resumeChallenge = resumeParticipation == null
          ? null
          : challengeMap[resumeParticipation.challengeId];
      if (resumeChallenge != null) {
        try {
          resumeDetail = await context
              .read<ChallengesService>()
              .getDetailBySlug(resumeChallenge.slug);
        } catch (_) {
          // The resume card can still render without personal progress.
        }
      }
      setState(() {
        _profile = profile ?? _profile;
        _challengesById = challengeMap;
        _mostPopularChallenge = mostPopular;
        _resumeParticipation = resumeParticipation;
        _resumeDetail = resumeDetail;
      });
    } catch (error) {
      // Cached home data can remain visible, but the failed refresh should be
      // actionable instead of disappearing silently.
      if (mounted) {
        AppErrorSnackbar.show(context, error, onRetry: _loadHomeData);
        if (_profile == null &&
            _challengesById.isEmpty &&
            _resumeParticipation == null) {
          setState(() => _homeError = error);
        }
      }
    }
  }

  static Participation? _selectResumeParticipation(
    List<Participation> participations,
  ) {
    if (participations.isEmpty) return null;

    final attempted =
        participations
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
    if (_homeError != null &&
        _profile == null &&
        _challengesById.isEmpty &&
        _resumeParticipation == null) {
      return Scaffold(
        body: AppErrorView(error: _homeError!, onRetry: _loadHomeData),
      );
    }
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: HomePalette.background(brightness),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 60,
        backgroundColor: HomePalette.background(brightness)
          .withValues(alpha: _isScrolled ? 0.88 : 1),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: _HomeBrandHeader(
          onNotificationsTap: () {
            final badge = context.read<NotificationBadgeController>();
            badge.markAllRead();
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                )
                .then(
                  (_) => context.read<NotificationBadgeController>().refresh(),
                );
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
          color: brightness == Brightness.dark
              ? HomePalette.primary
              : HomePalette.ink,
          backgroundColor: HomePalette.surface(brightness),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Greeting(name: name, streak: stats?.dayStreak ?? 0),
                      _WeekStrip(streak: stats?.dayStreak ?? 0),
                      const SizedBox(height: 16),
                      _AuraCard(stats: stats),
                      const SizedBox(height: 16),
                      _ResumeCard(
                        challenge: _resumeParticipation == null
                            ? null
                            : _challengesById[_resumeParticipation!
                                  .challengeId],
                        detail: _resumeDetail,
                        onTap: _resumeParticipation == null
                            ? null
                            : () => _openParticipation(_resumeParticipation!),
                      ),
                      const SizedBox(height: 22),
                      _SectionHeader(
                        title: 'Your challenges',
                        action: 'View all',
                        onAction: _openMyChallenges,
                      ),
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
                      const _SectionHeader(
                        title: 'Maybe try next',
                        action: 'Discover',
                      ),
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

  void _openMyChallenges() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }
}

class _HomeBrandHeader extends StatelessWidget {
  final VoidCallback onNotificationsTap;

  const _HomeBrandHeader({required this.onNotificationsTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'NERD',
              style: AppFonts.home(
                color: HomePalette.textPrimary(brightness),
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacingEm: 0.05,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: HomePalette.bright,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'MAXXING',
                style: AppFonts.home(
                  color: HomePalette.ink,
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
    final brightness = Theme.of(context).brightness;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hey $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.home(
                  color: HomePalette.textPrimary(brightness),
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                  letterSpacingEm: -0.02,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Keep learning. Keep levelling up.',
                style: AppFonts.home(
                  color: HomePalette.textSecondary(brightness),
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: HomePalette.peachWash(brightness),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 15,
                color: HomePalette.peachText(brightness),
              ),
              const SizedBox(width: 4),
              Text(
                '$streak ${streak == 1 ? 'day' : 'days'}',
                style: AppFonts.home(
                  color: HomePalette.peachText(brightness),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  final int streak;

  const _WeekStrip({required this.streak});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final today = DateTime.now();
    final days = List.generate(7, (index) {
      return today.subtract(Duration(days: 6 - index));
    });
    const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var index = 0; index < days.length; index++)
            Column(
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (index == 6)
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            color: HomePalette.primary,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox.expand(),
                        )
                      else
                        CustomPaint(
                          size: const Size.square(34),
                          painter: _DottedCirclePainter(
                            color: HomePalette.borderStrong(brightness),
                          ),
                        ),
                      if (index == 6 && streak > 0)
                        const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: HomePalette.ink,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  index == 6
                      ? 'Today'
                      : weekdayLabels[days[index].weekday - 1],
                  style: AppFonts.home(
                    color: index == 6
                        ? HomePalette.textPrimary(brightness)
                        : HomePalette.textSecondary(brightness),
                    fontSize: index == 6 ? 9 : 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DottedCirclePainter extends CustomPainter {
  final Color color;

  const _DottedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 1;
    final paint = Paint()..color = color;
    const dotCount = 16;
    for (var index = 0; index < dotCount; index++) {
      final angle = (index * 2 * math.pi / dotCount) - math.pi / 2;
      canvas.drawCircle(
        Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        ),
        1.2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DottedCirclePainter oldDelegate) =>
      color != oldDelegate.color;
}

class _AuraCard extends StatelessWidget {
  final UserStats? stats;

  const _AuraCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final progress = ((stats?.rankProgress ?? 0).clamp(0, 100)) / 100;
    final nextRank = stats?.nextRank;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HomePalette.surfaceAlt(brightness),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HomePalette.border(brightness)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    HomePalette.primary.withValues(
                      alpha: brightness == Brightness.dark ? 0.22 : 0.55,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL AURA',
                      style: AppFonts.home(
                        color: HomePalette.textSecondary(brightness),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacingEm: 0.14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: brightness == Brightness.dark
                            ? HomePalette.primaryMuted(brightness)
                            : HomePalette.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Rank ${stats?.rank ?? 'E'}',
                        style: AppFonts.home(
                          color: HomePalette.rankText(brightness),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${stats?.auraPoints ?? 0}',
                  style: AppFonts.home(
                    color: brightness == Brightness.dark
                        ? HomePalette.primary
                        : HomePalette.ink,
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacingEm: -0.03,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: stats == null ? null : progress,
                    minHeight: 6,
                    backgroundColor: HomePalette.border(brightness),
                    color: HomePalette.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        nextRank == null
                            ? 'Highest rank reached'
                            : '${stats!.auraToNextRank} AP to Rank $nextRank',
                        style: AppFonts.home(
                          color: HomePalette.textSecondary(brightness),
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                    Text(
                      '${stats?.rankProgress ?? 0}%',
                      style: AppFonts.home(
                        color: HomePalette.textSecondary(brightness),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _AuraStat(
                        value: '${stats?.activeChallengeCount ?? 0}',
                        label: 'Active',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AuraStat(
                        value: '${stats?.completedChallengeCount ?? 0}',
                        label: 'Completed',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuraStat extends StatelessWidget {
  final String value;
  final String label;

  const _AuraStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: HomePalette.surface(brightness),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomePalette.border(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppFonts.home(
              color: HomePalette.textPrimary(brightness),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: AppFonts.home(
              color: HomePalette.textSecondary(brightness),
              fontSize: 11,
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
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: _SectionTitle(title)),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            action,
            style: AppFonts.home(
              color: HomePalette.link(brightness),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Text(
      title,
      style: AppFonts.home(
        color: HomePalette.textPrimary(brightness),
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacingEm: -0.01,
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  final Challenge? challenge;
  final ChallengeDetail? detail;
  final VoidCallback? onTap;

  const _ResumeCard({
    required this.challenge,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = challenge?.title ?? 'No active challenge yet';
    final metric = detail?.primaryMetric;
    final baseline = _number(
      detail?.progress.baselineValue,
      fallback: metric?.baseline ?? 0,
    );
    final current = _number(
      detail?.progress.currentValue,
      fallback: metric?.current ?? baseline,
    );
    final target = _number(
      detail?.progress.targetValue,
      fallback: metric?.target ?? current,
    );
    final span = target - baseline;
    final progressValue = span <= 0
        ? 0.0
        : ((current - baseline) / span).clamp(0.0, 1.0).toDouble();
    final ringProgress = detail == null
      ? 0.04
      : math.max(progressValue, 0.04).toDouble();
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [HomePalette.primary, HomePalette.mint],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  height: 70,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: ringProgress,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        backgroundColor: HomePalette.ink.withValues(alpha: 0.25),
                        color: HomePalette.ink,
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: HomePalette.resumeRingFill,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                            detail == null
                              ? '--'
                              : '${(progressValue * 100).round()}%',
                          style: AppFonts.home(
                            color: HomePalette.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CONTINUE',
                        style: AppFonts.home(
                          color: HomePalette.ink.withValues(alpha: 0.65),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacingEm: 0.13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.home(
                          color: HomePalette.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: HomePalette.ink,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          challenge == null ? 'Discover' : 'Resume  →',
                          style: AppFonts.home(
                            color: HomePalette.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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

  static double _number(Object? value, {required double fallback}) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
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
    final brightness = Theme.of(context).brightness;
    final title = challenge?.title ?? 'Your challenge';
    final gradient = HomePalette.challengeGradient(title);
    final icon = title.toLowerCase().contains('fire')
        ? Icons.local_fire_department_rounded
        : title.toLowerCase().contains('lock')
        ? Icons.lock_outline_rounded
        : title.toLowerCase().contains('chess')
        ? Icons.extension_rounded
        : Icons.grid_view_rounded;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: HomePalette.surface(brightness),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: HomePalette.border(brightness)),
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
                    gradient: RadialGradient(
                      colors: gradient,
                      center: const Alignment(-0.45, -0.5),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: HomePalette.imageText,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.home(
                          color: HomePalette.textPrimary(brightness),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
                            icon: Icons.bolt_rounded,
                            label: '${challenge?.auraPoints ?? 0} aura',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: HomePalette.textSecondary(brightness),
                ),
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
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: HomePalette.surfaceAlt(brightness),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: HomePalette.textSecondary(brightness)),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: AppFonts.home(
              color: HomePalette.textSecondary(brightness),
              fontSize: 11,
            ),
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
    final brightness = Theme.of(context).brightness;
    final bg = paused
      ? (isDark
          ? HomePalette.pausedDarkBackground
          : HomePalette.pausedLightBackground)
      : HomePalette.primaryMuted(brightness);
    final fg = paused
      ? (isDark ? HomePalette.pausedDarkText : HomePalette.pausedLightText)
      : (isDark ? HomePalette.primary : HomePalette.lightLink);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: AppFonts.home(
          color: fg,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _EmptyChallengeRow extends StatelessWidget {
  const _EmptyChallengeRow();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomePalette.surface(brightness),
        border: Border.all(color: HomePalette.border(brightness)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'No active challenges yet. Pick one in Discover.',
        style: AppFonts.home(
          color: HomePalette.textSecondary(brightness),
          fontSize: 13.5,
        ),
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
    final title = challenge?.title ?? 'Discover a challenge';
    final gradient = HomePalette.challengeGradient(title);
    final icon = title.toLowerCase().contains('handstand')
        ? Icons.accessibility_new_rounded
        : title.toLowerCase().contains('juggle')
        ? Icons.sports_gymnastics_rounded
        : title.toLowerCase().contains('lift')
        ? Icons.fitness_center_rounded
        : Icons.local_fire_department_rounded;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: RadialGradient(
            center: const Alignment(-0.45, -0.55),
            colors: gradient,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(22)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, HomePalette.imageOverlay],
                    stops: [0.35, 1],
                  ),
                ),
              ),
              Positioned(
                top: 18,
                right: 24,
                child: Icon(
                  icon,
                  size: 54,
                  color: HomePalette.imageText.withValues(alpha: 0.75),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: HomePalette.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    challenge == null ? 'START HERE' : '#1 MOST JOINED',
                    style: AppFonts.home(
                      color: HomePalette.ink,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacingEm: 0.04,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.home(
                        color: HomePalette.imageText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    if (challenge != null &&
                        (challenge!.auraPoints > 0 ||
                            challenge!.enrollmentCount != null)) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (challenge!.auraPoints > 0)
                            _ImageChip(label: '${challenge!.auraPoints} aura'),
                          if (challenge!.enrollmentCount != null)
                            _ImageChip(
                              label: '${challenge!.enrollmentCount} joined',
                            ),
                        ],
                      ),
                    ],
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

class _ImageChip extends StatelessWidget {
  final String label;

  const _ImageChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: AppFonts.home(
        color: HomePalette.imageText,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
