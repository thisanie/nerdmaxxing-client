import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/challenge.dart';
import '../../models/discover.dart';
import '../../providers/discover_provider.dart';
import '../../services/api_client.dart';
import '../../services/discover_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/challenge_section.dart';
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
  Timer? _searchDebounce;
  List<DiscoverUser> _userResults = [];
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
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _search(value);
    });
  }

  Future<void> _search([String? value]) async {
    final query = (value ?? _searchController.text).trim();
    if (query.isEmpty) {
      setState(() {
        _userResults = [];
        _challengeResults = [];
        _searchError = null;
        _isSearching = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _searchError = null;
      _userResults = [];
      _challengeResults = [];
    });
    try {
      final result = await context.read<DiscoverService>().search(query);
      if (!mounted) return;
      if (_searchController.text.trim() != query) return;
      setState(() {
        _userResults = result.users;
        _challengeResults = result.challenges;
        _searchError = result.users.isEmpty && result.challenges.isEmpty
            ? 'No matching results found.'
            : null;
        _isSearching = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (_searchController.text.trim() != query) return;
      setState(() {
        _searchError = e.message;
        _isSearching = false;
      });
    }
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'NERD',
              style: AppFonts.body(
                color: Theme.of(context).colorScheme.onSurface,
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
      ),
      body: RefreshIndicator(
        onRefresh: provider.load,
        color: Theme.of(context).colorScheme.onSurface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discover',
                      style: AppFonts.body(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 38,
                        height: 1.1,
                        fontWeight: FontWeight.w500,
                        letterSpacingEm: -0.02,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _SearchField(
                      controller: _searchController,
                      isLoading: _isSearching,
                      onChanged: _scheduleSearch,
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
                    if (_userResults.isNotEmpty ||
                        _challengeResults.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _SearchResults(
                        users: _userResults,
                        challenges: _challengeResults,
                        onProfileTap: (username) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(username: username),
                          ),
                        ),
                        onChallengeTap: _openChallenge,
                      ),
                    ],
                    const SizedBox(height: 32),
                    const _SectionHeading('Browse by topic'),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            if (feed.categories.isNotEmpty)
              SliverToBoxAdapter(
                child: _TopicRow(
                  categories: feed.categories,
                  onTap: _openCategory,
                ),
              ),
            SliverToBoxAdapter(
              child: _TrendingSection(
                challenge:
                    feed.featured ??
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
            if (feed.recommended.isNotEmpty)
              SliverToBoxAdapter(
                child: ChallengeSection(
                  title: 'Picked for you',
                  challenges: feed.recommended,
                  onChallengeTap: _openChallenge,
                ),
              ),
            if (feed.newChallenges.isNotEmpty)
              SliverToBoxAdapter(
                child: ChallengeSection(
                  title: 'New this week',
                  challenges: feed.newChallenges,
                  onChallengeTap: _openChallenge,
                ),
              ),
            if (feed.legendary.isNotEmpty)
              SliverToBoxAdapter(
                child: ChallengeSection(
                  title: 'Legendary challenges',
                  challenges: feed.legendary,
                  legendary: true,
                  onChallengeTap: _openChallenge,
                ),
              ),
            if (feed.unexpected.isNotEmpty)
              SliverToBoxAdapter(
                child: ChallengeSection(
                  title: 'Try something unexpected',
                  challenges: feed.unexpected,
                  onChallengeTap: _openChallenge,
                ),
              ),
            if (feed.topNerds.isNotEmpty)
              SliverToBoxAdapter(child: _TopNerdsSection(nerds: feed.topNerds)),
            if (feed.recentActivity.isNotEmpty)
              SliverToBoxAdapter(
                child: _RecentActivitySection(activity: feed.recentActivity),
              ),
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
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearch;
  const _SearchField({
    required this.controller,
    required this.isLoading,
    required this.onChanged,
    required this.onSubmitted,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outline),
      ),
      padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: colorScheme.onSurfaceVariant,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Search people or challenges',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Search',
            onPressed: isLoading ? null : onSearch,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: isLoading
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.arrow_forward_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
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
    style: AppFonts.body(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: 22,
      fontWeight: FontWeight.w500,
      letterSpacingEm: -0.01,
    ),
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
              color: colorScheme.surface,
              shape: StadiumBorder(
                side: BorderSide(color: colorScheme.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onTap(categories[i]),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 18, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.limeWash,
                        ),
                        child: const Icon(
                          Icons.category_rounded,
                          color: AppColors.dark,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        categories[i].name,
                        style: AppFonts.body(
                          color: colorScheme.onSurface,
                          fontSize: 16,
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
              const Expanded(child: _SectionHeading('Trending this week')),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? AppColors.primary
                      : const Color(0xFF4F6A0A),
                ),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (challenge == null)
            const _PlaceholderCard(label: 'Challenges are loading up')
          else
            Material(
              color: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: colorScheme.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onTap(challenge!),
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
                              errorBuilder: (_, _, _) =>
                                  const _ChallengeArtwork(),
                            )
                          else
                            const _ChallengeArtwork(),
                          Positioned(
                            top: 16,
                            left: 16,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Text(
                                  '#1 TRENDING',
                                  style: AppFonts.body(
                                    color: AppColors.dark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacingEm: 0.03,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            challenge!.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.body(
                              color: colorScheme.onSurface,
                              fontSize: 24,
                              height: 1.15,
                              fontWeight: FontWeight.w500,
                              letterSpacingEm: -0.01,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(height: 1, color: colorScheme.outline),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${challenge!.enrollmentCount ?? 0} nerds joined',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bolt_rounded,
                                    size: 16,
                                    color: colorScheme.onSurface,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${challenge!.auraPoints} aura',
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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
        ],
      ),
    );
  }
}

class _ChallengeArtwork extends StatelessWidget {
  const _ChallengeArtwork();
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.surfaceAlt : AppColors.limeWash,
      child: Center(
        child: Icon(
          Icons.auto_awesome_rounded,
          color: isDark ? AppColors.primary : AppColors.lightTextPrimary,
          size: 38,
        ),
      ),
    );
  }
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

class _TopNerdsSection extends StatelessWidget {
  final List<DiscoverNerd> nerds;

  const _TopNerdsSection({required this.nerds});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 38, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading('Top nerds this week'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border.all(color: colorScheme.outline),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                for (var i = 0; i < nerds.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colorScheme.outline),
                  _LeaderboardRow(nerd: nerds[i]),
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
  final DiscoverNerd nerd;

  const _LeaderboardRow({required this.nerd});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlight = nerd.rank == 1;
    final accent = Theme.of(context).brightness == Brightness.dark
        ? AppColors.primary
        : const Color(0xFF4F6A0A);
    final name = nerd.displayName ?? nerd.username ?? 'NerdMaxxer';
    final initials = _initials(name);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              nerd.rank.toString().padLeft(2, '0'),
              style: TextStyle(
                color: highlight ? accent : colorScheme.onSurfaceVariant,
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
                color: highlight ? accent : colorScheme.outline,
              ),
            ),
            child: Text(
              initials,
              style: TextStyle(
                color: highlight ? accent : colorScheme.onSurface,
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
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${nerd.dayStreak}-day streak',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${nerd.completedCount}',
                style: TextStyle(
                  color: highlight ? accent : colorScheme.onSurface,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'DONE',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (nerd.username == null || nerd.username!.isEmpty) return row;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfileScreen(username: nerd.username!),
        ),
      ),
      child: row,
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _RecentActivitySection extends StatelessWidget {
  final List<DiscoverActivity> activity;

  const _RecentActivitySection({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 38, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading('Recent activity'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                for (var i = 0; i < activity.length; i++)
                  _ActivityRow(
                    activity: activity[i],
                    isLast: i == activity.length - 1,
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
  final DiscoverActivity activity;
  final bool isLast;

  const _ActivityRow({required this.activity, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = activity.displayName ?? activity.username ?? 'A nerd';
    final subject = activity.challengeTitle ?? 'a challenge';
    final action = _actionLabel(activity.action);
    final initials = _initials(name);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: colorScheme.outline)),
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
            child: Text(
              initials,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' just $action '),
                  TextSpan(
                    text: subject,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _relativeTime(activity.createdAt),
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'JOINED_CHALLENGE':
        return 'joined';
      case 'COMPLETED_CHALLENGE':
        return 'finished';
      case 'STARTED_CHALLENGE':
        return 'started';
      case 'EARNED_AURA':
        return 'earned aura from';
      case 'REACHED_STREAK':
        return 'reached a streak with';
      default:
        return 'updated';
    }
  }

  String _relativeTime(DateTime? value) {
    if (value == null) return '';
    final difference = DateTime.now().toUtc().difference(value.toUtc());
    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    return '${difference.inDays}d';
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _SearchResults extends StatelessWidget {
  final List<DiscoverUser> users;
  final List<Challenge> challenges;
  final ValueChanged<String> onProfileTap;
  final ValueChanged<Challenge> onChallengeTap;
  const _SearchResults({
    required this.users,
    required this.challenges,
    required this.onProfileTap,
    required this.onChallengeTap,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final user in users.take(3))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? const Icon(Icons.person_rounded)
                : null,
          ),
          title: Text(user.displayName ?? user.username ?? 'NerdMaxxer'),
          subtitle: Text('@${user.username ?? 'profile'}'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: user.username == null
              ? null
              : () => onProfileTap(user.username!),
        ),
      for (final challenge in challenges.take(3))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.auto_awesome_rounded),
          title: Text(
            challenge.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => onChallengeTap(challenge),
        ),
    ],
  );
}
