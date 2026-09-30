import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, ChangeNotifierProvider, Consumer;

import '../../models/challenge.dart';
import '../../models/group.dart';
import '../../models/participation.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_state_providers.dart';
import '../../providers/profile_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_client.dart';
import '../../services/challenges_service.dart';
import '../../services/groups_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../challenge/challenge_detail_screen.dart';
import 'group_chat_screen.dart';
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

  void _openGroup(Group group) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)));
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
      await ref
          .read(participationControllerProvider.notifier)
          .updateStatus(participation.id, status);
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
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Update profile'),
              onTap: () => Navigator.pop(sheetContext, 'update'),
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
                  activeThumbColor: AppColors.dark,
                  activeTrackColor: AppColors.primary,
                  inactiveThumbColor: colorScheme.onSurfaceVariant,
                  inactiveTrackColor: colorScheme.surfaceContainerHighest,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
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
      _openUpdateProfile(profile);
    } else if (action == 'logout') {
      _confirmLogout();
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
    final auth = context.watch<AuthProvider>();
    final profile = provider.profile;
    final isOwnProfile = _isOwnProfile(auth);
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
        color: Theme.of(context).colorScheme.onSurface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              title: Text(
                profile.name ?? profile.username ?? 'Profile',
                style: AppFonts.body(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              centerTitle: true,
              floating: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              actions: [
                if (_isOwnProfile(auth))
                  IconButton(
                    icon: const Icon(Icons.menu_rounded),
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
                const SliverToBoxAdapter(child: _SectionLabel('In progress')),
                if (participationState.isLoading && participations.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (participations.isEmpty)
                  const SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.flag_rounded,
                      title: 'Your next interesting thing is waiting.',
                      message:
                          'Discover a challenge and accept it to get started.',
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ParticipationTile(
                        participation: participations[index],
                        challenge:
                            _challengesById[participations[index].challengeId],
                        statusLabel: _statusLabel(participations[index].status),
                        onChangeStatus: _changeStatus,
                      ),
                      childCount: participations.length,
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: _SectionLabel('Created by you'),
                ),
                if (createdChallenges.isEmpty)
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
                        challenge: createdChallenges[index],
                      ),
                      childCount: createdChallenges.length,
                    ),
                  ),
              ],
              const SliverToBoxAdapter(child: _SectionLabel('Completed')),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _ChallengeTile(challenge: completedChallenges[index]),
                      childCount: completedChallenges.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
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
                  onOpenGroup: _openGroup,
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
      (Icons.flag_rounded, 'Challenges'),
      (Icons.groups_rounded, 'Groups'),
      if (showRewards) (Icons.emoji_events_rounded, 'Rewards'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 20),
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
                            ? colorScheme.onSurface
                            : colorScheme.outline,
                        width: selectedIndex == index ? 2 : 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tabs[index].$1,
                        size: 18,
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
                          fontSize: 13,
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
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Text(
        text.toUpperCase(),
        style: AppFonts.label(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
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
    const shape = StadiumBorder();
    final spinner = SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onSurface),
    );

    final Widget primary = isOwnProfile
        ? OutlinedButton(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              shape: shape,
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: scheme.outline),
            ),
            child: const Text('Edit profile'),
          )
        : profile.isFollowing
        ? OutlinedButton(
            onPressed: isFollowBusy ? null : onToggleFollow,
            style: OutlinedButton.styleFrom(
              shape: shape,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: isFollowBusy ? spinner : const Text('Following'),
          )
        : FilledButton(
            onPressed: isFollowBusy ? null : onToggleFollow,
            style: FilledButton.styleFrom(
              shape: shape,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: isFollowBusy ? spinner : const Text('Follow'),
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Row(
        children: [
          Expanded(flex: 3, child: primary),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: ShapeDecoration(
                shape: StadiumBorder(side: BorderSide(color: scheme.outline)),
              ),
              alignment: Alignment.center,
              child: Text(
                'Rank ${profile.rank}',
                style: AppFonts.body(
                  color: scheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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
                icon: const Icon(Icons.add_rounded),
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
        ...groups.map(
          (group) => _GroupTile(
            group: group,
            onLeave: onLeave,
            onTap: () => onOpenGroup(group),
          ),
        ),
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
    return _RowCard(
      onTap: onTap,
      leadingIcon: group.visibility == 'PRIVATE'
          ? Icons.lock_rounded
          : Icons.groups_rounded,
      leadingColor: AppColors.limeWash,
      leadingIconColor: AppColors.lightTextPrimary,
      title: group.name,
      subtitle:
          '${group.memberCount} ${group.memberCount == 1 ? 'member' : 'members'}',
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
              color: colorScheme.onSurfaceVariant,
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
    final scheme = Theme.of(context).colorScheme;
    final initial = (profile.name ?? profile.username ?? '?')
        .trim()
        .characters
        .firstOrNull
        ?.toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: CircleAvatar(
                  backgroundColor: const Color(0xFFA23BBF),
                  backgroundImage: profile.avatarUrl != null
                      ? NetworkImage(profile.avatarUrl!)
                      : null,
                  child: profile.avatarUrl == null
                      ? Text(
                          initial ?? '?',
                          style: AppFonts.body(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : null,
                ),
              ),
              Positioned(
                right: -2,
                bottom: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                  child: Text(
                    profile.rank,
                    style: AppFonts.body(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (profile.username != null) ...[
            const SizedBox(height: 12),
            Text(
              '@${profile.username}',
              style: AppFonts.body(
                color: scheme.onSurfaceVariant,
                fontSize: 15,
              ),
            ),
          ],
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              profile.bio!,
              textAlign: TextAlign.center,
              style: AppFonts.body(color: scheme.onSurface, fontSize: 14),
            ),
          ],
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Stat(value: '${profile.auraPoints}', label: 'Aura'),
                VerticalDivider(width: 1, color: scheme.outline),
                _Stat(
                  value: '${profile.followerCount}',
                  label: 'Followers',
                  onTap: onFollowersTap,
                ),
                VerticalDivider(width: 1, color: scheme.outline),
                _Stat(
                  value: '${profile.followingCount}',
                  label: 'Following',
                  onTap: onFollowingTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _Stat({required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 96),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: Column(
          children: [
            Text(
              value,
              style: AppFonts.body(
                color: scheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppFonts.body(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
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
          : TextButton(
              onPressed: () => onChangeStatus(participation, actionLabel.$2),
              child: Text(actionLabel.$1),
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
    return _RowCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChallengeDetailScreen(
            slug: challenge.slug,
            initialChallenge: challenge,
          ),
        ),
      ),
      leadingIcon: isPrivate ? Icons.lock_rounded : Icons.edit_note_rounded,
      leadingColor: AppColors.limeWash,
      leadingIconColor: AppColors.lightTextPrimary,
      title: challenge.title,
      subtitle: isPrivate ? 'Private' : 'Public',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.limeWash,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bolt_rounded,
              size: 14,
              color: AppColors.lightTextPrimary,
            ),
            const SizedBox(width: 3),
            Text(
              '${challenge.auraPoints}',
              style: AppFonts.body(
                color: AppColors.lightTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData leadingIcon;
  final Color leadingColor;
  final Color? leadingIconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _RowCard({
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: leadingColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    leadingIcon,
                    size: 22,
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
                        style: AppFonts.body(
                          color: scheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppFonts.body(
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
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
            Positioned(
              top: 7,
              right: 7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${challenge.auraPoints}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() => Container(
    color: AppColors.limeWash,
    alignment: Alignment.center,
    child: const Icon(
      Icons.flag_rounded,
      color: AppColors.lightTextPrimary,
      size: 28,
    ),
  );
}
