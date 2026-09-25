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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 60,
        titleSpacing: 20,
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: RichText(
          text: TextSpan(
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
            ),
            children: const [
              TextSpan(text: 'NERD'),
              TextSpan(
                text: 'MAXXING',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: provider.load,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discover',
                      style: const TextStyle(
                        fontSize: 44,
                        height: .98,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.8,
                      ),
                    ),
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 38),
                    const _SectionHeading('Browse by topic'),
                    const SizedBox(height: 18),
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
              child: _TrendingSection(
                challenge: feed.featured ??
                    (feed.trending.isEmpty ? null : feed.trending.first),
                onTap: (challenge) => _openChallenge(challenge),
                onViewAll: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CategoryChallengesScreen(
                      name: 'All challenges',
                      slug: null,
                    ),
                  ),
                ),
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outline)),
      ),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.search, color: colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                hintText: 'Search people or challenges',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Search',
            onPressed: isLoading ? null : onSearch,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            icon: isLoading
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.arrow_forward, color: colorScheme.onSurfaceVariant, size: 18),
          ),
        ],
      ),
    );
  }
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
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTap(categories[i]),
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 168),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outline),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: colorScheme.outline),
                        ),
                        child: Text(categories[i].icon),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        categories[i].name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendingSection extends StatelessWidget {
  final Challenge? challenge;
  final ValueChanged<Challenge> onTap;
  final VoidCallback onViewAll;

  const _TrendingSection({
    required this.challenge,
    required this.onTap,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 38, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Expanded(
                child: _SectionHeading('Trending this week'),
              ),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (challenge == null)
            const _PlaceholderCard(label: 'Challenges are loading up')
          else
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTap(challenge!),
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outline),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 190,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (challenge!.imageUrl != null)
                              Image.network(
                                challenge!.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const _ChallengeArtwork(),
                              )
                            else
                              const _ChallengeArtwork(),
                            Positioned(
                              top: 16,
                              left: 16,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  child: Text(
                                    '#1 TRENDING',
                                    style: TextStyle(
                                      color: AppColors.dark,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              challenge!.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 25,
                                height: 1.06,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(height: 1, color: colorScheme.outline),
                            const SizedBox(height: 13),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${challenge!.enrollmentCount ?? 0} nerds joined',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${challenge!.auraPoints} aura',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const nerds = [
      ('JM', 'Jamie M.', '12', 'on a 6-day streak'),
      ('AK', 'Amir K.', '9', 'on a 3-day streak'),
      ('RT', 'Rae T.', '8', 'on a 2-day streak'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 38, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading('Top nerds this week'),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Column(
              children: [
                for (var i = 0; i < nerds.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colorScheme.outline),
                  _LeaderboardRow(
                    rank: i + 1,
                    initials: nerds[i].$1,
                    name: nerds[i].$2,
                    completed: nerds[i].$3,
                    detail: nerds[i].$4,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final String initials;
  final String name;
  final String completed;
  final String detail;

  const _LeaderboardRow({
    required this.rank,
    required this.initials,
    required this.name,
    required this.completed,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlight = rank == 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              rank.toString().padLeft(2, '0'),
              style: TextStyle(
                color: highlight ? AppColors.primary : colorScheme.onSurfaceVariant,
                fontSize: 18,
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
                color: highlight ? AppColors.primary : colorScheme.outline,
              ),
            ),
            child: Text(
              initials,
              style: TextStyle(
                color: highlight ? AppColors.primary : colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                completed,
                style: TextStyle(
                  color: highlight ? AppColors.primary : colorScheme.onSurface,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'DONE',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 9, letterSpacing: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
      padding: const EdgeInsets.fromLTRB(20, 38, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading('Recent activity'),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Column(
              children: [
                for (final item in activity)
                  _ActivityRow(
                    initials: item.$1,
                    name: item.$2,
                    action: item.$3,
                    subject: item.$4,
                    isLast: item == activity.last,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String initials;
  final String name;
  final String action;
  final String subject;
  final bool isLast;

  const _ActivityRow({
    required this.initials,
    required this.name,
    required this.action,
    required this.subject,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: colorScheme.outline)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.outline),
            ),
            child: Text(initials, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: ' just $action '),
                  TextSpan(text: subject, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Text('now', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10)),
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
