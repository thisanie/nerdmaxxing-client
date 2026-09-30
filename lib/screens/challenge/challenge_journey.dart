import 'package:flutter/material.dart';

import '../../models/challenge.dart';
import '../../models/challenge_detail.dart';
import '../../models/participation.dart';
import '../../services/discussions_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/challenge_discussion.dart';

enum _ChallengeMenuAction { save, invite, drop }

class _Tone {
  final bool light;
  final Color bg, card, ink, muted, border, hero, accent, inkSurface;

  const _Tone._({
    required this.light,
    required this.bg,
    required this.card,
    required this.ink,
    required this.muted,
    required this.border,
    required this.hero,
    required this.accent,
    required this.inkSurface,
  });

  factory _Tone.of(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return light
        ? const _Tone._(
            light: true,
            bg: AppColors.lightBackground,
            card: AppColors.lightSurface,
            ink: AppColors.lightTextPrimary,
            muted: AppColors.lightTextSecondary,
            border: AppColors.lightBorder,
            hero: Color(0xFFEBF4C8),
            accent: Color(0xFF4F6A0A),
            inkSurface: AppColors.lightTextPrimary,
          )
        : const _Tone._(
            light: false,
            bg: AppColors.background,
            card: AppColors.surface,
            ink: AppColors.textPrimary,
            muted: AppColors.textSecondary,
            border: AppColors.border,
            hero: AppColors.primaryMuted,
            accent: AppColors.primary,
            inkSurface: AppColors.surfaceAlt,
          );
  }
}

class ChallengeJourney extends StatefulWidget {
  final Challenge challenge;
  final ChallengeDetail detail;
  final Participation? participation;
  final VoidCallback onAccept;
  final VoidCallback onTrain;
  final VoidCallback onProve;
  final VoidCallback? onDecline;
  final VoidCallback? onInvite;
  final VoidCallback? onDrop;
  final Future<void> Function()? onToggleSave;
  final bool saved;
  final String challengeSlug;
  final DiscussionsService discussionsService;
  final bool discussionCanPost;
  final String? currentUsername;
  final String? initialDiscussionId;
  final String? initialReplyId;
  final ValueChanged<int> onOpenMilestone;
  final bool accepting;
  final bool invited;
  final Future<void> Function()? onRefresh;

  const ChallengeJourney({
    super.key,
    required this.challenge,
    required this.detail,
    required this.participation,
    required this.onAccept,
    required this.onTrain,
    required this.onProve,
    this.onDecline,
    this.onInvite,
    this.onDrop,
    this.onToggleSave,
    this.saved = false,
    required this.challengeSlug,
    required this.discussionsService,
    this.discussionCanPost = false,
    this.currentUsername,
    this.initialDiscussionId,
    this.initialReplyId,
    required this.onOpenMilestone,
    required this.accepting,
    this.invited = false,
    this.onRefresh,
  });

  @override
  State<ChallengeJourney> createState() => _ChallengeJourneyState();
}

class _ChallengeJourneyState extends State<ChallengeJourney> {
  late bool _discussionOpen;
  late _Tone t;

  @override
  void initState() {
    super.initState();
    _discussionOpen =
        widget.initialDiscussionId != null || widget.initialReplyId != null;
  }

  bool get active => widget.participation != null;

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    final lower = value.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  Color get _btnBg => t.light ? AppColors.lightTextPrimary : AppColors.primary;
  Color get _btnFg => t.light ? Colors.white : AppColors.dark;

