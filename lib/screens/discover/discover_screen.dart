import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/challenge.dart';
import '../../models/discover.dart';
import '../../providers/discover_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/challenge_section.dart';
import '../challenge/challenge_detail_screen.dart';
import '../challenge/create_challenge_screen.dart';
import 'category_challenges_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscoverProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DiscoverProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: provider.load,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              title: const Text('Discover'),
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
