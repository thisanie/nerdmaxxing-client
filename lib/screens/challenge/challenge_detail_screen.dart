import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../models/challenge.dart';
import '../../models/challenge_detail.dart';
import '../../models/notification.dart';
import '../../models/participation.dart';
import '../../models/progress_log.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_state_providers.dart';
import '../../services/api_client.dart';
import '../../services/challenges_service.dart';
import '../../services/invitations_service.dart';
import '../../services/notifications_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import 'challenge_journey.dart';
import 'path_screen.dart';

class ChallengeDetailScreen extends ConsumerStatefulWidget {
  final String slug;
  final Challenge? initialChallenge;
  final AppNotification? invitation;

  const ChallengeDetailScreen({
    super.key,
    required this.slug,
    this.initialChallenge,
    this.invitation,
  });

  @override
  ConsumerState<ChallengeDetailScreen> createState() =>
      _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends ConsumerState<ChallengeDetailScreen> {
  Challenge? _challenge;
  ChallengeDetail? _detail;
  String? _error;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _challenge = widget.initialChallenge;
    _load();
  }

  Future<void> _load() async {
    try {
      await _refreshDetail();
    } on ApiException {
      // Initial-load errors are represented by _error when no fallback exists.
    }
  }

  Future<ChallengeDetail> _refreshDetail() async {
    try {
      final detail = await context.read<ChallengesService>().getDetailBySlug(
        widget.slug,
      );
      if (mounted) {
        setState(() {
          _detail = detail;
          _challenge = detail.challenge;
        });
      }
      return detail;
    } on ApiException catch (e) {
      if (!mounted) rethrow;
      if (_challenge == null) {
        setState(() => _error = e.message);
      }
      rethrow;
    }
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await ref.read(participationControllerProvider.notifier).accept(widget.slug);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Challenge accepted. Ready when you are.'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _acceptInvitation() async {
    final invitationId = widget.invitation?.invitationId;
    if (invitationId == null) return;
    final notifications = context.read<NotificationsService>();
    final participations = ref.read(participationControllerProvider.notifier);
    try {
      final participation = await notifications.acceptInvitation(invitationId);
      participations.add(participation);
      await notifications.markRead(widget.invitation!.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation accepted.')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _declineInvitation() async {
    final invitationId = widget.invitation?.invitationId;
    if (invitationId == null) return;
    final notifications = context.read<NotificationsService>();
    try {
      await notifications.declineInvitation(invitationId);
      await notifications.markRead(widget.invitation!.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation declined.')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ),
      );
    }
    if (_challenge == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final challenge = _challenge!;
    final detail = _detail ?? ChallengeDetail.fromChallenge(challenge);
    final participation = ref
        .watch(participationControllerProvider)
        .valueOrNull
        ?.where((item) => item.challengeId == challenge.id)
        .firstOrNull;

    return ChallengeJourney(
      challenge: challenge,
      detail: detail,
      participation: participation,
      accepting: _accepting,
        onAccept: widget.invitation?.invitationId != null
          ? _acceptInvitation
          : _accept,
          onDecline: widget.invitation?.invitationId != null
            ? _declineInvitation
            : null,
      onTrain: () => _openPath(detail),
          onOpenMilestone: (index) => participation == null
            ? _promptToAccept()
            : _openPath(detail, milestoneIndex: index),
          onRefresh: _refreshDetail,
      onProve: () => _showPrototypeSheet(
        'Prove it',
        detail.verification.instructions.isEmpty
            ? 'Submit evidence for the requirements shown on this challenge.'
            : detail.verification.instructions,
      ),
          invited: widget.invitation?.invitationId != null,
    );
  }

  void _showPrototypeSheet(String title, String message) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 34),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: const TextStyle(color: AppColors.primary, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          Text(message, style: const TextStyle(fontSize: 24, height: 1.1, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('GOT IT')),
        ]),
      ),
    );
  }

  Future<void> _promptToAccept() async {
    final shouldAccept = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accept this challenge first'),
        content: const Text(
          'Accept the challenge to unlock its milestones and resources.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ACCEPT CHALLENGE'),
          ),
        ],
      ),
    );
    if (shouldAccept == true && mounted) {
      if (widget.invitation?.invitationId != null) {
        await _acceptInvitation();
      } else {
        await _accept();
      }
    }
  }

  void _openPath(ChallengeDetail detail, {int? milestoneIndex}) {
    final currentIndex = milestoneIndex ?? _currentMilestoneIndex(detail);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PathScreen(
          challenge: _challenge!,
          detail: detail,
          initialMilestoneIndex: currentIndex,
          participation: ref.read(participationControllerProvider).valueOrNull
              ?.where((item) => item.challengeId == _challenge!.id)
              .firstOrNull,
            onRefresh: _refreshDetail,
        ),
      ),
    ).then((_) => _load());
  }

  int _currentMilestoneIndex(ChallengeDetail detail) {
    final index = detail.milestones.indexWhere(
      (milestone) => milestone.status != 'COMPLETED',
    );
    return index < 0 ? 0 : index;
  }

}

