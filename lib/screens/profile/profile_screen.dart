import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/challenge.dart';
import '../../models/group.dart';
import '../../models/participation.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/participation_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_client.dart';
import '../../services/challenges_service.dart';
import '../../services/groups_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../challenge/challenge_detail_screen.dart';
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

class _ProfileScreen extends StatefulWidget {
  final String? username;
  const _ProfileScreen({this.username});

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  bool _isSigningOut = false;
  bool _isFollowBusy = false;
  int _selectedTab = 0;
  Map<String, Challenge> _challengesById = {};
  List<Group> _myGroups = [];
  List<Group> _publicGroups = [];
  bool _groupsLoading = false;
  String? _groupsError;

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
      await Future.wait([
        context.read<ProfileProvider>().load(
          username,
          isOwnProfile: isOwnProfile,
        ),
        if (isOwnProfile) context.read<ParticipationProvider>().load(),
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
      builder: (_) => const _CreateGroupDialog(),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  bool _isOwnProfile(AuthProvider auth) =>
      widget.username == null || widget.username == auth.username;

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to access your account.',
        ),
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
    );

    if (shouldLogout != true || !mounted) return;
    setState(() => _isSigningOut = true);
    await context.read<AuthProvider>().signOut();
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
      await context.read<ParticipationProvider>().updateStatus(
        participation.id,
        status,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowBusy) return;
    setState(() => _isFollowBusy = true);
    try {
      await context.read<ProfileProvider>().toggleFollow();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isFollowBusy = false);
    }
  }

  Future<void> _showAccountMenu(UserProfile profile) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Update profile'),
              onTap: () => Navigator.pop(sheetContext, 'update'),
            ),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) => SwitchListTile.adaptive(
                secondary: const Icon(Icons.brightness_6_outlined),
                title: const Text('Dark theme'),
                value: themeProvider.isDark,
                onChanged: themeProvider.setDark,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              onTap: () => Navigator.pop(sheetContext, 'logout'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'update') {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => UpdateProfileScreen(profile: profile),
            ),
          )
          .then((updated) {
            if (updated == true && mounted) _load();
          });
    } else if (action == 'logout') {
      _confirmLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final participationProvider = context.watch<ParticipationProvider>();
    final auth = context.watch<AuthProvider>();
    final profile = provider.profile;
    final isOwnProfile = _isOwnProfile(auth);

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
          child: _RefreshableState(child: Text(provider.errorMessage!)),
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

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              title: Text('@${profile.username ?? 'profile'}'),
              floating: true,
              actions: [
                if (_isOwnProfile(auth))
                  IconButton(
                    icon: const Icon(Icons.menu),
                    tooltip: 'Account options',
                    onPressed: _isSigningOut
                        ? null
                        : () => _showAccountMenu(profile),
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: _ProfileHeader(
                profile: profile,
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
            if (!isOwnProfile)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: profile.isFollowing
                        ? OutlinedButton.icon(
                            onPressed: _isFollowBusy ? null : _toggleFollow,
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                  : AppColors.lightTextPrimary,
                              side: BorderSide(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Theme.of(context).colorScheme.outline
                                    : AppColors.lightTextPrimary.withValues(
                                        alpha: 0.65,
                                      ),
                              ),
                            ),
                            icon: _isFollowBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.person_remove_outlined),
                            label: const Text('Following'),
                          )
                        : FilledButton.icon(
                            onPressed: _isFollowBusy ? null : _toggleFollow,
                            style: OutlinedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.primary
                                  : AppColors.lightTextPrimary,
                              foregroundColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.dark
                                  : Colors.white,
                            ),
                            icon: _isFollowBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.person_add_outlined),
                            label: const Text('Follow'),
                          ),
                  ),
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                    child: Text(
                      'Created challenges',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                if (provider.createdChallenges.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text('No challenges created yet.'),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _CreatedChallengeTile(
                        challenge: provider.createdChallenges[index],
                      ),
                      childCount: provider.createdChallenges.length,
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                    child: Text(
                      'My challenges',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                if (participationProvider.isLoading &&
                    participationProvider.participations.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (participationProvider.participations.isEmpty)
                  const SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.flag_outlined,
                      title: 'Your next interesting thing is waiting.',
                      message:
                          'Discover a challenge and accept it to get started.',
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ParticipationTile(
                        participation:
                            participationProvider.participations[index],
                        challenge:
                            _challengesById[participationProvider
                                .participations[index]
                                .challengeId],
                        statusLabel: _statusLabel(
                          participationProvider.participations[index].status,
                        ),
                        onChangeStatus: _changeStatus,
                      ),
                      childCount: participationProvider.participations.length,
                    ),
                  ),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Completed challenges',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),
              if (provider.completedChallenges.isEmpty)
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ChallengeTile(
                        challenge: provider.completedChallenges[index],
                      ),
                      childCount: provider.completedChallenges.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 3,
                          mainAxisSpacing: 3,
                          childAspectRatio: 0.78,
                        ),
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
                ),
              )
            else if (_selectedTab != 0)
              const SliverToBoxAdapter(child: _ComingSoonPanel()),
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
      (Icons.flag_outlined, 'Challenges'),
      (Icons.groups_outlined, 'Groups'),
      if (showRewards) (Icons.emoji_events_outlined, 'Rewards'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Row(
        children: [
          for (var index = 0; index < tabs.length; index++)
            Expanded(
              child: InkWell(
                onTap: () => onSelected(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selectedIndex == index
                            ? AppColors.primaryMuted
                            : AppColors.lightBorder,
                        width: selectedIndex == index ? 2.5 : 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tabs[index].$1,
                        size: 16,
                        color: selectedIndex == index
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tabs[index].$2,
                        style: TextStyle(
                          color: selectedIndex == index
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
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

  const _GroupsPanel({
    required this.isOwnProfile,
    required this.groups,
    required this.publicGroups,
    required this.isLoading,
    required this.errorMessage,
    this.onCreate,
    this.onJoin,
    this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
        child: Text(errorMessage!),
      );
    }

    final joinedSection = [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                isOwnProfile ? 'My groups' : 'Groups',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (onCreate != null)
              IconButton(
                tooltip: 'Create group',
                onPressed: onCreate,
                icon: const Icon(Icons.add),
              ),
          ],
        ),
      ),
      if (groups.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            isOwnProfile
                ? 'You have not joined any groups yet.'
                : 'No groups yet.',
          ),
        )
      else
        ...groups.map((group) => _GroupTile(group: group, onLeave: onLeave)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...joinedSection,
        if (isOwnProfile) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Text(
              'Discover public groups',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (publicGroups.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('No public groups available.'),
            )
          else
            ...publicGroups.map(
              (group) => _GroupTile(group: group, onJoin: onJoin),
            ),
        ],
      ],
    );
  }
}

class _GroupTile extends StatelessWidget {
  final Group group;
  final Future<void> Function(Group group)? onJoin;
  final Future<void> Function(Group group)? onLeave;

  const _GroupTile({required this.group, this.onJoin, this.onLeave});

  @override
  Widget build(BuildContext context) {
    final isMember = group.membershipStatus == 'ACTIVE';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Card(
        child: ListTile(
          leading: Icon(
            group.visibility == 'PRIVATE'
                ? Icons.lock_outline
                : Icons.groups_outlined,
          ),
          title: Text(group.name),
          subtitle: Text(
            '${group.memberCount} ${group.memberCount == 1 ? 'member' : 'members'}'
            '${group.description == null ? '' : '\n${group.description}'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: onJoin != null && !isMember
              ? TextButton(
                  onPressed: () => onJoin!(group),
                  child: const Text('Join'),
                )
              : onLeave != null && isMember
              ? TextButton(
                  onPressed: () => onLeave!(group),
                  child: const Text('Leave'),
                )
              : null,
        ),
      ),
    );
  }
}

class _ComingSoonPanel extends StatelessWidget {
  const _ComingSoonPanel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              size: 34,
              color: AppColors.primaryMuted,
            ),
            const SizedBox(height: 14),
            const Text(
              'Coming soon',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'This section is still being levelled up.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13.5,
              ),
            ),
          ],
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

