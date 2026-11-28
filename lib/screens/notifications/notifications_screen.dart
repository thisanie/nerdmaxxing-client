import 'package:flutter/material.dart' hide SnackBar;
import '../../widgets/app_snack_bar.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../models/challenge.dart';
import '../../models/notification.dart';
import '../../providers/app_state_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_badge_provider.dart';
import '../../services/api_client.dart';
import '../../services/challenges_service.dart';
import '../../services/daily_quests_service.dart';
import '../../services/evidence_service.dart';
import '../../services/notifications_service.dart';
import '../../services/groups_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error.dart';
import '../challenge/challenge_detail_screen.dart';
import '../daily_quest/daily_quest_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/group_chat_screen.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
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
      if (notifications.any(
        (notification) =>
        notification.isEvidenceApproved || notification.isDailyQuest,
      )) {
        ref.invalidate(myStatsProvider);
      }
      setState(() => _notifications = notifications);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) return;
    final notifications = context.read<NotificationsService>();
    final badge = context.read<NotificationBadgeController>();
    try {
      await notifications.markRead(notification.id);
      badge.markRead();
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
    final badge = context.read<NotificationBadgeController>();
    final participations = ref.read(participationControllerProvider.notifier);
    setState(() => _workingId = notification.id);
    try {
      final participation = await notifications.acceptInvitation(invitationId);
      participations.add(participation);
      await notifications.markRead(notification.id);
      badge.markRead();
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Invitation accepted.')));
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
    final badge = context.read<NotificationBadgeController>();
    setState(() => _workingId = notification.id);
    try {
      await notifications.declineInvitation(invitationId);
      await notifications.markRead(notification.id);
      badge.markRead();
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
        challenge = Challenge.fromJson(
          embeddedChallenge.cast<String, dynamic>(),
        );
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
        SnackBar(content: Text('Challenge details are unavailable.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChallengeDetailScreen(
          slug: challenge!.slug,
          initialChallenge: challenge,
          invitation: notification,
          initialDiscussionId: notification.discussionId,
          initialReplyId: notification.replyId,
        ),
      ),
    );
  }

  Future<void> _openNotification(AppNotification notification) async {
    if (notification.isDailyQuest) {
      await _openDailyQuest(notification);
    } else if (notification.isEvidenceApproved) {
      await _openChallengeReward(notification);
    } else if (notification.isGroupMessage) {
      await _viewGroup(notification);
    } else if (notification.isFollow) {
      await _markRead(notification);
      if (!mounted) return;
      final username = notification.actorUsername;
      if (username == null || username.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Follower profile is unavailable.')),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProfileScreen(username: username)),
      );
    } else if (notification.isFollowingChallengeCompleted ||
        notification.isChallengeInvitation ||
        notification.isReply) {
      await _viewChallenge(notification);
    } else {
      await _markRead(notification);
    }
  }

  Future<void> _openChallengeReward(AppNotification notification) async {
    await _markRead(notification);
    if (!mounted) return;

    final submissionId = notification.evidenceSubmissionId;
    final notificationAura =
      notification.data['aura_rewarded'] ??
      notification.data['aura_rewared'];
    final notificationStreak = notification.data['day_streak'];
    final notificationAuraValue = notificationAura is num
        ? notificationAura.toInt()
        : int.tryParse('$notificationAura');
    final notificationStreakValue = notificationStreak is num
        ? notificationStreak.toInt()
        : int.tryParse('$notificationStreak');

    try {
      ref.invalidate(myStatsProvider);
      final submission = submissionId == null || submissionId.isEmpty
          ? null
          : await context.read<EvidenceService>().getSubmission(submissionId);
      if (!mounted) return;

      final stats = await ref.read(myStatsProvider.future);
      if (!mounted) return;
      final challengeSlug = notification.challengeSlug;
      final challenge = challengeSlug == null || challengeSlug.isEmpty
          ? null
          : await context.read<ChallengesService>().getBySlug(challengeSlug);
      if (!mounted) return;

      final title = notification.challengeTitle?.trim().isNotEmpty == true
          ? notification.challengeTitle!.trim()
          : challenge?.title ?? 'Challenge completed';
      final auraAwarded = submission?.auraAwarded ?? notificationAuraValue ?? 0;
      final dayStreak = submission?.dayStreak ??
          notificationStreakValue ??
          stats.dayStreak;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChallengeCompletionRewardScreen(
            challengeTitle: title,
            auraAwarded: auraAwarded,
            dayStreak: dayStreak,
            username: context.read<AuthProvider>().username ?? 'you',
            rank: stats.rank,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _openDailyQuest(AppNotification notification) async {
    await _markRead(notification);
    if (!mounted) return;
    final service = context.read<DailyQuestsService>();
    try {
      final attemptId = notification.dailyQuestAttemptId;
      if (attemptId != null && attemptId.isNotEmpty) {
        final result = await service.getAttemptResult(attemptId);
        if (!mounted) return;
        var questTitle = result.questTitle ?? notification.dailyQuestTitle;
        if (questTitle == null) {
          final today = await service.getToday();
          if (!mounted) return;
          final matchesNotification =
              (notification.dailyQuestId == null ||
                  notification.dailyQuestId == today.quest?.id) &&
              (notification.dailyQuestLocalDate == null ||
                  notification.dailyQuestLocalDate == today.localDate);
          if (matchesNotification) questTitle = today.quest?.title;
        }
        ref.invalidate(myStatsProvider);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DailyQuestRewardScreen(
              result: result,
              questTitle: questTitle ?? 'Daily Quest',
              username: context.read<AuthProvider>().username ?? 'you',
              rewardAlreadyApplied: true,
            ),
          ),
        );
        return;
      }

      final today = await service.getToday();
      if (!mounted) return;
      if ((notification.dailyQuestId != null &&
              notification.dailyQuestId != today.quest?.id) ||
          (notification.dailyQuestLocalDate != null &&
              notification.dailyQuestLocalDate != today.localDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('That Daily Quest is no longer available.')),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DailyQuestScreen(today: today)),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _viewGroup(AppNotification notification) async {
    final groups = context.read<GroupsService>();
    await _markRead(notification);
    if (!mounted) return;
    final groupId = notification.groupId;
    if (groupId == null || groupId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group details are unavailable.')),
        );
      }
      return;
    }
    try {
      final group = await groups.get(groupId);
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
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
                  SizedBox(
                    height: 480,
                    child: AppErrorView(error: _error!, onRetry: _load),
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
                  onTap: () => _openNotification(_notifications[index]),
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
    final isGroupMessage = notification.isGroupMessage;
    final isDailyQuest = notification.isDailyQuest;
    final isPendingInvitation = notification.isPendingInvitation;
    final isEvidenceResult =
        notification.isEvidenceApproved || notification.isEvidenceRejected;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: notification.isRead ? null : colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
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
                    isDailyQuest
                      ? Icons.bolt_rounded
                      : isGroupMessage
                        ? Icons.groups_rounded
                        : isInvitation
                        ? Icons.mail_rounded
                        : isEvidenceResult
                        ? notification.isEvidenceApproved
                              ? Icons.verified_rounded
                              : Icons.rate_review_outlined
                        : notification.isFollowingChallengeCompleted
                        ? Icons.celebration_rounded
                        : notification.isFollow
                        ? Icons.person_add_alt_1_rounded
                        : Icons.notifications_none_rounded,
                    color: notification.isEvidenceRejected
                        ? colorScheme.error
                        : Theme.of(context).brightness == Brightness.light
                        ? Colors.black
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            isDailyQuest
                              ? notification.title ?? 'Daily Quest'
                              : isGroupMessage
                              ? notification.groupName ?? 'Group message'
                              : notification.title ??
                                    (isEvidenceResult
                                        ? 'Evidence review'
                                        : notification
                                              .isFollowingChallengeCompleted
                                        ? notification.challengeTitle ??
                                              'Challenge completed'
                                        : notification.isFollow
                                        ? notification.actorName ??
                                              'New follower'
                                        : notification.challengeTitle ??
                                              'Notification'),
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
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Icon(
                        Icons.circle,
                        size: 8,
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.black
                            : AppColors.primary,
                      ),
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
