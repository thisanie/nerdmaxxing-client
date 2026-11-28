import 'package:flutter/material.dart' hide SnackBar;
import '../../widgets/app_snack_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/challenge.dart';
import '../../models/challenge_detail.dart';
import '../../models/participation.dart';
import '../../providers/app_state_providers.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/metric_attempt_dialog.dart';

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

  Brightness get _brightness => Theme.of(context).brightness;
  Color get _ink => HomePalette.textPrimary(_brightness);
  Color get _muted => HomePalette.textSecondary(_brightness);
  Color get _card => HomePalette.surface(_brightness);
  Color get _border => HomePalette.border(_brightness);
  Color get _accent => HomePalette.primary;

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
        gradient: const LinearGradient(
          colors: [HomePalette.primary, HomePalette.mint],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
                  color: HomePalette.ink,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'YOU ARE HERE',
                  style: AppFonts.label(
                    color: HomePalette.ink.withValues(alpha: .7),
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: HomePalette.ink,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _milestone.totalResourceCount > 0
                      ? 'Goal · ${_milestone.totalResourceCount} tasks'
                      : 'Goal · ${_milestone.resources.length} tasks',
                  style: AppFonts.body(color: HomePalette.primary, fontSize: 14),
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
                style: AppFonts.poster(
                  fontSize: 112,
                  color: HomePalette.ink,
                  wdth: 100,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                ' / $_milestoneTotalCount',
                style: AppFonts.body(
                  color: HomePalette.ink.withValues(alpha: .65),
                  fontSize: 36,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'done',
                  style: AppFonts.body(
                    color: HomePalette.ink.withValues(alpha: .75),
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          Text(
            _milestone.title,
            style: AppFonts.display(
              color: HomePalette.ink,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          Text(
            _milestone.description,
            style: AppFonts.body(
              color: HomePalette.ink.withValues(alpha: .75),
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
                        ? HomePalette.ink
                        : HomePalette.ink.withValues(alpha: .16),
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
              icon: const Icon(
                Icons.bar_chart_rounded,
                color: HomePalette.primary,
              ),
              label: const Text('Log a result'),
              style: FilledButton.styleFrom(
                backgroundColor: HomePalette.ink,
                foregroundColor: HomePalette.primary,
                disabledBackgroundColor: HomePalette.ink.withValues(
                  alpha: .4,
                ),
                disabledForegroundColor: HomePalette.primary.withValues(
                  alpha: .7,
                ),
                shape: const StadiumBorder(),
                textStyle: AppFonts.body(
                  color: HomePalette.primary,
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
        color: index == _selectedMilestone ? HomePalette.primary : _card,
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
              color: index == _selectedMilestone
                  ? HomePalette.ink
                  : _accent,
              shape: BoxShape.circle,
              border: Border.all(
                color: index == _selectedMilestone
                    ? HomePalette.ink
                    : _border,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                (index + 1).toString().padLeft(2, '0'),
                style: AppFonts.body(
                  color: index == _selectedMilestone
                      ? HomePalette.primary
                      : HomePalette.ink,
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
                color: index == _selectedMilestone ? HomePalette.ink : _ink,
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
                color: _brightness == Brightness.light
                  ? HomePalette.ink
                  : _accent,
              ),
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
        color: AppColors.lightTextPrimary,
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
                color: HomePalette.primary.withValues(alpha: .9),
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
                color: HomePalette.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: HomePalette.lightSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 28,
                color: AppColors.lightTextPrimary,
              ),
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
          SnackBar(
            content: Text('This resource link is not available yet.'),
          ),
        );
      }
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open this resource.')),
      );
    }
  }

  Future<void> _completeResource(_PathResource resource) async {
    final participation = widget.participation;
    final metrics = _detail.metricDefinitions;
    MetricAttemptInput? input;
    if (participation != null && metrics.isNotEmpty) {
      input = await showDialog<MetricAttemptInput>(
        context: context,
        builder: (dialogContext) => Theme(
          data: AppTheme.neutralActionTheme(Theme.of(dialogContext)),
          child: MetricAttemptDialog(metrics: metrics),
        ),
      );
      if (input == null) return;
    }

    final wasCompleted = resource.completed;
    setState(() {
      resource.completed = true;
      resource.saving = true;
      if (!wasCompleted) _milestone.completedResourceCount++;
    });

    final milestone = _detail.milestones.isEmpty
        ? null
        : _detail.milestones[_selectedMilestone];
    var completionSaved = false;

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
              note: input?.note,
            );
        completionSaved = true;
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
      if (completionSaved && participation != null && input != null) {
        await ref
            .read(participationControllerProvider.notifier)
            .logMetricAttempt(
              participation.id,
              metricKey: input.metric.key,
              value: input.value,
              unit: input.metric.unit,
              note: input.note,
            );
      }
      if (!mounted) return;
      setState(() => resource.saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resource marked complete.')),
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          if (!completionSaved) {
            resource.completed = wasCompleted;
            if (!wasCompleted) _milestone.completedResourceCount--;
          }
          resource.saving = false;
        });
        final message = completionSaved
            ? 'Resource completed, but progress could not be logged: ${error.message}'
            : error.message;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error, stackTrace) {
      debugPrint('Resource completion failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          if (!completionSaved) {
            resource.completed = wasCompleted;
            if (!wasCompleted) _milestone.completedResourceCount--;
          }
          resource.saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              completionSaved
                  ? 'Resource completed, but progress could not be logged.'
                  : kDebugMode
                  ? 'Resource save failed: $error'
                  : 'The resource could not be saved. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _logResult() async {
    final input = await showDialog<MetricAttemptInput>(
      context: context,
      builder: (dialogContext) => Theme(
        data: AppTheme.neutralActionTheme(Theme.of(dialogContext)),
        child: MetricAttemptDialog(metrics: _detail.metricDefinitions),
      ),
    );
    if (input == null || widget.participation == null) return;
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
          .showSnackBar(SnackBar(content: Text('Result logged.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
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
          color: _card,
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
