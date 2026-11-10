import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, ChangeNotifierProvider, Consumer;

import '../../models/challenge.dart';
import '../../models/group.dart';
import '../../models/participation.dart';
import '../../models/user_profile.dart';
import '../../models/user_stats.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_state_providers.dart';
import '../../providers/profile_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/challenges_service.dart';
import '../../services/groups_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/app_error.dart';
import '../../widgets/privacy_policy_dialog.dart';
import '../challenge/challenge_detail_screen.dart';
import 'group_chat_screen.dart';
import '../auth/password_setup_screen.dart';
import 'relationship_list_screen.dart';
import 'update_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String? username;
  const ProfileScreen({super.key, this.username});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ProfileProvider(context.read<ProfileService>()),
      child: _ProfileScreen(username: username),
    );
  }
}

class _ProfileScreen extends ConsumerStatefulWidget {
  final String? username;
  const _ProfileScreen({this.username});

  @override
  ConsumerState<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<_ProfileScreen> {
  bool _isSigningOut = false;
  bool _isDeletingAccount = false;
  bool _isFollowBusy = false;
  int _selectedTab = 0;
  Map<String, Challenge> _challengesById = {};
  List<Group> _myGroups = [];
  List<Group> _publicGroups = [];
  bool _groupsLoading = false;
  String? _groupsError;
  String _participationFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final username = widget.username ?? auth.username;
    if (username != null && username.isNotEmpty) {
      final isOwnProfile = widget.username == null || username == auth.username;
      final challengesService = context.read<ChallengesService>();
      final groupsService = context.read<GroupsService>();
      if (isOwnProfile) ref.invalidate(myCompletedChallengesProvider);
      await Future.wait([
        context.read<ProfileProvider>().load(
          username,
          isOwnProfile: isOwnProfile,
        ),
        if (isOwnProfile)
          ref.read(participationControllerProvider.notifier).refresh(),
      ]);
      if (isOwnProfile) {
        await _loadOwnGroups(groupsService);
      } else if (mounted) {
        setState(() {
          _myGroups = context.read<ProfileProvider>().profile?.groups ?? [];
          _publicGroups = [];
          _groupsError = null;
        });
      }
      if (isOwnProfile) {
        try {
          final challenges = await challengesService.list(limit: 100);
          if (!mounted) return;
          setState(() {
            _challengesById = {
              for (final challenge in challenges) challenge.id: challenge,
            };
          });
        } catch (_) {
          // Participation cards still show their IDs if the catalog is unavailable.
        }
      }
    }
  }

