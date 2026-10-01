import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/challenge.dart';
import '../../models/challenge_detail.dart';
import '../../models/participation.dart';
import '../../providers/app_state_providers.dart';
import '../../services/api_client.dart';
import '../../services/token_storage.dart';
import '../../theme/app_theme.dart';

class PathScreen extends ConsumerStatefulWidget {
  final Challenge challenge;
  final ChallengeDetail detail;
  final int initialMilestoneIndex;
  final Participation? participation;
  final Future<ChallengeDetail> Function()? onRefresh;

  const PathScreen({
    super.key,
    required this.challenge,
    required this.detail,
    this.initialMilestoneIndex = 0,
    this.participation,
    this.onRefresh,
  });

  @override
  ConsumerState<PathScreen> createState() => _PathScreenState();
}

class _PathScreenState extends ConsumerState<PathScreen> {
  late final List<_PathMilestone> _milestones;
  late ChallengeDetail _detail;
  var _selectedMilestone = 0;
  var _claimingStreakCelebration = false;

  bool get _light => Theme.of(context).brightness == Brightness.light;
  Color get _ink => _light ? AppColors.lightTextPrimary : AppColors.textPrimary;
  Color get _muted =>
      _light ? AppColors.lightTextSecondary : AppColors.textSecondary;
  Color get _card => _light ? AppColors.lightSurface : AppColors.surface;
  Color get _border => _light ? AppColors.lightBorder : AppColors.border;
  Color get _hero => _light ? AppColors.limeWash : AppColors.primaryMuted;
  Color get _accent => _light ? AppColors.primaryLight : AppColors.primaryLight;
  Color get _buttonForeground => Theme.of(context).colorScheme.onPrimary;
  Color get _actionBackground => _light ? _ink : AppColors.primary;
  Color get _actionForeground => _light ? _buttonForeground : AppColors.dark;

  @override
  void initState() {
    super.initState();
    _detail = widget.detail;
    _milestones = _buildMilestones();
    _selectedMilestone = _milestones.isEmpty
        ? 0
        : widget.initialMilestoneIndex.clamp(0, _milestones.length - 1);
  }

  List<_PathMilestone> _buildMilestones() {
    final apiMilestones = _detail.milestones;
    if (apiMilestones.isEmpty) {
      return const [];
    }

    return [
      for (final milestone in apiMilestones)
        _PathMilestone(
          title: milestone.title,
          description: milestone.description,
          completedResourceCount: milestone.completedResourceCount,
          totalResourceCount: milestone.totalResourceCount,
          loggedMinutes: milestone.loggedMinutes,
          resources: milestone.resources.isEmpty
              ? _resourcesForMilestone(milestone.orderIndex)
              : [
                  for (final resource in milestone.resources)
                    _PathResource(
                      resource.title,
                      resource.resourceType,
                      resource.rationale,
                      resource.url,
                      resource.completed,
                      id: resource.id,
                    ),
                ],
        ),
    ];
  }

  List<_PathResource> _resourcesForMilestone(int orderIndex) {
    return const [];
  }

  _PathMilestone get _milestone => _milestones[_selectedMilestone];

  Future<void> _refresh() async {
    final detail = await widget.onRefresh?.call();
    if (!mounted || detail == null) return;
    setState(() {
      _detail = detail;
      _milestones
        ..clear()
        ..addAll(_buildMilestones());
      _selectedMilestone = _milestones.isEmpty
          ? 0
          : _selectedMilestone.clamp(0, _milestones.length - 1);
    });
  }

  int get _completedCount =>
      _milestone.resources.where((resource) => resource.completed).length;

  int get _milestoneCompletedCount => _milestone.totalResourceCount > 0
      ? _milestone.completedResourceCount
      : _completedCount;

  int get _milestoneTotalCount => _milestone.totalResourceCount > 0
      ? _milestone.totalResourceCount
      : _milestone.resources.length;

