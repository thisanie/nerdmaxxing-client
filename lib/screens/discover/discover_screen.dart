import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/challenge.dart';
import '../../models/discover.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/discover_provider.dart';
import '../../providers/participation_provider.dart';
import '../../models/participation.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/challenge_section.dart';
import '../challenge/challenge_detail_screen.dart';
import '../challenge/create_challenge_screen.dart';
import 'category_challenges_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscoverProvider>().load();
      _loadHomeData();
    });
  }

  Future<void> _loadHomeData() async {
    final auth = context.read<AuthProvider>();
    final username = auth.username;
    final profileFuture = username != null && username.isNotEmpty
        ? context.read<ProfileService>().getProfile(username)
        : null;
    try {
      await context.read<ParticipationProvider>().load();
      final profile = profileFuture == null ? null : await profileFuture;
      if (!mounted) return;
      if (profile != null) {
        setState(() => _profile = profile);
      }
    } catch (_) {
      // The discovery feed remains usable if the home summary is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DiscoverProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([provider.load(), _loadHomeData()]);
        },
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              title: const Text('Home'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Create a challenge',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateChallengeScreen(),
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(child: _HomeHero(profile: _profile)),
            SliverToBoxAdapter(child: _AttemptingChallenges()),
            if (provider.isLoading &&
                provider.feed.featured == null &&
                _isEmpty(provider))
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.errorMessage != null && _isEmpty(provider))
              SliverFillRemaining(
                child: _ErrorState(
                  message: provider.errorMessage!,
                  onRetry: provider.load,
                ),
              )
            else ...[
              if (provider.feed.featured != null)
                SliverToBoxAdapter(
                  child: _FeaturedChallenge(challenge: provider.feed.featured!),
                ),
              SliverToBoxAdapter(
                child: CategorySection(
                  categories: provider.feed.categories,
                  onTap: _openCategory,
                ),
              ),
              _section('Trending Now', provider.feed.trending, seeAll: true),
              _section(
                'New Challenges',
                provider.feed.newChallenges,
                seeAll: true,
              ),
              _section('Because You Completed...', provider.feed.recommended),
              _section(
                'Legendary Challenges',
                provider.feed.legendary,
                legendary: true,
              ),
              _section('Explore the Unexpected', provider.feed.unexpected),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ),
      ),
    );
  }

  bool _isEmpty(DiscoverProvider provider) =>
      provider.feed.featured == null &&
      provider.feed.trending.isEmpty &&
      provider.feed.categories.isEmpty &&
      provider.feed.newChallenges.isEmpty &&
      provider.feed.recommended.isEmpty &&
      provider.feed.legendary.isEmpty &&
      provider.feed.unexpected.isEmpty;

  Widget _section(
    String title,
    List<Challenge> challenges, {
    bool seeAll = false,
    bool legendary = false,
  }) {
    return SliverToBoxAdapter(
      child: ChallengeSection(
        title: title,
        challenges: challenges,
        legendary: legendary,
        onSeeAll: seeAll ? () => _openAll(title) : null,
        onChallengeTap: _openChallenge,
      ),
    );
  }

  void _openChallenge(Challenge challenge) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChallengeDetailScreen(slug: challenge.slug),
      ),
    );
  }

  void _openCategory(DiscoverCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CategoryChallengesScreen(name: category.name, slug: category.slug),
      ),
    );
  }

  void _openAll(String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryChallengesScreen(name: title, slug: null),
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  final UserProfile? profile;
  const _HomeHero({required this.profile});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final greetingName =
        profile?.name ?? auth.displayName ?? auth.username ?? 'NerdMaxxer';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WELCOME BACK',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Good to see you, $greetingName.',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Keep learning. Keep levelling up.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                const Icon(Icons.bolt, color: AppColors.warning, size: 28),
                const SizedBox(height: 3),
                Text(
                  '${profile?.auraPoints ?? 0}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'aura',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttemptingChallenges extends StatelessWidget {
  const _AttemptingChallenges();

  String _statusLabel(String status) {
    switch (status) {
      case 'ACCEPTED':
        return 'Accepted';
      case 'IN_PROGRESS':
        return 'In progress';
      case 'PAUSED':
        return 'Paused';
      case 'SUBMITTED':
        return 'Submitted';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = context
        .watch<ParticipationProvider>()
        .participations
        .where((p) => p.status != 'COMPLETED' && p.status != 'REMOVED')
        .toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Currently attempting',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...active
              .take(3)
              .map(
                (participation) => _AttemptingTile(
                  participation: participation,
                  statusLabel: _statusLabel(participation.status),
                ),
              ),
        ],
      ),
    );
  }
}

class _AttemptingTile extends StatelessWidget {
  final Participation participation;
  final String statusLabel;
  const _AttemptingTile({
    required this.participation,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final id = participation.challengeId;
    final shortId = id.length > 8 ? '${id.substring(0, 8)}...' : id;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.surfaceAlt,
          child: Icon(Icons.flag_outlined, color: AppColors.primary),
        ),
        title: Text('Challenge $shortId'),
        subtitle: Text(statusLabel),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }
}

class _FeaturedChallenge extends StatelessWidget {
  final Challenge challenge;
  const _FeaturedChallenge({required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChallengeDetailScreen(slug: challenge.slug),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.75,
                child: challenge.imageUrl != null
                    ? Image.network(
                        challenge.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _featuredFallback(),
                      )
                    : _featuredFallback(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FEATURED CHALLENGE',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      challenge.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      challenge.shortDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          challenge.effortLabel,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          challenge.difficultyLevel,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ChallengeDetailScreen(slug: challenge.slug),
                          ),
                        ),
                        child: const Text('Take Challenge'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featuredFallback() => Container(
    color: AppColors.surfaceAlt,
    alignment: Alignment.center,
    child: const Icon(
      Icons.auto_awesome,
      size: 42,
      color: AppColors.primaryMuted,
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off,
              size: 36,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Couldn\'t load Discover',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
