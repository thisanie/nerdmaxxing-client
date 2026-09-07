import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/challenge.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../models/participation.dart';
import '../../providers/participation_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/api_client.dart';
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
      await Future.wait([
        context.read<ProfileProvider>().load(
          username,
          isOwnProfile: isOwnProfile,
        ),
        if (isOwnProfile) context.read<ParticipationProvider>().load(),
      ]);
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final participationProvider = context.watch<ParticipationProvider>();
    final auth = context.watch<AuthProvider>();
    final profile = provider.profile;
    final isOwnProfile = _isOwnProfile(auth);

    if (provider.isLoading && profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (provider.errorMessage != null && profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(child: Text(provider.errorMessage!)),
      );
    }
    if (profile == null) {
      return const Scaffold(body: Center(child: Text('Profile unavailable')));
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
                  PopupMenuButton<String>(
                    enabled: !_isSigningOut,
                    icon: const Icon(Icons.menu),
                    tooltip: 'Account options',
                    onSelected: (value) {
                      if (value == 'update') {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    UpdateProfileScreen(profile: profile),
                              ),
                            )
                            .then((updated) {
                              if (updated == true && mounted) _load();
                            });
                      } else if (value == 'logout') {
                        _confirmLogout();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'update',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Update profile'),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'logout',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.logout),
                          title: Text('Log out'),
                        ),
                      ),
                    ],
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
                    child: OutlinedButton.icon(
                      onPressed: _isFollowBusy ? null : _toggleFollow,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      icon: _isFollowBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              profile.isFollowing
                                  ? Icons.person_remove_outlined
                                  : Icons.person_add_outlined,
                            ),
                      label: Text(profile.isFollowing ? 'Following' : 'Follow'),
                    ),
                  ),
                ),
              ),
            if (isOwnProfile) ...[
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 3,
                    mainAxisSpacing: 3,
                    childAspectRatio: 0.78,
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
          Text(
            profile.name ?? profile.username ?? 'NerdMaxxer',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(profile.bio!),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ProfileChip(
                icon: Icons.bolt,
                label: '${profile.auraPoints} aura',
              ),
              _ProfileChip(
                icon: Icons.workspace_premium_outlined,
                label: '${profile.skillsCount} skills',
              ),
            ],
          ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ProfileChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: AppColors.accent),
      label: Text(label),
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
    );
  }
}

class _ParticipationTile extends StatelessWidget {
  final Participation participation;
  final String statusLabel;
  final Future<void> Function(Participation participation, String status)
  onChangeStatus;

  const _ParticipationTile({
    required this.participation,
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
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
              if (participation.status == 'ACCEPTED')
                TextButton(
                  onPressed: () => onChangeStatus(participation, 'IN_PROGRESS'),
                  child: const Text('Start'),
                ),
              if (participation.status == 'IN_PROGRESS')
                TextButton(
                  onPressed: () => onChangeStatus(participation, 'PAUSED'),
                  child: const Text('Pause'),
                ),
              if (participation.status == 'PAUSED')
                TextButton(
                  onPressed: () => onChangeStatus(participation, 'IN_PROGRESS'),
                  child: const Text('Resume'),
                ),
            ],
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
