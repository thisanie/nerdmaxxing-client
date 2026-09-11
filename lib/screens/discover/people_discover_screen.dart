import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/challenge.dart';
import '../../models/discover.dart';
import '../../models/user_profile.dart';
import '../../providers/discover_provider.dart';
import '../../services/api_client.dart';
import '../../services/challenges_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../challenge/challenge_detail_screen.dart';
import '../profile/profile_screen.dart';
import 'category_challenges_screen.dart';

class PeopleDiscoverScreen extends StatefulWidget {
  const PeopleDiscoverScreen({super.key});

  @override
  State<PeopleDiscoverScreen> createState() => _PeopleDiscoverScreenState();
}

class _PeopleDiscoverScreenState extends State<PeopleDiscoverScreen> {
  final _searchController = TextEditingController();
  UserProfile? _profileResult;
  List<Challenge> _challengeResults = [];
  String? _searchError;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscoverProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchError = null;
      _profileResult = null;
      _challengeResults = [];
    });
    UserProfile? profile;
    var challenges = <Challenge>[];
    String? error;
    await Future.wait([
      () async {
        try {
          profile = await context.read<ProfileService>().getProfile(query);
        } on ApiException catch (e) {
          error = e.message;
        }
      }(),
      () async {
        try {
          final results = await context.read<ChallengesService>().list(
            limit: 100,
          );
          final normalized = query.toLowerCase();
          challenges = results.where((challenge) {
            final searchable = [
              challenge.title,
              challenge.shortDescription,
              challenge.fullDescription,
            ].join(' ').toLowerCase();
            return searchable.contains(normalized);
          }).toList();
        } on ApiException catch (e) {
          error ??= e.message;
        }
      }(),
    ]);
    if (!mounted) return;
    setState(() {
      _profileResult = profile;
      _challengeResults = challenges;
      _searchError = profile == null && challenges.isEmpty
          ? error ?? 'No matching results found.'
          : null;
      _isSearching = false;
    });
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

  void _openCategory(DiscoverCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CategoryChallengesScreen(name: category.name, slug: category.slug),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DiscoverProvider>();
    final feed = provider.feed;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: provider.load,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discover',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 18),
                    _SearchField(
                      controller: _searchController,
                      isLoading: _isSearching,
                      onSubmitted: (_) => _search(),
                      onSearch: _search,
                    ),
                    if (_searchError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _searchError!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ],
                    if (_profileResult != null ||
                        _challengeResults.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _SearchResults(
                        profile: _profileResult,
                        challenges: _challengeResults,
                        onProfileTap: (profile) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ProfileScreen(username: profile.username),
                          ),
                        ),
                        onChallengeTap: _openChallenge,
                      ),
                    ],
                    const SizedBox(height: 24),
                    const _SectionHeading('Browse by topic'),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            if (feed.categories.isEmpty)
              const SliverToBoxAdapter(child: _TopicFallback())
            else
              SliverToBoxAdapter(
                child: _TopicRow(
                  categories: feed.categories,
                  onTap: _openCategory,
                ),
              ),
            SliverToBoxAdapter(
              child: _FeedSection(
                title: 'Trending this week',
                onViewAll: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CategoryChallengesScreen(
                      name: 'All challenges',
                      slug: null,
                    ),
                  ),
                ),
                children: feed.trending.isEmpty
                    ? const [
                        _PlaceholderCard(label: 'Challenges are loading up'),
                      ]
                    : feed.trending
                          .take(5)
                          .map(
                            (challenge) => _ChallengeFeatureCard(
                              challenge: challenge,
                              onTap: () => _openChallenge(challenge),
                            ),
                          )
                          .toList(),
              ),
            ),
            const SliverToBoxAdapter(child: _TopNerdsSection()),
            const SliverToBoxAdapter(child: _RecentActivitySection()),
            if (provider.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (provider.errorMessage != null && feed.trending.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearch;
  const _SearchField({
    required this.controller,
    required this.isLoading,
    required this.onSubmitted,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    textInputAction: TextInputAction.search,
    onSubmitted: onSubmitted,
    decoration: InputDecoration(
      hintText: 'Search people or challenges',
      prefixIcon: const Icon(Icons.search),
      suffixIcon: IconButton(
        tooltip: 'Search',
        onPressed: isLoading ? null : onSearch,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward),
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  final String title;
  const _SectionHeading(this.title);
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
  );
}

class _TopicRow extends StatelessWidget {
  final List<DiscoverCategory> categories;
  final ValueChanged<DiscoverCategory> onTap;
  const _TopicRow({required this.categories, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) const SizedBox(width: 9),
            ActionChip(
              onPressed: () => onTap(categories[i]),
              avatar: Text(categories[i].icon),
              label: Text(categories[i].name),
              side: BorderSide(color: colorScheme.outline),
              backgroundColor: colorScheme.surface,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedSection extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;
  final List<Widget> children;
  const _FeedSection({
    required this.title,
    this.onViewAll,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 0, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (onViewAll != null)
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('View all'),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                children[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _ChallengeFeatureCard extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback onTap;
  const _ChallengeFeatureCard({required this.challenge, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    height: 150,
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (challenge.imageUrl != null)
              Image.network(
                challenge.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _ChallengeArtwork(),
              )
            else
              const _ChallengeArtwork(),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 28, 12, 11),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xDD0A0A06)],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '⚡ ${challenge.enrollmentCount ?? 0} joined',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

class _ChallengeArtwork extends StatelessWidget {
  const _ChallengeArtwork();
  @override
  Widget build(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surface,
    child: const Center(
      child: Icon(Icons.auto_awesome, color: AppColors.primary, size: 38),
    ),
  );
}

class _PlaceholderCard extends StatelessWidget {
  final String label;
  const _PlaceholderCard({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    width: 260,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      label,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _TopicFallback extends StatelessWidget {
  const _TopicFallback();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 20),
    child: Wrap(
      spacing: 9,
      children: [
        _FallbackChip(icon: '🧠', label: 'Science'),
        _FallbackChip(icon: '🔧', label: 'Practical'),
        _FallbackChip(icon: '♟️', label: 'Strategy'),
        _FallbackChip(icon: '🎨', label: 'Creative'),
      ],
    ),
  );
}

class _FallbackChip extends StatelessWidget {
  final String icon;
  final String label;
  const _FallbackChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Chip(
    avatar: Text(icon),
    label: Text(label),
    side: BorderSide(color: Theme.of(context).colorScheme.outline),
    backgroundColor: Theme.of(context).colorScheme.surface,
  );
}

class _TopNerdsSection extends StatelessWidget {
  const _TopNerdsSection();
  @override
  Widget build(BuildContext context) => _FeedSection(
    title: 'Top nerds this week',
    children: const [
      _NerdCard(initials: 'JM', name: 'Jamie M.', completed: '12'),
      _NerdCard(initials: 'AK', name: 'Amir K.', completed: '9'),
      _NerdCard(initials: 'RT', name: 'Rae T.', completed: '8'),
    ],
  );
}

class _NerdCard extends StatelessWidget {
  final String initials;
  final String name;
  final String completed;
  const _NerdCard({
    required this.initials,
    required this.name,
    required this.completed,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: 100,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: Theme.of(context).colorScheme.onSurface,
          child: Text(
            initials,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '🔥 $completed done',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection();

  @override
  Widget build(BuildContext context) {
    const activity = [
      ('SL', 'Sam L.', 'finished', 'Handstand Hold'),
      ('JM', 'Jamie M.', 'joined', '500 Chess Openings'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent activity',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final item in activity)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: Theme.of(context).colorScheme.onSurface,
                      child: Text(
                        item.$1,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: item.$2,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: ' just ${item.$3} '),
                            TextSpan(
                              text: item.$4,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final UserProfile? profile;
  final List<Challenge> challenges;
  final ValueChanged<UserProfile> onProfileTap;
  final ValueChanged<Challenge> onChallengeTap;
  const _SearchResults({
    required this.profile,
    required this.challenges,
    required this.onProfileTap,
    required this.onChallengeTap,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (profile != null)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundImage: profile!.avatarUrl != null
                ? NetworkImage(profile!.avatarUrl!)
                : null,
            child: profile!.avatarUrl == null
                ? const Icon(Icons.person_outline)
                : null,
          ),
          title: Text(profile!.name ?? profile!.username ?? 'NerdMaxxer'),
          subtitle: Text('@${profile!.username ?? 'profile'}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onProfileTap(profile!),
        ),
      for (final challenge in challenges.take(3))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.auto_awesome),
          title: Text(
            challenge.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onChallengeTap(challenge),
        ),
    ],
  );
}