  @override
  Widget build(BuildContext context) {
    if (_milestones.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('YOUR PATH')),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 260),
              Center(
                child: Text('This challenge has no configured milestones yet.'),
              ),
            ],
          ),
        ),
      );
    }
    final resources = _milestone.resources;
    final totalCount = _milestoneTotalCount;
    final progress = totalCount == 0
        ? 0.0
        : _milestoneCompletedCount / totalCount;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                tooltip: 'Back',
                icon: Icon(Icons.arrow_back_rounded, size: 22, color: _ink),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'The Grind  ·  ',
                      style: TextStyle(color: _muted),
                    ),
                    TextSpan(
                      text:
                          'Milestone ${(_selectedMilestone + 1).toString().padLeft(2, '0')}',
                      style: TextStyle(color: _ink),
                    ),
                  ],
                ),
                style: AppFonts.body(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  tooltip: 'More options',
                  onPressed: () {},
                  icon: Icon(Icons.more_vert_rounded, size: 22, color: _ink),
                ),
              ],
            ),
            SliverToBoxAdapter(child: _header(progress)),
            SliverToBoxAdapter(child: _milestoneRail()),
            SliverToBoxAdapter(
              child: resources.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(22),
                      child: Text(
                        'No resources are configured for this milestone.',
                      ),
                    )
                  : _resourceList(resources),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 38)),
          ],
        ),
      ),
    );
  }

  Widget _header(double progress) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
    child: Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: _hero,
        borderRadius: BorderRadius.circular(32),
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
                  color: _muted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'YOU ARE HERE',
                  style: AppFonts.label(color: _ink, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _ink,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _milestone.totalResourceCount > 0
                      ? 'Goal · ${_milestone.totalResourceCount} tasks'
                      : 'Goal · ${_milestone.resources.length} tasks',
                  style: AppFonts.body(color: _hero, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_milestoneCompletedCount',
                style: AppFonts.poster(fontSize: 112, color: _ink, wdth: 100),
              ),
              const SizedBox(width: 8),
              Text(
                ' / $_milestoneTotalCount',
                style: AppFonts.body(color: _muted, fontSize: 36),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'done',
                  style: AppFonts.body(color: _ink, fontSize: 18),
                ),
              ),
            ],
          ),
          Text(
            _milestone.title,
            style: AppFonts.display(
              color: _ink,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          Text(
            _milestone.description,
            style: AppFonts.body(
              color: _ink.withValues(alpha: .75),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: List.generate(
              _milestoneTotalCount,
              (index) => Expanded(
                child: Container(
                  height: 8,
                  margin: EdgeInsets.only(
                    right: index == _milestoneTotalCount - 1 ? 0 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: index < _milestoneCompletedCount
                        ? _ink
                        : _hero.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed:
                  widget.participation != null &&
                      _detail.metricDefinitions.isNotEmpty
                  ? _logResult
                  : null,
              icon: Icon(Icons.bar_chart_rounded, color: _actionForeground),
              label: const Text('Log a result'),
              style: FilledButton.styleFrom(
                backgroundColor: _actionBackground,
                foregroundColor: _actionForeground,
                disabledBackgroundColor: _actionBackground.withValues(
                  alpha: .4,
                ),
                disabledForegroundColor: _actionForeground.withValues(
                  alpha: .7,
                ),
                shape: const StadiumBorder(),
                textStyle: AppFonts.body(
                  color: _actionForeground,
                  fontSize: 17,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _milestoneRail() => Container(
    padding: const EdgeInsets.fromLTRB(0, 22, 0, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'The Grind',
                  style: AppFonts.body(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${_milestones.length} milestones',
                style: AppFonts.body(color: _muted, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 84,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _milestones.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _milestoneChip(index),
          ),
        ),
      ],
    ),
  );

  Widget _milestoneChip(int index) => InkWell(
    onTap: () => setState(() => _selectedMilestone = index),
    child: Container(
      width: 190,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: index == _selectedMilestone ? _actionBackground : _card,
        border: index == _selectedMilestone
            ? null
            : Border.all(color: _border, width: 1.5),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _accent,
              shape: BoxShape.circle,
              border: Border.all(color: _ink, width: 2),
            ),
            child: Center(
              child: Text(
                (index + 1).toString().padLeft(2, '0'),
                style: AppFonts.body(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _milestones[index].title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.body(
                color: index == _selectedMilestone ? _actionForeground : _ink,
                fontSize: 15,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _resourceList(List<_PathResource> resources) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                'Your checklist',
                style: AppFonts.body(
                  color: _ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$_milestoneCompletedCount of $_milestoneTotalCount done',
              style: AppFonts.body(color: _muted, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < resources.length; index++)
          _resourceTile(resources[index], index),
        if (_selectedMilestone < _milestones.length - 1) _lockedNextMilestone(),
      ],
    ),
  );

  Widget _resourceTile(_PathResource resource, int index) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _card,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      children: [
        if (resource.type.toUpperCase() == 'VIDEO') ...[
          _videoPreview(resource),
          const SizedBox(height: 14),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: resource.completed || resource.saving
                  ? null
                  : () => _completeResource(resource),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: resource.completed ? _accent : _card,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: resource.completed ? _ink : _muted,
                    width: 2,
                  ),
                ),
                child: resource.saving
                    ? Padding(
                        padding: const EdgeInsets.all(5),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _ink,
                        ),
                      )
                    : resource.completed
                    ? Icon(Icons.check_rounded, size: 16, color: _ink)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${(index + 1).toString().padLeft(2, '0')} / ${resource.type.toUpperCase()}',
                    style: AppFonts.label(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    resource.title,
                    style:
                        AppFonts.display(
                          color: resource.completed ? _muted : _ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          wdth: 95,
                        ).copyWith(
                          decoration: resource.completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    resource.description,
                    style: AppFonts.body(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Open resource',
              onPressed: () => _openResource(resource),
              icon: Icon(
                resource.type.toUpperCase() == 'VIDEO'
                    ? Icons.play_arrow_rounded
                    : Icons.open_in_new_rounded,
                size: 19,
              ),
              color: _accent,
              style: IconButton.styleFrom(
                side: BorderSide(color: _ink, width: 1.5),
                shape: const CircleBorder(),
                minimumSize: const Size(44, 44),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _videoPreview(_PathResource resource) => InkWell(
    onTap: () => _openResource(resource),
    borderRadius: BorderRadius.circular(20),
    child: Container(
      width: double.infinity,
      height: 112,
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -20,
            bottom: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: .9),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 18,
            top: 14,
            child: Text(
              'VIDEO',
              style: AppFonts.label(
                color: _accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: _card, shape: BoxShape.circle),
              child: Icon(Icons.play_arrow_rounded, size: 28, color: _ink),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _openResource(_PathResource resource) async {
    final uri = Uri.tryParse(resource.url);
    if (uri == null || !uri.hasScheme) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This resource link is not available yet.'),
          ),
        );
      }
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this resource.')),
      );
    }
  }

  Future<void> _completeResource(_PathResource resource) async {
    final input = await showDialog<_CompletionInput>(
      context: context,
      builder: (_) => _CompletionDialog(metric: _detail.primaryMetric),
    );
    if (input == null) return;

    final wasCompleted = resource.completed;
    setState(() {
      resource.completed = true;
      resource.saving = true;
      if (!wasCompleted) _milestone.completedResourceCount++;
    });

    final milestone = _detail.milestones.isEmpty
        ? null
        : _detail.milestones[_selectedMilestone];
    final participation = widget.participation;

    try {
      if (participation != null &&
          milestone != null &&
          milestone.id.isNotEmpty &&
          resource.id.isNotEmpty) {
        await ref
            .read(participationControllerProvider.notifier)
            .completeResource(
              participation.id,
              milestoneId: milestone.id,
              resourceId: resource.id,
              resourceMinutes: input.resourceMinutes,
              note: input.note,
              logProgress: input.logProgress,
            );
        if (input.logProgress && input.metricValue != null) {
          final metric = _detail.primaryMetric;
          if (metric != null) {
            await ref
                .read(participationControllerProvider.notifier)
                .logMetricAttempt(
                  participation.id,
                  metricKey: metric.key,
                  value: input.metricValue!,
                  unit: metric.unit,
                  note: input.note,
                );
          }
        }
      }
      final completedResource = widget.challenge.resources.where(
        (candidate) => candidate.id == resource.id,
      );
      for (final candidate in completedResource) {
        candidate.completed = true;
      }
      if (milestone != null) {
        for (final candidate in milestone.resources) {
          if (candidate.id == resource.id) candidate.completed = true;
        }
      }
      if (!mounted) return;
      setState(() => resource.saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resource marked complete.')),
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          resource.completed = wasCompleted;
          if (!wasCompleted) _milestone.completedResourceCount--;
          resource.saving = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error, stackTrace) {
      debugPrint('Resource completion failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          resource.completed = wasCompleted;
          if (!wasCompleted) _milestone.completedResourceCount--;
          resource.saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kDebugMode
                  ? 'Resource save failed: $error'
                  : 'The resource could not be saved. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _logResult() async {
    final input = await showDialog<_MetricInput>(
      context: context,
      builder: (_) => _MetricDialog(metrics: _detail.metricDefinitions),
    );
    if (input == null || widget.participation == null) return;
    final previousStreak =
      ref.read(myStatsProvider).valueOrNull?.dayStreak ?? 0;

    try {
      await ref
          .read(participationControllerProvider.notifier)
          .logMetricAttempt(
            widget.participation!.id,
            metricKey: input.metric.key,
            value: input.value,
            unit: input.metric.unit,
            note: input.note,
          );
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Result logged.')));
      if (await _claimStreakCelebrationForToday()) {
        if (!mounted) return;
        await _showStreakCelebration(previousStreak + 1);
        if (!mounted) return;
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<bool> _claimStreakCelebrationForToday() async {
    if (_claimingStreakCelebration) return false;
    _claimingStreakCelebration = true;
    try {
      final userId = await TokenStorage().userId ?? 'anonymous';
      final preferences = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final date = '${today.year}-${today.month}-${today.day}';
      final key = 'nm_streak_celebration_${Uri.encodeComponent(userId)}';
      if (preferences.getString(key) == date) return false;
      await preferences.setString(key, date);
      return true;
    } finally {
      _claimingStreakCelebration = false;
    }
  }

  Future<void> _showStreakCelebration(int streak) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss streak celebration',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _StreakCelebration(streak: streak),
    );
  }

  Widget _lockedNextMilestone() {
    final next = _milestones[_selectedMilestone + 1];
    return CustomPaint(
      foregroundPainter: _DottedBorderPainter(
        color: _muted.withValues(alpha: .6),
        radius: 28,
      ),
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: _light ? AppColors.lightSurface : _card,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _muted, width: 1.5),
              ),
              child: Center(
                child: Text(
                  (_selectedMilestone + 2).toString().padLeft(2, '0'),
                  style: AppFonts.body(color: _muted, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Locked',
                    style: AppFonts.body(color: _muted, fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Finish this checklist to unlock ${next.title}.',
                    style: AppFonts.body(color: _muted, fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.lock_rounded, color: _muted, size: 22),
          ],
        ),
      ),
    );
  }
}

class _StreakCelebration extends StatefulWidget {
  final int streak;

  const _StreakCelebration({required this.streak});

  @override
  State<_StreakCelebration> createState() => _StreakCelebrationState();
}

class _StreakCelebrationState extends State<_StreakCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..forward();
    Future<void>.delayed(const Duration(milliseconds: 3400), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xED0A0A09),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = _controller.value;
            final flameIn = Curves.elasticOut.transform(
              (progress / .34).clamp(0.0, 1.0),
            );
            final glow = .82 + math.sin(progress * math.pi * 6) * .12;
            final roll = Curves.easeInOut.transform(
              ((progress - .28) / .22).clamp(0.0, 1.0),
            );
            return Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: MediaQuery.sizeOf(context).height / 2 - 130,
                  child: Transform.scale(
                    scale: glow,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0x8CC8F23C),
                            Color(0x00C8F23C),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  height: 260,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var index = 0; index < 16; index++)
                        _ember(index, progress),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Transform.scale(
                          scale: flameIn,
                          alignment: Alignment.bottomCenter,
                          child: const SizedBox(
                            width: 150,
                            height: 195,
                            child: CustomPaint(painter: _FlamePainter()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: MediaQuery.sizeOf(context).height / 2 + 130,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 120,
                        height: 100,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minWidth: 120,
                            maxWidth: 120,
                            minHeight: 200,
                            maxHeight: 200,
                            child: Transform.translate(
                              offset: Offset(0, -100 * roll),
                              child: Column(
                                children: [
                                  _streakNumber(widget.streak - 1),
                                  _streakNumber(widget.streak),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Text(
                        'DAY STREAK',
                        style: TextStyle(
                          color: Color(0xFFB9BCAB),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Opacity(
                        opacity: ((progress - .45) / .2).clamp(0.0, 1.0),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.all(Radius.circular(99)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            child: Text(
                              '+1 day',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      const Text(
                        'Tap anywhere to continue',
                        style: TextStyle(color: Color(0xFF8D9082), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _streakNumber(int value) => SizedBox(
    height: 100,
    child: Center(
      child: Text(
        '$value',
        style: AppFonts.display(
          color: Colors.white,
          fontSize: 88,
          fontWeight: FontWeight.w700,
          height: 1,
          letterSpacingEm: -.03,
        ),
      ),
    ),
  );

  Widget _ember(int index, double progress) {
    final travel = ((progress * 1.7 + index * .13) % 1).toDouble();
    final opacity = travel < .15 ? travel / .15 : 1 - travel;
    final left = 110 + math.sin(index * 2.1 + progress * 8) * 70;
    return Positioned(
      left: left,
      bottom: 54 + travel * 190,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Container(
          width: index.isEven ? 8 : 5,
          height: index.isEven ? 8 : 5,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  const _FlamePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale);
    final flame = Path()
      ..moveTo(50, 4)
      ..cubicTo(54, 28, 82, 44, 82, 80)
      ..cubicTo(82, 106, 68, 124, 50, 124)
      ..cubicTo(32, 124, 18, 106, 18, 80)
      ..cubicTo(18, 64, 26, 54, 34, 46)
      ..cubicTo(36, 56, 40, 60, 44, 62)
      ..cubicTo(42, 40, 42, 20, 50, 4)
      ..close();
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF2FF9A), AppColors.primary],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 130));
    final outline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(flame, fill);
    canvas.drawPath(flame, outline);

    final core = Path()
      ..moveTo(50, 62)
      ..cubicTo(53, 76, 68, 84, 68, 102)
      ..cubicTo(68, 114, 60, 122, 50, 122)
      ..cubicTo(40, 122, 32, 114, 32, 102)
      ..cubicTo(32, 92, 38, 86, 42, 78)
      ..cubicTo(44, 84, 46, 86, 50, 86)
      ..cubicTo(48, 76, 48, 70, 50, 62)
      ..close();
    canvas.drawPath(core, Paint()..color = const Color(0xFFFFFBE0));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PathMilestone {
  final String title;
  final String description;
  int completedResourceCount;
  final int totalResourceCount;
  final int loggedMinutes;
  final List<_PathResource> resources;

  _PathMilestone({
    required this.title,
    required this.description,
    required this.completedResourceCount,
    required this.totalResourceCount,
    required this.loggedMinutes,
    required this.resources,
  });
}

class _PathResource {
  final String title;
  final String type;
  final String description;
  final String url;
  final String id;
  bool completed;
  bool saving = false;

  _PathResource(
    this.title,
    this.type,
    this.description,
    this.url,
    this.completed, {
    this.id = '',
  });
}

class _CompletionInput {
  final int resourceMinutes;
  final String? note;
  final bool logProgress;
  final double? metricValue;

  const _CompletionInput({
    required this.resourceMinutes,
    required this.note,
    required this.logProgress,
    required this.metricValue,
  });
}

class _CompletionDialog extends StatefulWidget {
  final ChallengeMetric? metric;

  const _CompletionDialog({required this.metric});

  @override
  State<_CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<_CompletionDialog> {
  final _resourceMinutes = TextEditingController();
  final _note = TextEditingController();
  final _metricValue = TextEditingController();
  bool _logProgress = false;
  String? _error;

  @override
  void dispose() {
    _resourceMinutes.dispose();
    _note.dispose();
    _metricValue.dispose();
    super.dispose();
  }

  void _submit() {
    final resourceMinutes = int.tryParse(_resourceMinutes.text.trim());
    final metricValue = double.tryParse(_metricValue.text.trim());
    if (resourceMinutes == null || resourceMinutes <= 0) {
      setState(() => _error = 'Enter valid time for the resource.');
      return;
    }
    if (_logProgress && widget.metric != null && metricValue == null) {
      setState(() => _error = 'Enter the measured progress value.');
      return;
    }
    Navigator.of(context).pop(
      _CompletionInput(
        resourceMinutes: resourceMinutes,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        logProgress: _logProgress,
        metricValue: metricValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mark resource complete'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _resourceMinutes,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Minutes on this resource',
            ),
          ),
          TextField(
            controller: _note,
            maxLines: 3,
            maxLength: 5000,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
            ),
          ),
          if (widget.metric != null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _logProgress,
              onChanged: (value) =>
                  setState(() => _logProgress = value ?? false),
              title: const Text('Log my measured progress'),
            ),
          if (_logProgress && widget.metric != null)
            TextField(
              controller: _metricValue,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Progress (${widget.metric!.unit})',
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Complete resource')),
    ],
  );
}

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DottedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 5).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DottedBorderPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}

class _MetricInput {
  final ChallengeMetric metric;
  final double value;
  final String? note;

  const _MetricInput({required this.metric, required this.value, this.note});
}

class _MetricDialog extends StatefulWidget {
  final List<ChallengeMetric> metrics;

  const _MetricDialog({required this.metrics});

  @override
  State<_MetricDialog> createState() => _MetricDialogState();
}

class _MetricDialogState extends State<_MetricDialog> {
  final _value = TextEditingController();
  final _note = TextEditingController();
  late ChallengeMetric _metric;
  String? _error;

  @override
  void initState() {
    super.initState();
    _metric = widget.metrics.first;
  }

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_value.text.trim());
    if (value == null || value < 0) {
      setState(() => _error = 'Enter a valid result.');
      return;
    }
    Navigator.of(context).pop(
      _MetricInput(
        metric: _metric,
        value: value,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Log a result'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.metrics.length > 1)
            DropdownButtonFormField<ChallengeMetric>(
              initialValue: _metric,
              decoration: const InputDecoration(labelText: 'Metric'),
              items: [
                for (final metric in widget.metrics)
                  DropdownMenuItem(value: metric, child: Text(metric.label)),
              ],
              onChanged: (metric) {
                if (metric != null) setState(() => _metric = metric);
              },
            ),
          TextField(
            controller: _value,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _metric.label,
              suffixText: _metric.unit,
              hintText: 'e.g. 5',
            ),
          ),
          TextField(
            controller: _note,
            maxLength: 5000,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Log result')),
    ],
  );
}
