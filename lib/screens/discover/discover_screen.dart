import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/challenge.dart';
import '../../models/progress_log.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/participation_provider.dart';
import '../../models/participation.dart';
import '../../services/challenges_service.dart';
import '../../services/profile_service.dart';
import '../../services/participation_service.dart';
import '../../theme/app_theme.dart';
import '../challenge/challenge_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfile? _profile;
  Map<String, Challenge> _challengesById = {};
  Challenge? _mostPopularChallenge;
  Participation? _resumeParticipation;
  List<ProgressLog> _resumeProgress = [];
  bool _resumeProgressLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHomeData();
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
      await context.read<ParticipationProvider>().load();
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
          context
              .read<ParticipationProvider>()
              .participations
              .where((p) => p.status != 'COMPLETED' && p.status != 'REMOVED')
              .toList()
            ..sort(_newestParticipationFirst);
      setState(() {
        _profile = profile ?? _profile;
        _challengesById = challengeMap;
        _mostPopularChallenge = mostPopular;
        _resumeParticipation = active.isEmpty ? null : active.first;
        _resumeProgress = [];
      });
      if (active.isNotEmpty) {
        await _loadResumeProgress(active.first.id);
      }
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

  Future<void> _loadResumeProgress(String participantId) async {
    if (mounted) setState(() => _resumeProgressLoading = true);
    try {
      final logs = await context.read<ParticipationService>().listProgress(
        participantId,
        limit: 100,
      );
      if (mounted) setState(() => _resumeProgress = logs);
    } catch (_) {
      // The challenge remains available even if its progress history is unavailable.
    } finally {
      if (mounted) setState(() => _resumeProgressLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final participation = context.watch<ParticipationProvider>();
    final name = _profile?.name ?? auth.displayName ?? auth.username ?? 'Pablo';
    final active = participation.participations
        .where((p) => p.status != 'COMPLETED' && p.status != 'REMOVED')
        .take(2)
        .toList();
    final completed = _profile?.completedChallengesCount ?? 0;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 60,
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: _HomeBrandHeader(
          onNotificationsTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications coming soon')),
            );
          },
        ),
      ),
      body: RefreshIndicator(
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
                    _Greeting(name: name, aura: _profile?.auraPoints ?? 0),
                    const SizedBox(height: 18),
                    _StatsRow(
                      active: active.length,
                      completed: completed,
                      streak: 4,
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle('Continue where you left off'),
                    const SizedBox(height: 8),
                    _ResumeCard(
                      challenge: _resumeParticipation == null
                          ? null
                          : _challengesById[_resumeParticipation!.challengeId],
                      progress: _resumeProgress,
                      isLoading: _resumeProgressLoading,
                      onTap: _resumeParticipation == null
                          ? null
                          : () => _openParticipation(_resumeParticipation!),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle('Your challenges'),
                    const SizedBox(height: 10),
                    if (active.isEmpty)
                      const _EmptyChallengeRow()
                    else
                      ...active.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ChallengeRow(
                            participation: item,
                            challenge: _challengesById[item.challengeId],
                            onTap: () => _openParticipation(item),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    const _SectionTitle('Maybe try next'),
                    const SizedBox(height: 10),
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
        IconButton(
          onPressed: onNotificationsTap,
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none_rounded),
          color: colorScheme.onSurface,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  final String name;
  final int aura;

  const _Greeting({required this.name, required this.aura});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inkColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.lightTextPrimary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hey $name 👋',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Keep learning. Keep levelling up.',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: inkColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              '⚡ $aura AURA',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
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
  final int completed;
  final int streak;

  const _StatsRow({
    required this.active,
    required this.completed,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(value: '$active', label: 'ACTIVE'),
        const SizedBox(width: 10),
        _Stat(value: '$completed', label: 'COMPLETED'),
        const SizedBox(width: 10),
        _Stat(value: '$streak🔥', label: 'DAY STREAK'),
      ],
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
        ? AppColors.dark
        : AppColors.lightTextPrimary;
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CONTINUE CHALLENGE',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: isLoading ? null : progressValue,
                  minHeight: 6,
                  backgroundColor: Color(0x332D3324),
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
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    challenge == null
                        ? 'Discover a challenge'
                        : 'Resume challenge →',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: inkColor,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  challenge?.title.toLowerCase().contains('chess') == true
                      ? Icons.extension
                      : Icons.grid_view_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge?.title ?? 'Your challenge',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFFB8B6AA)),
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
    final inkColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.lightTextPrimary;
    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: inkColor,
                  borderRadius: BorderRadius.circular(12),
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