class _ProfileHeader extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  const _ProfileHeader({
    required this.profile,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: AppColors.surfaceAlt,
                backgroundImage: profile.avatarUrl != null
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null
                    ? const Icon(
                        Icons.person_outline,
                        size: 42,
                        color: AppColors.textSecondary,
                      )
                    : null,
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(
                      value: profile.completedChallengesCount,
                      label: 'skills',
                    ),
                    _Stat(
                      value: profile.followerCount,
                      label: 'followers',
                      onTap: onFollowersTap,
                    ),
                    _Stat(
                      value: profile.followingCount,
                      label: 'following',
                      onTap: onFollowingTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.name ?? profile.username ?? 'NerdMaxxer',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    '⚡ ${profile.auraPoints} aura',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(profile.bio!),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;
  final VoidCallback? onTap;

  const _Stat({required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Card(
        child: InkWell(
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
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge?.title ??
                            'Challenge $shortId${challengeId.length > 6 ? '...' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusLabel,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (challenge != null)
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                if (participation.status == 'ACCEPTED')
                  TextButton(
                    onPressed: () =>
                        onChangeStatus(participation, 'IN_PROGRESS'),
                    child: const Text('Start'),
                  ),
                if (participation.status == 'IN_PROGRESS')
                  TextButton(
                    onPressed: () => onChangeStatus(participation, 'PAUSED'),
                    child: const Text('Pause'),
                  ),
                if (participation.status == 'PAUSED')
                  TextButton(
                    onPressed: () =>
                        onChangeStatus(participation, 'IN_PROGRESS'),
                    child: const Text('Resume'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatedChallengeTile extends StatelessWidget {
  final Challenge challenge;

  const _CreatedChallengeTile({required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Card(
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChallengeDetailScreen(
                slug: challenge.slug,
                initialChallenge: challenge,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            leading: Icon(
              challenge.visibility.toUpperCase() == 'PRIVATE'
                  ? Icons.lock_outline
                  : Icons.edit_note,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(challenge.title),
            subtitle: Text(
              '${challenge.status} • ${challenge.visibility}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right),
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
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChallengeDetailScreen(slug: challenge.slug),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (challenge.imageUrl != null)
            Image.network(
              challenge.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(),
            )
          else
            _fallback(),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(7),
              color: Colors.black.withValues(alpha: 0.68),
              child: Text(
                challenge.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() => Container(
    color: AppColors.surfaceAlt,
    alignment: Alignment.center,
    child: const Icon(
      Icons.flag_outlined,
      color: AppColors.primaryMuted,
      size: 28,
    ),
  );
}
