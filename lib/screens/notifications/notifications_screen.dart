import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../models/challenge.dart';
import '../../models/notification.dart';
import '../../providers/app_state_providers.dart';
import '../../providers/notification_badge_provider.dart';
import '../../services/api_client.dart';
import '../../services/challenges_service.dart';
import '../../services/notifications_service.dart';
import '../../theme/app_theme.dart';
import '../challenge/challenge_detail_screen.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;
  String? _error;
  String? _workingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notifications = await context.read<NotificationsService>().list();
      if (!mounted) return;
      setState(() => _notifications = notifications);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await context.read<NotificationsService>().markRead(notification.id);
      context.read<NotificationBadgeController>().markRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map(
              (item) => item.id == notification.id
                  ? item.copyWith(isRead: true)
                  : item,
            )
            .toList();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _accept(AppNotification notification) async {
    final invitationId = notification.invitationId;
    if (invitationId == null) return;
    final notifications = context.read<NotificationsService>();
    final participations = ref.read(participationControllerProvider.notifier);
    setState(() => _workingId = notification.id);
    try {
      final participation = await notifications.acceptInvitation(invitationId);
      participations.add(participation);
      await notifications.markRead(notification.id);
      context.read<NotificationBadgeController>().markRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
        .map(
          (item) => item.id == notification.id
          ? item.copyWith(isRead: true, invitationStatus: 'ACCEPTED')
          : item,
        )
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation accepted.')),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  Future<void> _decline(AppNotification notification) async {
    final invitationId = notification.invitationId;
    if (invitationId == null) return;
    final notifications = context.read<NotificationsService>();
    setState(() => _workingId = notification.id);
    try {
      await notifications.declineInvitation(invitationId);
      await notifications.markRead(notification.id);
      context.read<NotificationBadgeController>().markRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map(
              (item) => item.id == notification.id
                  ? item.copyWith(isRead: true, invitationStatus: 'DECLINED')
                  : item,
            )
            .toList();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  Future<void> _viewChallenge(AppNotification notification) async {
    final challengeService = context.read<ChallengesService>();
    await _markRead(notification);
    if (!mounted) return;
    Challenge? challenge;
    try {
      final embeddedChallenge = notification.data['challenge'];
      if (embeddedChallenge is Map) {
        challenge = Challenge.fromJson(embeddedChallenge.cast<String, dynamic>());
      }
      final slug = notification.challengeSlug;
      if (challenge != null) {
        // The notification already contains everything needed for the detail page.
      } else if (slug != null && slug.isNotEmpty) {
        challenge = await challengeService.getBySlug(slug);
      }
      if (challenge == null) {
        final challenges = await challengeService.list(limit: 100);
        final challengeId = notification.challengeId;
        if (challengeId != null) {
          final idMatches = challenges.where((item) => item.id == challengeId);
          challenge = idMatches.isEmpty ? null : idMatches.first;
        }
        if (challenge == null && notification.challengeTitle != null) {
          final title = notification.challengeTitle!.trim().toLowerCase();
          final titleMatches = challenges.where(
            (item) => item.title.trim().toLowerCase() == title,
          );
          challenge = titleMatches.isEmpty ? null : titleMatches.first;
        }
        if (challenge == null && notification.body.isNotEmpty) {
          final body = notification.body.toLowerCase();
          final bodyMatches = challenges.where(
            (item) => body.contains(item.title.trim().toLowerCase()),
          );
          challenge = bodyMatches.isEmpty ? null : bodyMatches.first;
        }
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return;
    }
    if (!mounted) return;
    if (challenge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Challenge details are unavailable.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChallengeDetailScreen(
          slug: challenge!.slug,
          initialChallenge: challenge,
          invitation: notification,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _notifications.isEmpty
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text(_error!)),
                  ),
                ],
              )
            : _notifications.isEmpty
            ? ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('You have no notifications.')),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) => _NotificationTile(
                  notification: _notifications[index],
                  isWorking: _workingId == _notifications[index].id,
                  onTap: () => _viewChallenge(_notifications[index]),
                  onAccept: () => _accept(_notifications[index]),
                  onDecline: () => _decline(_notifications[index]),
                ),
              ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final bool isWorking;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _NotificationTile({
    required this.notification,
    required this.isWorking,
    required this.onTap,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final isInvitation = notification.isChallengeInvitation;
    final isPendingInvitation = notification.isPendingInvitation;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: notification.isRead
          ? null
          : colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: notification.isChallengeInvitation ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isInvitation ? Icons.mail_outline : Icons.notifications_none,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.challengeTitle ?? 'Notification',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(notification.body),
                        if (notification.createdAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _dateLabel(notification.createdAt!),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!notification.isRead)
                    const Padding(
                      padding: EdgeInsets.only(left: 8, top: 4),
                      child: Icon(Icons.circle, size: 8, color: AppColors.primary),
                    ),
                ],
                ),
              if (isInvitation && notification.invitationStatus != null) ...[
                const SizedBox(height: 10),
                Text(
                  notification.invitationStatus == 'ACCEPTED'
                      ? 'Accepted'
                      : notification.invitationStatus == 'DECLINED'
                      ? 'Declined'
                      : notification.invitationStatus!,
                  style: TextStyle(
                    color: notification.invitationStatus == 'DECLINED'
                        ? AppColors.textSecondary
                        : AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (isPendingInvitation && notification.invitationId != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isWorking ? null : onDecline,
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: isWorking ? null : onAccept,
                        child: Text(isWorking ? 'Working...' : 'Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _dateLabel(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}