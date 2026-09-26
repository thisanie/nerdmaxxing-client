import 'package:flutter/material.dart';

import '../../models/challenge.dart';
import '../../models/challenge_detail.dart';
import '../../models/participation.dart';
import '../../theme/app_theme.dart';

class ChallengeJourney extends StatefulWidget {
  final Challenge challenge;
  final ChallengeDetail detail;
  final Participation? participation;
  final VoidCallback onAccept;
  final VoidCallback onTrain;
  final VoidCallback onProve;
  final VoidCallback? onDecline;
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
    required this.onOpenMilestone,
    required this.accepting,
    this.invited = false,
    this.onRefresh,
  });

  @override
  State<ChallengeJourney> createState() => _ChallengeJourneyState();
}

class _ChallengeJourneyState extends State<ChallengeJourney> {
  bool _saved = false;

  bool get active => widget.participation != null;

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: widget.onRefresh ?? () async {},
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background.withValues(alpha: .92),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              active ? 'ON THE TRIAL' : 'DISCOVER',
              style: const TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700),
            ),
            actions: [
              IconButton(
                tooltip: _saved ? 'Saved' : 'Save challenge',
                onPressed: () => setState(() => _saved = !_saved),
                icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border, size: 21),
              ),
            ],
          ),
          SliverToBoxAdapter(child: _hero(context, challenge)),
          if (active) SliverToBoxAdapter(child: _section(context, 'NEXT MILESTONE', _nextMilestone(context))),
          if (active) SliverToBoxAdapter(child: _section(context, 'CHALLENGE PROGRESS', _challengeProgress(context))),
          if (!active) SliverToBoxAdapter(child: _section(context, 'WHY TAKE THIS ON?', _why(context))),
          SliverToBoxAdapter(child: _section(context, active ? 'THE GRIND' : 'THE PATH', _path(context))),
          if (active) SliverToBoxAdapter(child: _section(context, 'RECENT ATTEMPTS', _attempts(context))),
          SliverToBoxAdapter(child: _section(context, 'PEOPLE ON THIS TRIAL', _people(context))),
          if (!active) SliverToBoxAdapter(child: _section(context, 'HOW YOU PROVE IT', _verification(context))),
          if (active) SliverToBoxAdapter(child: _section(context, 'PROVE IT', _verification(context))),
          SliverToBoxAdapter(child: _finalCta(context)),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, Challenge challenge) {
    final primary = widget.detail.primaryMetric;
    final current = _formatValue(primary?.current);
    final target = _formatValue(primary?.target);
    final unit = primary?.unit ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 38),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _eyebrow(challenge.difficultyLevel)),
          const SizedBox(width: 12),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: _eyebrow(active ? 'ACCEPTED' : 'PERFORMANCE TRIAL'),
            ),
          ),
        ]),
        const SizedBox(height: 54),
        if (active) ...[
          _eyebrow('YOU ARE HERE'),
          const SizedBox(height: 8),
          _number(current, 112, AppColors.textPrimary),
          Row(children: [
            _numberLabel(unit.toUpperCase()),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                primary?.baseline == null || primary?.current == null
                    ? 'Progress is being tracked'
                    : '↑ ${_formatValue(primary!.current! - primary.baseline!)} $unit since starting',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _metricStats(),
          const SizedBox(height: 28),
          if (primary != null && primary.target != null && primary.current != null)
            _progressRuler(primary),
        ] else ...[
          _number(target, 148, AppColors.primary),
          _numberLabel(unit.toUpperCase()),
          const SizedBox(height: 24),
          _eyebrow('THE CHALLENGE'),
          const SizedBox(height: 12),
          Text(
            challenge.shortDescription,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 22, height: 1.15),
          ),
          const SizedBox(height: 28),
          Row(children: [
            _fact('DIFFICULTY', challenge.difficultyLevel),
            _fact('EFFORT', challenge.effortLabel),
            _fact('REWARD', '+${challenge.auraPoints}', accent: true),
          ]),
        ],
        const SizedBox(height: 30),
        Row(children: [
          Expanded(child: FilledButton(onPressed: widget.accepting ? null : (active ? widget.onTrain : widget.onAccept), child: Text(widget.accepting ? 'ACCEPTING...' : active ? 'TRAIN' : 'ACCEPT THE CHALLENGE'))),
          if (active) ...[
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton(onPressed: widget.onProve, child: const Text('PROVE IT'))),
          ] else ...[
            const SizedBox(width: 10),
            IconButton(onPressed: () => setState(() => _saved = !_saved), icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border)),
          ],
        ]),
        if (!active) ...[
          const SizedBox(height: 22),
          Text(
            '${widget.detail.participantCount} nerds are on this trial  ·  ${widget.detail.completedParticipantCount} have cleared it',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (widget.invited && widget.onDecline != null)
            TextButton(onPressed: widget.onDecline, child: const Text('Decline invitation')),
        ],
      ]),
    );
  }

  Widget _challengeProgress(BuildContext context) {
    final milestones = widget.detail.milestones;
    final completed = milestones.where(_isMilestoneComplete).length;
    final total = milestones.length;
    final ratio = total == 0 ? 0.0 : completed / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _number('$completed', 72, AppColors.textPrimary),
            const Padding(
              padding: EdgeInsets.only(bottom: 5),
              child: Text(' / ', style: TextStyle(color: AppColors.textSecondary, fontSize: 24)),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '$total MILESTONES',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _progressBar(ratio),
        const SizedBox(height: 12),
        Text(
          total == 0
              ? 'No milestones configured yet.'
              : '${(ratio * 100).round()}% of the challenge complete',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  bool _isMilestoneComplete(ChallengeMilestone milestone) {
    final total = milestone.totalResourceCount > 0
        ? milestone.totalResourceCount
        : milestone.resources.length;
    final completed = milestone.totalResourceCount > 0
        ? milestone.completedResourceCount
        : milestone.resources.where((resource) => resource.completed).length;
    return total > 0 && completed >= total;
  }

  bool _isNextMilestone(int index) {
    for (var milestoneIndex = 0; milestoneIndex < widget.detail.milestones.length; milestoneIndex++) {
      if (!_isMilestoneComplete(widget.detail.milestones[milestoneIndex])) {
        return milestoneIndex == index;
      }
    }
    return false;
  }

  Widget _nextMilestone(BuildContext context) {
    final milestone = widget.detail.milestones
      .where((item) => !_isMilestoneComplete(item))
        .firstOrNull;
    if (milestone == null) {
      return Text(
        'Keep logging progress to unlock your next milestone.',
        style: Theme.of(context).textTheme.bodyLarge,
      );
    }
    final primary = widget.detail.primaryMetric;
    final target = milestone.targetValue ?? primary?.target ?? 0;
    final current = milestone.currentValue ?? primary?.current ?? 0;
    final ratio = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(milestone.title, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(milestone.description, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 22),
        _progressBar(ratio),
        const SizedBox(height: 12),
        Text(
          '${_formatValue(current)} / ${_formatValue(target)} ${primary?.unit ?? ''}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _why(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(widget.challenge.shortDescription, style: const TextStyle(fontSize: 27, height: 1.08, fontWeight: FontWeight.w700)),
    const SizedBox(height: 20),
    Text(widget.challenge.fullDescription, style: Theme.of(context).textTheme.bodyLarge),
    const SizedBox(height: 24),
    Row(children: [
      _fact('DIFFICULTY', widget.challenge.difficultyLevel),
      _fact('EFFORT', widget.challenge.effortLabel),
      _fact('AURA', '+${widget.challenge.auraPoints}', accent: true),
    ]),
  ]);

  Widget _path(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: widget.detail.milestones.isEmpty
        ? [Text('This challenge has no configured milestones yet.', style: Theme.of(context).textTheme.bodyLarge)]
        : [
            for (var index = 0; index < widget.detail.milestones.length; index++)
              _milestoneStep(widget.detail.milestones[index], index),
          ],
  );

  Widget _milestoneStep(ChallengeMilestone milestone, int index) => InkWell(
    onTap: () => widget.onOpenMilestone(index),
    child: _step(
      milestone.orderIndex.toString().padLeft(2, '0'),
      milestone.title,
      milestone.description,
      _isMilestoneComplete(milestone),
      current: _isNextMilestone(index),
    ),
  );

  Widget _attempts(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: widget.detail.attempts.isEmpty
        ? [Text('No attempts logged yet.', style: Theme.of(context).textTheme.bodyLarge)]
        : [
            for (var index = 0; index < widget.detail.attempts.length; index++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Text('#${widget.detail.attempts.length - index}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(width: 22),
                    Expanded(
                      child: Text(
                        _attemptSummary(widget.detail.attempts[index]),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
  );

  Widget _people(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          for (final person in widget.detail.participants.take(5))
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: CircleAvatar(
                radius: 18,
                backgroundImage: person.avatarUrl == null ? null : NetworkImage(person.avatarUrl!),
                backgroundColor: AppColors.surfaceAlt,
                child: person.avatarUrl == null
                    ? Text((person.displayName ?? person.username ?? '?').substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 11))
                    : null,
              ),
            ),
          const SizedBox(width: 8),
          Text('${widget.detail.participantCount} nerds here', style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
      const SizedBox(height: 18),
      Text('${widget.detail.completedParticipantCount} have cleared it.', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
    ],
  );

  Widget _verification(BuildContext context) {
    final verification = widget.detail.verification;
    final requirements = widget.detail.effectiveRequirements;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(
      verification.instructions.isEmpty
          ? 'Submit evidence that proves you completed this challenge.'
          : verification.instructions,
      style: const TextStyle(fontSize: 25, height: 1.08, fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 18),
    Text(
      active
          ? 'Your result is checked against the challenge requirements.'
          : 'Your result is signed to your profile and reviewed according to the challenge verification rules.',
      style: Theme.of(context).textTheme.bodyLarge,
    ),
    if (!active) ...[
      const SizedBox(height: 24),
      for (final requirement in requirements)
        _requirement(
          requirement.label.isEmpty ? requirement.metricKey : requirement.label,
          '${_formatValue(requirement.value)} ${requirement.unit}'.trim(),
        ),
      if (verification.requiredRuns > 0)
        _requirement('VERIFIED RUNS NEEDED', '${verification.requiredRuns}'),
      const SizedBox(height: 24),
      _proofStep('01', 'A baseline first.', 'Your first result is logged so you can see how far you move.'),
      _proofStep('02', 'The path opens.', '${widget.detail.milestones.length} milestones are matched to your stage.'),
      _proofStep('03', '${widget.challenge.auraPoints} aura is on the table.', 'Paid when you prove it, not before.'),
    ],
    if (active) ...[const SizedBox(height: 24), OutlinedButton.icon(onPressed: widget.onProve, icon: const Icon(Icons.arrow_forward, size: 17), label: const Text('BEGIN VERIFIED TEST'))],
  ]);
  }

  Widget _requirement(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 13),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _proofStep(String number, String title, String detail) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(number, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
      const SizedBox(width: 18),
      Expanded(child: Text.rich(TextSpan(children: [
        TextSpan(text: '$title ', style: const TextStyle(fontWeight: FontWeight.w700)),
        TextSpan(text: detail, style: const TextStyle(color: AppColors.textSecondary)),
      ]))),
    ]),
  );

  Widget _finalCta(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 38, 22, 46),
    child: active
        ? TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('DROP THIS TRIAL'))
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ready to take on ${widget.challenge.title}?', style: const TextStyle(fontSize: 40, height: .95, fontWeight: FontWeight.w800, letterSpacing: -2)),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: widget.accepting ? null : widget.onAccept, child: const Text('ACCEPT THE CHALLENGE'))),
            const SizedBox(height: 8),
            Center(child: TextButton(onPressed: () => setState(() => _saved = !_saved), child: Text(_saved ? 'SAVED' : 'SAVE FOR LATER'))),
          ]),
  );

  Widget _section(BuildContext context, String title, Widget child) => Container(decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))), padding: const EdgeInsets.fromLTRB(22, 34, 22, 38), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: AppColors.primary, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)), const SizedBox(height: 20), child]));
  Widget _eyebrow(String text) => Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1.7, fontWeight: FontWeight.w600));
  Widget _number(String text, double size, Color color) => Text(text, style: TextStyle(color: color, fontSize: size, height: .78, fontWeight: FontWeight.w800, letterSpacing: -7));
  Widget _numberLabel(String text) => Text(text, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1));
  Widget _stat(String label, String value, {bool warning = false}) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_eyebrow(label), const SizedBox(height: 7), Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: warning ? AppColors.warning : AppColors.textPrimary))]));
  Widget _fact(String label, String value, {bool accent = false}) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_eyebrow(label), const SizedBox(height: 8), Text(value, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: accent ? AppColors.primary : AppColors.textPrimary))]));
  Widget _step(String no, String title, String detail, bool done, {bool current = false}) => Container(decoration: BoxDecoration(border: const Border(bottom: BorderSide(color: AppColors.border)), color: current ? AppColors.primary.withValues(alpha: .08) : null), padding: const EdgeInsets.symmetric(vertical: 18), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(no, style: TextStyle(color: done || current ? AppColors.primary : AppColors.textSecondary, fontSize: 30, fontWeight: FontWeight.w800)), const SizedBox(width: 18), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: done ? AppColors.textSecondary : AppColors.textPrimary, decoration: done ? TextDecoration.lineThrough : null)), const SizedBox(height: 4), Text(detail, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)), const SizedBox(height: 12), _progressBar(done ? 1 : current ? .5 : 0)])), const SizedBox(width: 14), Text(done ? '✓' : current ? '→' : '→', style: TextStyle(color: done || current ? AppColors.primary : AppColors.textSecondary, fontSize: 22))]));

  Widget _progressBar(double ratio) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: Stack(children: [
      Container(height: 6, color: AppColors.border),
      FractionallySizedBox(widthFactor: ratio.clamp(0.0, 1.0), child: Container(height: 6, color: AppColors.primary)),
    ]),
  );
  Widget _progressRuler(ChallengeMetric metric) {
    final current = metric.current ?? 0;
    final target = metric.target ?? 0;
    final ratio = target <= 0
        ? 0.0
        : (current / target).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('START ${_formatValue(metric.baseline)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            Text('CURRENT ${_formatValue(metric.current)}', style: const TextStyle(color: AppColors.primary, fontSize: 11)),
            Text('TARGET ${_formatValue(metric.target)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 10),
        Stack(children: [
          Container(height: 4, color: AppColors.border),
          FractionallySizedBox(widthFactor: ratio, child: Container(height: 4, color: AppColors.primary)),
        ]),
      ],
    );
  }

  String _formatValue(double? value) {
    if (value == null) return '--';
    return value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);
  }

  Widget _metricStats() {
    final metrics = widget.detail.metricDefinitions
        .where((metric) => metric.current != null)
        .take(4)
        .toList();
    if (metrics.isEmpty) {
      return const Text(
        'No metric progress logged yet.',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final metric in metrics)
          _stat(metric.label.toUpperCase(), _formatMetric(metric, metric.current)),
      ],
    );
  }

  String _formatMetric(ChallengeMetric metric, double? value) {
    final formatted = _formatValue(value);
    if (formatted == '--' || metric.unit.isEmpty) return formatted;
    return '$formatted ${metric.unit}';
  }

  String _attemptSummary(ChallengeAttempt attempt) {
    if (attempt.metrics.isEmpty) return 'No metric values recorded';
    return attempt.metrics.entries.map((entry) {
      final metric = widget.detail.metricDefinitions
          .where((item) => item.key == entry.key)
          .firstOrNull;
      if (metric == null) return '${entry.key}: ${_formatValue(entry.value)}';
      return '${metric.label}: ${_formatMetric(metric, entry.value)}';
    }).join('  ·  ');
  }
}
  