  @override
  Widget build(BuildContext context) {
    t = _Tone.of(context);
    final challenge = widget.challenge;
    final difficulty = _titleCase(challenge.difficultyLevel);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.arrow_back_rounded, size: 22, color: t.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: difficulty,
                style: TextStyle(color: t.muted),
              ),
              TextSpan(
                text: '  ·  ',
                style: TextStyle(color: t.muted),
              ),
              TextSpan(
                text: active ? 'Accepted' : 'Open trial',
                style: TextStyle(color: t.ink),
              ),
            ],
          ),
          style: AppFonts.body(
            color: t.ink,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          if (active)
            PopupMenuButton<_ChallengeMenuAction>(
              tooltip: 'Challenge options',
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _ChallengeMenuAction.save,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      widget.saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                    ),
                    title: Text(
                      widget.saved
                          ? 'Remove saved challenge'
                          : 'Save challenge',
                    ),
                  ),
                ),
                const PopupMenuItem(
                  value: _ChallengeMenuAction.invite,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.person_add_rounded),
                    title: Text('Invite friend'),
                  ),
                ),
                const PopupMenuItem(
                  value: _ChallengeMenuAction.drop,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.exit_to_app_rounded),
                    title: Text('Drop challenge'),
                  ),
                ),
              ],
              icon: Icon(Icons.more_vert_rounded, size: 22, color: t.ink),
            )
          else
            IconButton(
              tooltip: widget.saved ? 'Saved' : 'Save challenge',
              onPressed: widget.onToggleSave,
              icon: Icon(
                widget.saved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                size: 22,
                color: t.ink,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await widget.onRefresh?.call();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _hero(context, challenge)),
                if (active)
                  SliverToBoxAdapter(
                    child: _section(
                      'Your attempts',
                      _attempts(context),
                      trailing: '${widget.detail.attempts.length} logged',
                    ),
                  ),
                if (!active)
                  SliverToBoxAdapter(
                    child: _section('Why take this on?', _why(context)),
                  ),
                SliverToBoxAdapter(
                  child: _section(
                    active ? 'The trail' : 'The path',
                    _path(context),
                    trailing: _trailSummary(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _section(
                    'At the summit',
                    _people(context),
                    trailing: '${(_climbRatio * 100).round()}% climbed',
                  ),
                ),
                if (!active)
                  SliverToBoxAdapter(
                    child: _section('How you prove it', _verification(context)),
                  ),
                SliverToBoxAdapter(child: _discussionSection(context)),
                SliverToBoxAdapter(child: _finalCta(context)),
              ],
            ),
          ),
          if (_discussionOpen)
            Positioned.fill(child: _discussionOverlay(context)),
        ],
      ),
    );
  }

  void _handleMenuAction(_ChallengeMenuAction action) {
    switch (action) {
      case _ChallengeMenuAction.save:
        widget.onToggleSave?.call();
      case _ChallengeMenuAction.invite:
        widget.onInvite?.call();
      case _ChallengeMenuAction.drop:
        widget.onDrop?.call();
    }
  }

  // ---------------------------------------------------------------- shell

  Widget _section(String title, Widget child, {String? trailing}) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 34, 20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.body(
                    color: t.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    letterSpacingEm: -0.02,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing,
                  style: AppFonts.body(color: t.muted, fontSize: 14),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: t.card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: t.border),
    ),
    child: child,
  );

  Widget _tall(Widget child) => SizedBox(height: 56, child: child);

  // ---------------------------------------------------------------- hero

  Widget _hero(BuildContext context, Challenge challenge) {
    final primary = widget.detail.primaryMetric;
    final unit = primary?.unit ?? '';
    final metricLabel = primary?.label ?? challenge.title;
    final target = _formatValue(primary?.target);
    final current = _formatValue(_progressMetricValue);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: t.hero,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: t.light ? const Color(0xFFD9E5AE) : t.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: active ? t.accent : t.muted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    active ? 'YOU ARE HERE' : 'THE CHALLENGE',
                    style: AppFonts.label(color: t.ink, fontSize: 13),
                  ),
                ),
                if (active && _sinceStart != null) _sincePill(),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  active ? current : target,
                  style: AppFonts.poster(
                    fontSize: 128,
                    color: t.ink,
                    wdth: 100,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      unit,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.body(
                        color: t.ink,
                        fontSize: 30,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (active) ...[
              Text(
                metricLabel,
                style: AppFonts.body(
                  color: t.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                primary?.target == null
                    ? 'Progress is being tracked.'
                    : 'Best so far. Target is ${_formatValue(primary!.target)}.',
                style: AppFonts.body(color: t.ink, fontSize: 18),
              ),
              if (primary != null && primary.target != null) ...[
                const SizedBox(height: 26),
                _progressRuler(primary),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _tall(
                      FilledButton.icon(
                        onPressed: widget.accepting ? null : widget.onTrain,
                        style: FilledButton.styleFrom(
                          backgroundColor: _btnBg,
                          foregroundColor: _btnFg,
                          shape: const StadiumBorder(),
                          textStyle: AppFonts.body(
                            color: t.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 26),
                        label: const Text('Train'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _tall(
                      OutlinedButton(
                        onPressed: widget.onProve,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: t.ink,
                          side: BorderSide(
                            color: t.ink.withValues(alpha: .3),
                            width: 1.5,
                          ),
                          shape: const StadiumBorder(),
                          textStyle: AppFonts.body(
                            color: t.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: const Text('Prove it'),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                challenge.shortDescription,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.body(
                  color: t.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  _fact('DIFFICULTY', _titleCase(challenge.difficultyLevel)),
                  _fact('EFFORT', challenge.effortLabel),
                  _fact('REWARD', '+${challenge.auraPoints}'),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _tall(
                      FilledButton(
                        onPressed: widget.accepting ? null : widget.onAccept,
                        style: FilledButton.styleFrom(
                          backgroundColor: _btnBg,
                          foregroundColor: _btnFg,
                          shape: const StadiumBorder(),
                          textStyle: AppFonts.body(
                            color: t.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: Text(
                          widget.accepting
                              ? 'Accepting...'
                              : 'Accept the challenge',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.outlined(
                    onPressed: widget.onToggleSave,
                    style: IconButton.styleFrom(
                      side: BorderSide(
                        color: t.ink.withValues(alpha: .3),
                        width: 1.5,
                      ),
                      minimumSize: const Size(56, 56),
                    ),
                    color: t.ink,
                    icon: Icon(
                      widget.saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.detail.participantCount} nerds are on this trial  ·  ${widget.detail.completedParticipantCount} have cleared it',
                style: AppFonts.body(
                  color: t.ink.withValues(alpha: .7),
                  fontSize: 13,
                ),
              ),
              if (widget.invited && widget.onDecline != null)
                TextButton(
                  onPressed: widget.onDecline,
                  style: TextButton.styleFrom(
                    foregroundColor: t.ink,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('Decline invitation'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  double? get _sinceStart {
    final now = _progressMetricValue;
    final base = _progressBaselineValue;
    if (now == null || base == null) return null;
    return now - base;
  }

  Widget _sincePill() {
    final delta = _sinceStart!;
    final fg = t.light ? AppColors.primary : AppColors.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _btnBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            delta >= 0 ? Icons.north_east_rounded : Icons.south_east_rounded,
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            '${_formatValue(delta.abs())} since start',
            style: AppFonts.body(
              color: fg,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fact(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.label(
            color: t.ink.withValues(alpha: .6),
            fontSize: 10.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.body(
            color: t.ink,
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _progressRuler(ChallengeMetric metric) {
    final base = _progressBaselineValue ?? metric.baseline ?? 0;
    final current = _progressMetricValue ?? metric.current ?? base;
    final target = metric.target ?? current;
    final span = target - base;
    final ratio = span == 0 ? 0.0 : ((current - base) / span).clamp(0.0, 1.0);
    final labelStyle = AppFonts.body(
      color: t.ink.withValues(alpha: .7),
      fontSize: 13,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            const knob = 18.0;
            final x = (width - knob) * ratio;
            return SizedBox(
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: (x - 6).clamp(0.0, width - 40),
                    top: 0,
                    child: Text(
                      _formatValue(current),
                      style: AppFonts.body(
                        color: t.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Icon(Icons.flag_rounded, size: 20, color: t.ink),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 27,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: t.ink.withValues(alpha: .22),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 27,
                    child: Container(
                      width: x + knob / 2,
                      height: 3,
                      decoration: BoxDecoration(
                        color: t.ink,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Positioned(
                    left: x,
                    top: 20,
                    child: Container(
                      width: knob,
                      height: knob,
                      decoration: BoxDecoration(
                        color: t.ink,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.hero, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatValue(base), style: labelStyle),
            Text(
              _formatValue(target),
              style: labelStyle.copyWith(
                color: t.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------- attempts

  Widget _attempts(BuildContext context) {
    final attempts = widget.detail.attempts;
    if (attempts.isEmpty) {
      return _card(
        child: Text(
          'No attempts logged yet.',
          style: AppFonts.body(color: t.muted, fontSize: 15),
        ),
      );
    }
    final primary = widget.detail.primaryMetric;
    double? valueOf(ChallengeAttempt a) =>
        (primary != null ? a.metrics[primary.key] : null) ??
        a.metrics.values.firstOrNull;

    // Attempts arrive newest-first; chart the latest few in chronological order.
    final chrono = attempts.reversed.toList();
    final start = chrono.length > 4 ? chrono.length - 4 : 0;
    final shown = chrono.sublist(start);
    final values = shown.map(valueOf).toList();
    final maxValue = values.whereType<double>().fold<double>(
      0,
      (a, b) => b > a ? b : a,
    );
    final unit = primary?.unit ?? '';
    final first = valueOf(chrono.first);
    final last = valueOf(chrono.last);
    final bestIndex = maxValue <= 0
        ? -1
        : values.indexWhere((v) => v == maxValue);

    final String footer;
    if (first != null && last != null && first > 0 && chrono.length > 1) {
      footer =
          '${primary?.label ?? 'Result'}  ·  ${_formatValue(last / first)}× your first attempt';
    } else {
      footer = primary?.label ?? 'Latest results';
    }

    return _card(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < shown.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _attemptBar(
                        value: values[i],
                        max: maxValue,
                        unit: unit,
                        number: start + i + 1,
                        isLatest: i == shown.length - 1,
                        isBest: i == bestIndex && i != shown.length - 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: t.border),
          const SizedBox(height: 12),
          Text(footer, style: AppFonts.body(color: t.muted, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _attemptBar({
    required double? value,
    required double max,
    required String unit,
    required int number,
    required bool isLatest,
    required bool isBest,
  }) {
    const maxBar = 88.0;
    const minBar = 26.0;
    final ratio = value == null || max <= 0
        ? 0.0
        : (value / max).clamp(0.0, 1.0);
    final barHeight = minBar + (maxBar - minBar) * ratio;
    final Color fill = isLatest
        ? AppColors.primary
        : isBest
        ? (t.light ? AppColors.lightTextPrimary : AppColors.textPrimary)
        : (t.light ? AppColors.lightSurfaceAlt : AppColors.surfaceAlt);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          value == null
              ? '--'
              : '${_formatValue(value)}${unit.length <= 3 ? unit : ''}',
          style: AppFonts.body(color: t.ink, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(14),
            border: isLatest
                ? Border.all(
                    color: t.light
                        ? AppColors.lightTextPrimary
                        : AppColors.primary,
                    width: 1.5,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text('#$number', style: AppFonts.body(color: t.muted, fontSize: 14)),
      ],
    );
  }

  // ---------------------------------------------------------------- trail

  bool _isMilestoneComplete(ChallengeMilestone milestone) {
    final total = milestone.totalResourceCount > 0
        ? milestone.totalResourceCount
        : milestone.resources.length;
    final completed = milestone.totalResourceCount > 0
        ? milestone.completedResourceCount
        : milestone.resources.where((resource) => resource.completed).length;
    return total > 0 && completed >= total;
  }

  double _milestoneProgress(ChallengeMilestone milestone) {
    final total = milestone.totalResourceCount > 0
        ? milestone.totalResourceCount
        : milestone.resources.length;
    if (total == 0) return 0;
    final completed = milestone.totalResourceCount > 0
        ? milestone.completedResourceCount
        : milestone.resources.where((resource) => resource.completed).length;
    return (completed / total).clamp(0.0, 1.0);
  }

  bool _isNextMilestone(int index) {
    for (var i = 0; i < widget.detail.milestones.length; i++) {
      if (!_isMilestoneComplete(widget.detail.milestones[i])) return i == index;
    }
    return false;
  }

  double get _climbRatio {
    final milestones = widget.detail.milestones;
    if (milestones.isEmpty) return 0;
    return milestones.where(_isMilestoneComplete).length / milestones.length;
  }

  String _trailSummary() {
    final milestones = widget.detail.milestones;
    if (milestones.isEmpty) return '';
    final done = milestones.where(_isMilestoneComplete).length;
    return '$done of ${milestones.length} milestones';
  }

  Widget _path(BuildContext context) {
    final milestones = widget.detail.milestones;
    if (milestones.isEmpty) {
      return _card(
        child: Text(
          'This challenge has no configured milestones yet.',
          style: AppFonts.body(color: t.muted, fontSize: 15),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        children: [
          for (var i = 0; i < milestones.length; i++)
            _trailStep(milestones[i], i, isLast: i == milestones.length - 1),
        ],
      ),
    );
  }

  Widget _trailStep(
    ChallengeMilestone milestone,
    int index, {
    required bool isLast,
  }) {
    final done = _isMilestoneComplete(milestone);
    final current = !done && _isNextMilestone(index);
    final number = milestone.orderIndex.toString().padLeft(2, '0');

    final Widget node;
    if (done) {
      node = Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(
            color: t.light ? AppColors.lightTextPrimary : AppColors.primary,
            width: 1.5,
          ),
        ),
        child: const Icon(Icons.check_rounded, size: 22, color: AppColors.dark),
      );
    } else if (current) {
      node = Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: t.light ? AppColors.limeWash : AppColors.primaryMuted,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: _btnBg, shape: BoxShape.circle),
          child: Text(
            number,
            style: AppFonts.body(
              color: t.light ? AppColors.primary : AppColors.dark,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    } else {
      node = Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: t.border, width: 1.5),
        ),
        child: Text(number, style: AppFonts.body(color: t.muted, fontSize: 16)),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => widget.onOpenMilestone(index),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  node,
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: done ? _btnBg : t.border,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      milestone.title,
                      style: AppFonts.body(
                        color: done || current ? t.ink : t.muted,
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                    if (milestone.description.isNotEmpty &&
                        (done || current)) ...[
                      const SizedBox(height: 4),
                      Text(
                        milestone.description,
                        style: AppFonts.body(
                          color: t.muted,
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (current) ...[
                      const SizedBox(height: 14),
                      _milestoneProgressCard(milestone),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _milestoneProgressCard(ChallengeMilestone milestone) {
    final primary = widget.detail.primaryMetric;
    final target = milestone.targetValue;
    final double ratio;
    final String left;
    if (target != null && target > 0) {
      final cur = milestone.currentValue ?? _progressMetricValue ?? 0;
      ratio = (cur / target).clamp(0.0, 1.0);
      left =
          '${_formatValue(cur)} / ${_formatValue(target)} ${primary?.unit ?? ''}'
              .trim();
    } else {
      ratio = _milestoneProgress(milestone);
      final total = milestone.totalResourceCount > 0
          ? milestone.totalResourceCount
          : milestone.resources.length;
      final completed = milestone.totalResourceCount > 0
          ? milestone.completedResourceCount
          : milestone.resources.where((r) => r.completed).length;
      left = '$completed / $total steps';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          _progressBar(ratio),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(left, style: AppFonts.body(color: t.muted, fontSize: 15)),
              Text(
                'Next up',
                style: AppFonts.body(color: t.muted, fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressBar(double ratio) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: Stack(
      children: [
        Container(
          height: 8,
          color: t.light ? AppColors.lightSurfaceAlt : AppColors.surfaceAlt,
        ),
        FractionallySizedBox(
          widthFactor: ratio.clamp(0.02, 1.0),
          child: Container(height: 8, color: _btnBg),
        ),
      ],
    ),
  );

  // --------------------------------------------------------------- people

  Widget _people(BuildContext context) {
    final detail = widget.detail;
    const avatarColors = [
      Color(0xFFC08F62),
      Color(0xFFA24FBF),
      Color(0xFF3F7A57),
      Color(0xFF4A4A48),
    ];
    final shown = detail.participants.take(4).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: t.inkSurface,
        borderRadius: BorderRadius.circular(28),
        border: t.light ? null : Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${detail.completedParticipantCount}',
                style: AppFonts.body(
                  color: Colors.white,
                  fontSize: 52,
                  height: 1,
                  letterSpacingEm: -0.03,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'have cleared it',
                style: AppFonts.body(
                  color: Colors.white.withValues(alpha: .7),
                  fontSize: 26,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (shown.isNotEmpty) ...[
                SizedBox(
                  height: 44,
                  width: 44.0 + 30.0 * (shown.length - 1),
                  child: Stack(
                    children: [
                      for (var i = 0; i < shown.length; i++)
                        Positioned(
                          left: 30.0 * i,
                          child: _avatar(
                            shown[i],
                            avatarColors[i % avatarColors.length],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Text(
                  '${detail.participantCount} nerds are on this trial',
                  style: AppFonts.body(
                    color: Colors.white.withValues(alpha: .7),
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar(ChallengeParticipant person, Color fallback) {
    final name = person.displayName ?? person.username ?? '?';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: fallback,
        shape: BoxShape.circle,
        border: Border.all(color: t.inkSurface, width: 2),
        image: person.avatarUrl == null
            ? null
            : DecorationImage(
                image: NetworkImage(person.avatarUrl!),
                fit: BoxFit.cover,
              ),
      ),
      alignment: Alignment.center,
      child: person.avatarUrl == null
          ? Text(
              name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
              style: AppFonts.body(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            )
          : null,
    );
  }

  // ------------------------------------------------------------ discussion

  Widget _discussionSection(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Material(
      color: t.card,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => setState(() => _discussionOpen = true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: t.light
                        ? AppColors.lightTextPrimary
                        : AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Discussion',
                  style: AppFonts.body(
                    color: t.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.forum_rounded, color: t.muted, size: 24),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _discussionOverlay(BuildContext context) => ColoredBox(
    color: t.bg,
    child: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 10, 6),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Discussion',
                    style: AppFonts.body(
                      color: t.ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      letterSpacingEm: -0.02,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close discussion',
                  onPressed: () => setState(() => _discussionOpen = false),
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: t.ink),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Questions, ideas, and useful breakthroughs.',
                style: AppFonts.body(color: t.muted, fontSize: 14),
              ),
            ),
          ),
          Divider(height: 1, color: t.border),
          Expanded(
            child: ChallengeDiscussion(
              challengeSlug: widget.challengeSlug,
              service: widget.discussionsService,
              canPost: widget.discussionCanPost,
              currentUsername: widget.currentUsername,
              initialDiscussionId: widget.initialDiscussionId,
              initialReplyId: widget.initialReplyId,
            ),
          ),
        ],
      ),
    ),
  );

  // ------------------------------------------------------ inactive content

  Widget _why(BuildContext context) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.challenge.shortDescription,
          style: AppFonts.body(
            color: t.ink,
            fontSize: 21,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
        ),
        if (widget.challenge.fullDescription.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            widget.challenge.fullDescription,
            style: AppFonts.body(color: t.muted, fontSize: 15, height: 1.5),
          ),
        ],
      ],
    ),
  );

  Widget _verification(BuildContext context) {
    final verification = widget.detail.verification;
    final requirements = widget.detail.effectiveRequirements;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                verification.instructions.isEmpty
                    ? 'Submit evidence that proves you completed this challenge.'
                    : verification.instructions,
                style: AppFonts.body(
                  color: t.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your result is signed to your profile and reviewed according to the challenge verification rules.',
                style: AppFonts.body(
                  color: t.muted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              if (requirements.isNotEmpty || verification.requiredRuns > 0) ...[
                const SizedBox(height: 10),
                Divider(height: 1, color: t.border),
                for (final requirement in requirements)
                  _requirement(
                    requirement.label.isEmpty
                        ? requirement.metricKey
                        : requirement.label,
                    '${_formatValue(requirement.value)} ${requirement.unit}'
                        .trim(),
                  ),
                if (verification.requiredRuns > 0)
                  _requirement(
                    'Verified runs needed',
                    '${verification.requiredRuns}',
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _proofStep(
          '01',
          'A baseline first.',
          'Your first result is logged so you can see how far you move.',
        ),
        _proofStep(
          '02',
          'The path opens.',
          '${widget.detail.milestones.length} milestones are matched to your stage.',
        ),
        _proofStep(
          '03',
          '${widget.challenge.auraPoints} aura is on the table.',
          'Paid when you prove it, not before.',
        ),
      ],
    );
  }

  Widget _requirement(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppFonts.body(color: t.muted, fontSize: 14),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppFonts.body(
              color: t.ink,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _proofStep(String number, String title, String detail) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.light ? AppColors.limeWash : AppColors.primaryMuted,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: AppFonts.body(
              color: t.accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$title ',
                    style: TextStyle(color: t.ink, fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: detail,
                    style: TextStyle(color: t.muted),
                  ),
                ],
              ),
              style: AppFonts.body(color: t.ink, fontSize: 15, height: 1.4),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _finalCta(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
    child: active
        ? Center(
            child: TextButton(
              onPressed: widget.onDrop,
              style: TextButton.styleFrom(foregroundColor: t.muted),
              child: const Text('Drop this trial'),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready to take on ${widget.challenge.title}?',
                style: AppFonts.body(
                  color: t.ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                  letterSpacingEm: -0.03,
                ),
              ),
              const SizedBox(height: 20),
              _tall(
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.accepting ? null : widget.onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: _btnBg,
                      foregroundColor: _btnFg,
                      shape: const StadiumBorder(),
                      textStyle: AppFonts.body(
                        color: t.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('Accept the challenge'),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: widget.onToggleSave,
                  style: TextButton.styleFrom(foregroundColor: t.muted),
                  child: Text(widget.saved ? 'Saved' : 'Save for later'),
                ),
              ),
            ],
          ),
  );

  // -------------------------------------------------------------- helpers

  String _formatValue(double? value) {
    if (value == null) return '--';
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
  }

  double? get _progressMetricValue {
    final value = widget.detail.progress.currentValue;
    return value is num ? value.toDouble() : double.tryParse('$value');
  }

  double? get _progressBaselineValue {
    final value = widget.detail.progress.baselineValue;
    return value is num ? value.toDouble() : double.tryParse('$value');
  }
}