class _InviteFriendsDialog extends StatefulWidget {
  final String challenge;

  const _InviteFriendsDialog({required this.challenge});

  @override
  State<_InviteFriendsDialog> createState() => _InviteFriendsDialogState();
}

class _InviteFriendsDialogState extends State<_InviteFriendsDialog> {
  final _searchController = TextEditingController();
  List<UserSummary> _followers = [];
  bool _loading = true;
  bool _linkLoading = false;
  String? _error;
  String? _invitingId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFollowers());
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  Future<void> _loadFollowers() async {
    try {
      final username = context.read<AuthProvider>().username;
      if (username == null || username.isEmpty) {
        throw ApiException(null, 'Your profile is not ready yet.');
      }
      final profileService = context.read<ProfileService>();
      final profile = await profileService.getProfile(username);
      final followers = await profileService.listFollowers(profile.id);
      if (!mounted) return;
      setState(() => _followers = followers);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite(UserSummary user) async {
    setState(() {
      _invitingId = user.id;
      _error = null;
    });
    try {
      await context.read<InvitationsService>().inviteFollower(
        widget.challenge,
        inviteeId: user.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.name ?? user.username ?? 'Friend'} was invited.'),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _invitingId = null);
    }
  }

  Future<void> _copyInviteLink() async {
    setState(() {
      _linkLoading = true;
      _error = null;
    });
    try {
      final link = await context.read<InvitationsService>().createInviteLink(
        widget.challenge,
      );
      await Clipboard.setData(ClipboardData(text: link.url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite link copied to clipboard.')),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _linkLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final users = _followers.where((user) {
      return query.isEmpty ||
          (user.username ?? '').toLowerCase().contains(query) ||
          (user.name ?? '').toLowerCase().contains(query);
    }).toList();

    return AlertDialog(
      title: const Text('Challenge friends'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search your followers',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    if (_error != null) const SizedBox(height: 8),
                    if (users.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No matching followers.'),
                      )
                    else
                      ...users.map(
                        (user) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundImage: user.avatarUrl == null
                                ? null
                                : NetworkImage(user.avatarUrl!),
                            child: user.avatarUrl == null
                                ? const Icon(Icons.person_outline)
                                : null,
                          ),
                          title: Text(
                            user.name ?? user.username ?? 'NerdMaxxer',
                          ),
                          subtitle: user.username == null
                              ? null
                              : Text('@${user.username}'),
                          trailing: _invitingId == user.id
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : IconButton(
                                  tooltip: 'Challenge',
                                  onPressed: _invitingId == null
                                      ? () => _invite(user)
                                      : null,
                                  icon: const Icon(Icons.send_outlined),
                                ),
                        ),
                      ),
                    const Divider(height: 24),
                    OutlinedButton.icon(
                      onPressed: _linkLoading ? null : _copyInviteLink,
                      icon: const Icon(Icons.link),
                      label: Text(
                        _linkLoading ? 'Creating link...' : 'Copy invite link',
                      ),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _ProgressDialog extends ConsumerStatefulWidget {
  final Participation participation;

  const _ProgressDialog({required this.participation});

  @override
  ConsumerState<_ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends ConsumerState<_ProgressDialog> {
  final _hoursController = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final hours = double.tryParse(_hoursController.text.trim());
    if (hours == null || hours <= 0 || hours > 24) {
      setState(() => _error = 'Enter a number of hours between 0 and 24.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(participationControllerProvider.notifier).logProgress(
        widget.participation.id,
        hoursSpent: hours,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      _hoursController.clear();
      _noteController.clear();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _durationLabel(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours == 0) return '$remainingMinutes min';
    if (remainingMinutes == 0) return '${hours}h';
    return '${hours}h ${remainingMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final logsState = ref.watch(progressLogsProvider(widget.participation.id));
    final logs = logsState.valueOrNull ?? const <ProgressLog>[];
    return AlertDialog(
      title: const Text('Log progress'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _hoursController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Hours spent',
                  hintText: 'e.g. 1.5',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLength: 5000,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save progress'),
              ),
              const SizedBox(height: 20),
              Text(
                'Recent progress',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (logsState.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (logs.isEmpty)
                const Text('No progress logged yet.')
              else
                ...logs.map(
                  (log) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: Text(_durationLabel(log.minutesSpent)),
                    subtitle: Text(
                      [
                        if (log.note != null && log.note!.isNotEmpty) log.note!,
                        if (log.createdAt != null)
                          log.createdAt!.toLocal().toString().split('.').first,
                      ].join('\n'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