  Future<void> _loadOwnGroups(GroupsService service) async {
    if (mounted) setState(() => _groupsLoading = true);
    try {
      final results = await Future.wait([
        service.listMine(),
        service.listPublic(limit: 100),
      ]);
      if (!mounted) return;
      setState(() {
        _myGroups = results[0];
        _publicGroups = results[1];
        _groupsError = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _groupsError = e.message);
    } finally {
      if (mounted) setState(() => _groupsLoading = false);
    }
  }

  Future<void> _createGroup() async {
    final draft = await showDialog<_GroupDraft>(
      context: context,
      builder: (dialogContext) => Theme(
        data: AppTheme.neutralActionTheme(Theme.of(dialogContext)),
        child: const _CreateGroupDialog(),
      ),
    );
    if (draft == null || !mounted) return;
    try {
      final group = await context.read<GroupsService>().create(
        name: draft.name,
        description: draft.description,
        visibility: draft.visibility,
      );
      if (!mounted) return;
      setState(() {
        _myGroups = [group, ..._myGroups];
        _publicGroups = [group, ..._publicGroups];
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      AppErrorSnackbar.show(context, e);
    }
  }

  Future<void> _joinGroup(Group group) async {
    try {
      await context.read<GroupsService>().join(group.id);
      if (!mounted) return;
      setState(() {
        _myGroups = [group, ..._myGroups.where((item) => item.id != group.id)];
        _publicGroups = _publicGroups
            .map(
              (item) => item.id == group.id
                  ? Group(
                      id: item.id,
                      name: item.name,
                      description: item.description,
                      visibility: item.visibility,
                      creatorId: item.creatorId,
                      memberCount: item.memberCount + 1,
                      membershipStatus: 'ACTIVE',
                      createdAt: item.createdAt,
                    )
                  : item,
            )
            .toList();
      });
    } on ApiException catch (e) {
      if (mounted) {
        AppErrorSnackbar.show(context, e);
      }
    }
  }

  Future<void> _leaveGroup(Group group) async {
    try {
      await context.read<GroupsService>().leave(group.id);
      if (mounted) {
        setState(() => _myGroups.removeWhere((item) => item.id == group.id));
      }
    } on ApiException catch (e) {
      if (mounted) {
        AppErrorSnackbar.show(context, e);
      }
    }
  }

  void _openGroup(Group group) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)));
  }

  bool _isOwnProfile(AuthProvider auth) =>
      widget.username == null || widget.username == auth.username;

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: AppTheme.neutralActionTheme(Theme.of(context)),
        child: AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to access your account.',
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
        ),
      ),
    );

    if (shouldLogout != true || !mounted) return;
    setState(() => _isSigningOut = true);
    await context.read<AuthProvider>().signOut();
  }

  Future<void> _confirmDeleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: AppTheme.neutralActionTheme(Theme.of(context)),
        child: AlertDialog(
        title: const Text('Delete account permanently?'),
        content: const Text(
          'This permanently deletes your account, sessions, owned challenges, '
          'groups, and associated records. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete account'),
          ),
        ],
        ),
      ),
    );

    if (shouldDelete != true || !mounted) return;
    setState(() => _isDeletingAccount = true);
    try {
      await context.read<AuthProvider>().deleteAccount();
    } on ApiException catch (error) {
      if (mounted) AppErrorSnackbar.show(context, error);
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

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
      case 'COMPLETED':
        return 'Completed';
      default:
        return status;
    }
  }

  Future<void> _changeStatus(Participation participation, String status) async {
    try {
      await ref
          .read(participationControllerProvider.notifier)
          .updateStatus(participation.id, status);
    } on ApiException catch (e) {
      if (!mounted) return;
      AppErrorSnackbar.show(context, e);
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowBusy) return;
    setState(() => _isFollowBusy = true);
    try {
      await context.read<ProfileProvider>().toggleFollow();
    } on ApiException catch (e) {
      if (!mounted) return;
      AppErrorSnackbar.show(context, e);
    } finally {
      if (mounted) setState(() => _isFollowBusy = false);
    }
  }

  Future<void> _showAccountMenu(UserProfile profile) async {
    late final bool hasPassword;
    try {
      hasPassword = await context.read<AuthService>().hasPassword();
    } on ApiException catch (error) {
      if (mounted) AppErrorSnackbar.show(context, error);
      return;
    }
    if (!mounted) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Theme(
        data: AppTheme.neutralActionTheme(Theme.of(sheetContext)),
        child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Update profile'),
                onTap: () => Navigator.pop(sheetContext, 'update'),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline_rounded),
                title: Text(
                  hasPassword ? 'Update password' : 'Set up password',
                ),
                onTap: () => Navigator.pop(sheetContext, 'password'),
              ),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return SwitchListTile.adaptive(
                    secondary: Icon(
                      Icons.brightness_6_rounded,
                      color: colorScheme.onSurface,
                    ),
                    title: const Text('Dark theme'),
                    value: themeProvider.isDark,
                    onChanged: themeProvider.setDark,
                    activeThumbColor: colorScheme.surface,
                    activeTrackColor: colorScheme.onSurface,
                    inactiveThumbColor: colorScheme.onSurfaceVariant,
                    inactiveTrackColor: colorScheme.surfaceContainerHighest,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy policy'),
                onTap: () => Navigator.pop(sheetContext, 'privacy'),
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Log out'),
                onTap: () => Navigator.pop(sheetContext, 'logout'),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
                title: Text(
                  'Delete account',
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.error,
                  ),
                ),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'update') {
      _openUpdateProfile(profile);
    } else if (action == 'password') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              PasswordSetupScreen(hasPassword: hasPassword, canSkip: false),
        ),
      );
    } else if (action == 'privacy') {
      await showPrivacyPolicyDialog(context);
    } else if (action == 'logout') {
      _confirmLogout();
    } else if (action == 'delete') {
      _confirmDeleteAccount();
    }
  }

  void _openUpdateProfile(UserProfile profile) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => UpdateProfileScreen(profile: profile),
          ),
        )
        .then((updated) {
          if (updated == true && mounted) _load();
        });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final participationState = ref.watch(participationControllerProvider);
    final participations = participationState.valueOrNull ?? const [];
    final activeParticipations = participations
        .where((participation) => !participation.isCompleted)
        .toList();
    final filteredParticipations = _participationFilter == 'ALL'
        ? activeParticipations
        : activeParticipations
              .where(
                (participation) =>
                    participation.status.toUpperCase() == _participationFilter,
              )
              .toList();
    final participationEmptyMessage = _participationFilter == 'ALL'
        ? 'Discover a challenge and accept it to get started.'
        : 'No challenges match this status filter.';
    final auth = context.watch<AuthProvider>();
    final profile = provider.profile;
    final isOwnProfile = _isOwnProfile(auth);
    final ownStats = isOwnProfile ? ref.watch(myStatsProvider).valueOrNull : null;
    final completedChallenges = isOwnProfile
        ? ref.watch(myCompletedChallengesProvider).valueOrNull ?? const []
        : provider.completedChallenges;
    final createdChallenges = isOwnProfile
        ? ref.watch(myCreatedChallengesProvider).valueOrNull ?? const []
        : provider.createdChallenges;

    if (provider.isLoading && profile == null) {
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: _load,
          child: _RefreshableState(child: const CircularProgressIndicator()),
        ),
      );
    }
    if (provider.errorMessage != null && profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _RefreshableState(
            child: AppErrorView(error: provider.errorMessage!, onRetry: _load),
          ),
        ),
      );
    }
    if (profile == null) {
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: _load,
          child: const _RefreshableState(child: Text('Profile unavailable')),
        ),
      );
    }

    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: HomePalette.background(brightness),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        color: Theme.of(context).colorScheme.onSurface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: 44,
              title: Text(
                profile.name ?? profile.username ?? 'Profile',
                style: AppFonts.home(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              centerTitle: true,
              floating: true,
              backgroundColor: HomePalette.background(brightness),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              actions: [
                if (_isOwnProfile(auth))
                  IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    tooltip: 'Account options',
                    style: IconButton.styleFrom(
                      fixedSize: const Size(34, 34),
                      padding: EdgeInsets.zero,
                      backgroundColor: HomePalette.surfaceAlt(brightness),
                      side: BorderSide(color: HomePalette.border(brightness)),
                      shape: const CircleBorder(),
                    ),
                    onPressed: _isSigningOut || _isDeletingAccount
                        ? null
                        : () => _showAccountMenu(profile),
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: _ProfileHeader(
                profile: profile,
                auraPoints: ownStats?.auraPoints ?? profile.auraPoints,
                onFollowersTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RelationshipListScreen(
                      userId: profile.id,
                      type: RelationshipType.followers,
                    ),
                  ),
                ),
                onFollowingTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RelationshipListScreen(
                      userId: profile.id,
                      type: RelationshipType.following,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _ProfileActions(
                profile: profile,
                isOwnProfile: isOwnProfile,
                isFollowBusy: _isFollowBusy,
                onEdit: () => _openUpdateProfile(profile),
                onToggleFollow: _toggleFollow,
              ),
            ),
            SliverToBoxAdapter(
              child: _ProfileTabs(
                selectedIndex: _selectedTab,
                showRewards: isOwnProfile,
                onSelected: (index) => setState(() => _selectedTab = index),
              ),
            ),
            if (_selectedTab == 0) ...[
              if (isOwnProfile) ...[
                SliverToBoxAdapter(
                  child: _ParticipationFilters(
                    selected: _participationFilter,
                    onSelected: (filter) =>
                        setState(() => _participationFilter = filter),
                  ),
                ),
                if (participationState.isLoading && participations.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (filteredParticipations.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.flag_rounded,
                      title: 'Your next interesting thing is waiting.',
                      message: participationEmptyMessage,
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ParticipationTile(
                        participation: filteredParticipations[index],
                        challenge:
                            _challengesById[filteredParticipations[index]
                                .challengeId],
                        statusLabel: _statusLabel(
                          filteredParticipations[index].isCompleted
                              ? 'COMPLETED'
                              : filteredParticipations[index].status,
                        ),
                        onChangeStatus: _changeStatus,
                      ),
                      childCount: filteredParticipations.length,
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _SectionLabel('Created by you'),
                ),
                if (createdChallenges.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(26, 0, 26, 12),
                      child: CustomPaint(
                        painter: _DashedBorderPainter(
                          color: brightness == Brightness.dark
                              ? HomePalette.darkBorderStrong
                              : const Color(0xFFCFCFC4),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  'No challenges yet',
                                  style: AppFonts.home(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Create your own and invite nerds to it.',
                                  textAlign: TextAlign.center,
                                  style: AppFonts.home(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _CreatedChallengeTile(
                        challenge: createdChallenges[index],
                      ),
                      childCount: createdChallenges.length,
                    ),
                  ),
              ],
              SliverToBoxAdapter(
                child: _SectionLabel('Completed'),
              ),
              if (completedChallenges.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No completed challenges yet.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final challenge = completedChallenges[index];
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _CompletedChallengeCard(
                          challenge: challenge,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChallengeDetailScreen(
                                slug: challenge.slug,
                                initialChallenge: challenge,
                              ),
                            ),
                          ),
                        ),
                      );
                    }, childCount: completedChallenges.length),
                  ),
                ),
            ],
            if (_selectedTab == 1)
              SliverToBoxAdapter(
                child: _GroupsPanel(
                  isOwnProfile: isOwnProfile,
                  groups: isOwnProfile ? _myGroups : profile.groups,
                  publicGroups: _publicGroups,
                  isLoading: _groupsLoading,
                  errorMessage: _groupsError,
                  onCreate: isOwnProfile ? _createGroup : null,
                  onJoin: isOwnProfile ? _joinGroup : null,
                  onLeave: isOwnProfile ? _leaveGroup : null,
                  onOpenGroup: _openGroup,
                ),
              )
            else if (_selectedTab == 2 && isOwnProfile)
              SliverToBoxAdapter(
                child: const _RewardsPanel(),
              )
            else if (_selectedTab != 0)
              const SliverToBoxAdapter(child: SizedBox.shrink()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _ProfileTabs extends StatelessWidget {
  final int selectedIndex;
  final bool showRewards;
  final ValueChanged<int> onSelected;

  const _ProfileTabs({
    required this.selectedIndex,
    required this.showRewards,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tabs = [
      (Icons.flag_rounded, 'Challenges'),
      (Icons.groups_rounded, 'Groups'),
      if (showRewards) (Icons.emoji_events_rounded, 'Rewards'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        children: [
          for (var index = 0; index < tabs.length; index++)
            Expanded(
              child: InkWell(
                onTap: () => onSelected(index),
                child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selectedIndex == index
                            ? HomePalette.primary
                            : HomePalette.border(Theme.of(context).brightness),
                        width: selectedIndex == index ? 3 : 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tabs[index].$1,
                        size: 20,
                          color: selectedIndex == index
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tabs[index].$2,
                        style: AppFonts.home(
                          color: selectedIndex == index
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
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
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final String? count;

  const _SectionLabel(this.text, {this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text.toUpperCase(),
            style: AppFonts.home(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacingEm: 0.14,
            ),
          ),
          if (count != null)
            Text(
              count!,
              style: AppFonts.home(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileActions extends StatelessWidget {
  final UserProfile profile;
  final bool isOwnProfile;
  final bool isFollowBusy;
  final VoidCallback onEdit;
  final VoidCallback onToggleFollow;

  const _ProfileActions({
    required this.profile,
    required this.isOwnProfile,
    required this.isFollowBusy,
    required this.onEdit,
    required this.onToggleFollow,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    const shape = StadiumBorder();
    final spinner = SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onSurface),
    );

    final Widget primary = isOwnProfile
        ? FilledButton(
            onPressed: onEdit,
            style: FilledButton.styleFrom(
              backgroundColor: HomePalette.primary,
              foregroundColor: HomePalette.ink,
              shape: shape,
              padding: const EdgeInsets.symmetric(vertical: 15),
              textStyle: AppFonts.home(
                color: HomePalette.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Edit profile'),
          )
        : profile.isFollowing
        ? OutlinedButton(
            onPressed: isFollowBusy ? null : onToggleFollow,
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.onSurface,
              shape: shape,
              padding: const EdgeInsets.symmetric(vertical: 15),
              textStyle: AppFonts.home(
                color: scheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: isFollowBusy ? spinner : const Text('Following'),
          )
        : FilledButton(
            onPressed: isFollowBusy ? null : onToggleFollow,
            style: FilledButton.styleFrom(
              backgroundColor: HomePalette.primary,
              foregroundColor: HomePalette.ink,
              shape: shape,
              padding: const EdgeInsets.symmetric(vertical: 15),
              textStyle: AppFonts.home(
                color: HomePalette.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: isFollowBusy ? spinner : const Text('Follow'),
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 16, 26, 0),
      child: Row(
        children: [
          Expanded(child: primary),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                disabledForegroundColor: scheme.onSurface,
                shape: shape,
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: BorderSide(
                  color: HomePalette.border(Theme.of(context).brightness),
                ),
                textStyle: AppFonts.home(
                  color: scheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text('Rank ${profile.rank}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupDraft {
  final String name;
  final String? description;
  final String visibility;

  const _GroupDraft({
    required this.name,
    required this.description,
    required this.visibility,
  });
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _visibility = 'PUBLIC';

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      _GroupDraft(
        name: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        visibility: _visibility,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create group'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _descriptionController,
              maxLength: 2000,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              decoration: const InputDecoration(labelText: 'Visibility'),
              items: const [
                DropdownMenuItem(value: 'PUBLIC', child: Text('Public')),
                DropdownMenuItem(value: 'PRIVATE', child: Text('Private')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _visibility = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

class _GroupsPanel extends StatelessWidget {
  final bool isOwnProfile;
  final List<Group> groups;
  final List<Group> publicGroups;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onCreate;
  final Future<void> Function(Group group)? onJoin;
  final Future<void> Function(Group group)? onLeave;
  final ValueChanged<Group> onOpenGroup;

  const _GroupsPanel({
    required this.isOwnProfile,
    required this.groups,
    required this.publicGroups,
    required this.isLoading,
    required this.errorMessage,
    this.onCreate,
    this.onJoin,
    this.onLeave,
    required this.onOpenGroup,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sectionStyle = AppFonts.home(
      color: scheme.onSurfaceVariant,
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 8),
        child: Text(errorMessage!),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 22, 26, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isOwnProfile ? 'YOUR GROUPS' : 'GROUPS',
                  style: AppFonts.home(
                    color: scheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onCreate != null)
                TextButton(
                  onPressed: onCreate,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    side: BorderSide(color: scheme.outlineVariant),
                    shape: const StadiumBorder(),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    'Create',
                    style: AppFonts.home(
                      color: scheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (groups.isEmpty)
          _GroupEmptyState(
            title: isOwnProfile ? 'Your group story starts here.' : 'No groups yet.',
            message: isOwnProfile
                ? 'Join a crew and make small adventures together.'
                : 'This profile has not joined a group yet.',
          )
        else
          ...groups.map(
            (group) => _GroupTile(
              group: group,
              onLeave: onLeave,
              onTap: () => onOpenGroup(group),
            ),
          ),
        if (isOwnProfile) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 28, 26, 12),
            child: Text('FIND YOUR PEOPLE', style: sectionStyle),
          ),
          if (publicGroups.isEmpty)
            _GroupEmptyState(
              title: 'Small adventures are better together.',
              message: 'Explore public groups to find your next curious crew.',
            )
          else
            ...publicGroups.map(
              (group) => _GroupTile(
                group: group,
                onJoin: onJoin,
                onLeave: onLeave,
                onTap: group.membershipStatus == 'ACTIVE'
                    ? () => onOpenGroup(group)
                    : null,
              ),
            ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _GroupTile extends StatelessWidget {
  final Group group;
  final Future<void> Function(Group group)? onJoin;
  final Future<void> Function(Group group)? onLeave;
  final VoidCallback? onTap;

  const _GroupTile({
    required this.group,
    this.onJoin,
    this.onLeave,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMember = group.membershipStatus == 'ACTIVE';
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 12),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surface,
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
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: HomePalette.surfaceAlt(brightness),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    group.visibility.toUpperCase() == 'PRIVATE'
                        ? Icons.shield_outlined
                        : Icons.groups_rounded,
                    size: 26,
                    color: brightness == Brightness.light
                        ? HomePalette.lightLink
                        : HomePalette.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.home(
                          color: scheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${group.memberCount} ${group.memberCount == 1 ? 'member' : 'members'} · ${group.visibility.toLowerCase() == 'private' ? 'Private' : 'Public'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.home(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onJoin != null && !isMember)
                  _ProfileRowAction(
                    label: 'Join',
                    onPressed: () => onJoin!(group),
                  )
                else if (isMember && onLeave != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onTap != null)
                        _ProfileRowAction(label: 'Open', onPressed: onTap!),
                      PopupMenuButton<String>(
                        tooltip: 'Group options',
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_horiz_rounded, size: 20),
                        onSelected: (value) {
                          if (value == 'leave') onLeave!(group);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'leave',
                            child: Text('Leave group'),
                          ),
                        ],
                      ),
                    ],
                  )
                else if (onTap != null)
                  _ProfileRowAction(label: 'Open', onPressed: onTap!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupEmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _GroupEmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 12, 26, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppFonts.home(
                color: scheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: AppFonts.home(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardsPanel extends StatelessWidget {
  const _RewardsPanel();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          'Coming soon',
          style: AppFonts.home(color: scheme.onSurfaceVariant, fontSize: 14),
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

class _DashedBorderPainter extends CustomPainter {
  final Color color;

  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(.75, .75, size.width - 1.5, size.height - 1.5),
          const Radius.circular(20),
        ),
      );
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 8) {
        final end = start + 5 < metric.length ? start + 5 : metric.length;
        canvas.drawPath(metric.extractPath(start, end), border);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ProfileHeader extends StatelessWidget {
  final UserProfile profile;
  final int auraPoints;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  const _ProfileHeader({
    required this.profile,
    required this.auraPoints,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final displayName = profile.name ?? profile.username ?? 'Nerd';
    final initial = displayName.trim().characters.firstOrNull?.toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 14, 26, 0),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB04AE0), Color(0xFF6A2A9A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: HomePalette.primary, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: isLight
                          ? HomePalette.lightPrimaryMuted
                          : HomePalette.darkPrimaryMuted,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.transparent,
                  backgroundImage: profile.avatarUrl != null
                      ? NetworkImage(profile.avatarUrl!)
                      : null,
                  child: profile.avatarUrl == null
                      ? Text(
                          initial ?? '?',
                          style: AppFonts.home(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HomePalette.ink,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                  child: Text(
                    profile.rank,
                    style: AppFonts.home(
                      color: HomePalette.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (profile.username != null) ...[
            const SizedBox(height: 16),
            Text(
              '@${profile.username}',
              style: AppFonts.home(
                color: scheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          ],
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              profile.bio!,
              textAlign: TextAlign.center,
              style: AppFonts.home(
                color: scheme.onSurfaceVariant,
                fontSize: 14.5,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: isLight
                  ? HomePalette.lightSurfaceAlt
                  : HomePalette.darkSurfaceAlt,
              border: Border.all(
                color: isLight
                    ? HomePalette.lightBorder
                    : HomePalette.darkBorder,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: '$auraPoints',
                    label: 'Aura',
                    valueColor: isLight
                      ? HomePalette.lightLink
                      : HomePalette.primary,
                  ),
                ),
                _statDivider(scheme),
                Expanded(
                  child: _Stat(
                    value: '${profile.followerCount}',
                    label: 'Followers',
                    onTap: onFollowersTap,
                  ),
                ),
                _statDivider(scheme),
                Expanded(
                  child: _Stat(
                    value: '${profile.followingCount}',
                    label: 'Following',
                    onTap: onFollowingTap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider(ColorScheme scheme) => Container(
    width: 1,
    height: 66,
    color: scheme.outlineVariant,
  );
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;
  final Color? valueColor;

  const _Stat({
    required this.value,
    required this.label,
    this.onTap,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: AppFonts.home(
                  color: valueColor ?? scheme.onSurface,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                style: AppFonts.home(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback onTap;

  const _CompletedChallengeCard({
    required this.challenge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final title = challenge.title.toLowerCase();
    final isChess = title.contains('chess');
    final isRubiks = title.contains('rubik');
    final isSudoku = title.contains('sudoku');
    final difficulty = challenge.difficultyLevel
        .toLowerCase()
        .split('_')
        .map(
          (word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
    final difficultyColor = switch (difficulty.toLowerCase()) {
      'beginner' => HomePalette.primary,
      'intermediate' => const Color(0xFFFFAB3D),
      'advanced' => const Color(0xFFFF6B57),
      _ => HomePalette.primary,
    };

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _CompletedChallengeCover(
                challenge: challenge,
                isLight: isLight,
                isChess: isChess,
                isRubiks: isRubiks,
                isSudoku: isSudoku,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xB30F0F0E)],
                    stops: [0.55, 1],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: HomePalette.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 17,
                    color: HomePalette.ink,
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: difficultyColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: HomePalette.ink,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            difficulty,
                            style: AppFonts.home(
                              color: HomePalette.ink,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      challenge.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.home(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: .85),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          challenge.effortLabel,
                          style: AppFonts.home(
                            color: Colors.white.withValues(alpha: .85),
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.bolt_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: .85),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${challenge.auraPoints}',
                          style: AppFonts.home(
                            color: Colors.white.withValues(alpha: .85),
                            fontSize: 12.5,
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
    );
  }
}

class _CompletedChallengeCover extends StatelessWidget {
  final Challenge challenge;
  final bool isLight;
  final bool isChess;
  final bool isRubiks;
  final bool isSudoku;

  const _CompletedChallengeCover({
    required this.challenge,
    required this.isLight,
    required this.isChess,
    required this.isRubiks,
    required this.isSudoku,
  });

  @override
  Widget build(BuildContext context) {
      final colors = isRubiks
        ? const [Color(0xFFD6C43A), Color(0xFF403A08)]
        : isSudoku
      ? const [Color(0xFF3AA57A), Color(0xFF0F3324)]
      : isChess
      ? (isLight
        ? const [Color(0xFFF3DFC5), Color(0xFFD0E7DC)]
        : const [Color(0xFF443019), Color(0xFF25403B)])
      : HomePalette.challengeGradient(challenge.title);
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: isRubiks || isSudoku
            ? RadialGradient(
                center: isRubiks
                    ? const Alignment(-.2, -.4)
                    : const Alignment(.4, -.4),
                radius: .95,
                colors: colors,
              )
            : LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: _CompletedCoverArtwork(
              isChess: isChess,
              isLight: isLight,
            ),
          ),
        ],
      ),
    );

    if (challenge.imageUrl == null || challenge.imageUrl!.trim().isEmpty) {
      return fallback;
    }
    return Image.network(
      challenge.imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

class _CompletedCoverArtwork extends StatelessWidget {
  final bool isChess;
  final bool isLight;

  const _CompletedCoverArtwork({required this.isChess, required this.isLight});

  @override
  Widget build(BuildContext context) {
    if (isChess) {
      return Text(
        '♞',
        style: TextStyle(
          color: isLight ? const Color(0xFF273830) : const Color(0xFFF4E3BF),
          fontFamily: 'Georgia',
          fontSize: 65,
          height: 1,
          shadows: const [
            Shadow(color: Color(0x55000000), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
      );
    }

    const tileColors = [
      Color(0xFFE44335),
      Color(0xFFFFCF38),
      Color(0xFFF7F5EB),
      Color(0xFF2778CF),
      Color(0xFF38AD68),
      Color(0xFFFFCF38),
      Color(0xFFE44335),
      Color(0xFFF7F5EB),
      Color(0xFF2778CF),
    ];
    return Transform.rotate(
      angle: -.14,
      child: Container(
        width: 102,
        height: 102,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: const Color(0xFF11130F),
          border: Border.all(color: const Color(0xFF11130F), width: 5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Color(0x55000000), blurRadius: 25, offset: Offset(0, 15)),
          ],
        ),
        child: GridView.count(
          crossAxisCount: 3,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
          children: [
            for (final color in tileColors)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ParticipationTile extends StatelessWidget {
  final Participation participation;
  final Challenge? challenge;
  final String statusLabel;
  final Future<void> Function(Participation participation, String status)
  onChangeStatus;

  const _ParticipationTile({
    required this.participation,
    required this.challenge,
    required this.statusLabel,
    required this.onChangeStatus,
  });

  @override
  Widget build(BuildContext context) {
    final challengeId = participation.challengeId;
    final shortId = challengeId.length > 6
        ? challengeId.substring(0, 6)
        : challengeId;
    final scheme = Theme.of(context).colorScheme;
    final actionLabel = switch (participation.status) {
      'ACCEPTED' => ('Start', 'IN_PROGRESS'),
      'IN_PROGRESS' => ('Pause', 'PAUSED'),
      'PAUSED' => ('Resume', 'IN_PROGRESS'),
      _ => null,
    };
    return _RowCard(
      challenge: challenge,
      onTap: challenge == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChallengeDetailScreen(
                  slug: challenge!.slug,
                  initialChallenge: challenge,
                ),
              ),
            ),
      leadingIcon: Icons.flag_rounded,
            leadingColor: scheme.surfaceContainerHighest,
      title:
          challenge?.title ??
          'Challenge $shortId${challengeId.length > 6 ? '...' : ''}',
      subtitle: statusLabel,
      trailing: actionLabel == null
          ? null
          : _ProfileRowAction(
              label: actionLabel.$1,
              primary: actionLabel.$1 == 'Start',
              onPressed: () => onChangeStatus(participation, actionLabel.$2),
            ),
    );
  }
}

class _ParticipationFilters extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _ParticipationFilters({
    required this.selected,
    required this.onSelected,
  });

  static const _filters = [
    ('ALL', 'All'),
    ('ACCEPTED', 'Accepted'),
    ('IN_PROGRESS', 'In progress'),
    ('PAUSED', 'Paused'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(26, 10, 26, 10),
      child: Row(
        children: [
          for (var index = 0; index < _filters.length; index++) ...[
            if (index > 0) const SizedBox(width: 10),
            ChoiceChip(
              label: Text(_filters[index].$2),
              selected: selected == _filters[index].$1,
              showCheckmark: false,
              visualDensity: VisualDensity.standard,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              selectedColor: isLight
                  ? HomePalette.lightPrimaryMuted
                  : HomePalette.darkPrimaryMuted,
              backgroundColor: isLight
                  ? HomePalette.lightSurfaceAlt
                  : HomePalette.darkSurfaceAlt,
              labelStyle: AppFonts.home(
                color: selected == _filters[index].$1
                    ? (isLight ? HomePalette.lightLink : HomePalette.primary)
                    : scheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(
                color: selected == _filters[index].$1
                    ? (isLight
                          ? const Color(0xFFDDEB8A)
                          : Colors.transparent)
                    : HomePalette.border(Theme.of(context).brightness),
              ),
              shape: const StadiumBorder(),
              onSelected: (_) => onSelected(_filters[index].$1),
            ),
          ],
        ],
      ),
    );
  }
}

class _CreatedChallengeTile extends StatelessWidget {
  final Challenge challenge;

  const _CreatedChallengeTile({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final isPrivate = challenge.visibility.toUpperCase() == 'PRIVATE';
    final scheme = Theme.of(context).colorScheme;
    return _RowCard(
      challenge: challenge,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChallengeDetailScreen(
            slug: challenge.slug,
            initialChallenge: challenge,
          ),
        ),
      ),
      leadingIcon: isPrivate ? Icons.lock_rounded : Icons.edit_note_rounded,
      leadingColor: scheme.surfaceContainerHighest,
      leadingIconColor: HomePalette.primary,
      title: challenge.title,
      subtitle:
          '${isPrivate ? 'Private' : 'Public'} · ${challenge.enrollmentCount ?? 0} participants',
      trailing: _ProfileRowAction(
        label: 'View',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChallengeDetailScreen(
              slug: challenge.slug,
              initialChallenge: challenge,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileRowAction extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  const _ProfileRowAction({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = primary
        ? FilledButton.styleFrom(
            backgroundColor: HomePalette.primary,
            foregroundColor: HomePalette.ink,
            minimumSize: const Size(0, 38),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            shape: const StadiumBorder(),
            textStyle: AppFonts.home(
              color: HomePalette.ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            minimumSize: const Size(0, 38),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            side: BorderSide(
              color: HomePalette.border(Theme.of(context).brightness),
            ),
            shape: const StadiumBorder(),
            textStyle: AppFonts.home(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          );
    return primary
        ? FilledButton(onPressed: onPressed, style: style, child: Text(label))
        : OutlinedButton(onPressed: onPressed, style: style, child: Text(label));
  }
}

class _RowCard extends StatelessWidget {
  final Challenge? challenge;
  final VoidCallback? onTap;
  final IconData leadingIcon;
  final Color leadingColor;
  final Color? leadingIconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _RowCard({
    this.challenge,
    required this.onTap,
    required this.leadingIcon,
    required this.leadingColor,
    this.leadingIconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 12),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: HomePalette.border(Theme.of(context).brightness),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: leadingColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: challenge?.imageUrl?.trim().isNotEmpty == true
                      ? Image.network(
                          challenge!.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            leadingIcon,
                            size: 26,
                            color: leadingIconColor ?? scheme.onSurface,
                          ),
                        )
                      : Icon(
                          leadingIcon,
                          size: 26,
                          color: leadingIconColor ?? scheme.onSurface,
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
                          color: scheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppFonts.home(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  final Challenge challenge;
  const _ChallengeTile({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChallengeDetailScreen(slug: challenge.slug),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (challenge.imageUrl != null)
                    Image.network(
                      challenge.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallback(context),
                    )
                  else
                    _fallback(context),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 23,
                      height: 23,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: scheme.onPrimary,
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          challenge.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.home(
                            color: scheme.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 13,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${challenge.auraPoints} aura',
                          style: AppFonts.home(
                            color: scheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) => Container(
    color: Theme.of(context).brightness == Brightness.dark
        ? AppColors.primaryMuted
        : AppColors.limeWash,
    alignment: Alignment.center,
    child: const Icon(
      Icons.flag_rounded,
      color: AppColors.primaryLight,
      size: 28,
    ),
  );
}
