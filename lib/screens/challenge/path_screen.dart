import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/challenge.dart';
import '../../models/challenge_detail.dart';
import '../../models/participation.dart';
import '../../providers/app_state_providers.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';

class PathScreen extends ConsumerStatefulWidget {
  final Challenge challenge;
  final ChallengeDetail detail;
  final int initialMilestoneIndex;
  final Participation? participation;

  const PathScreen({
    super.key,
    required this.challenge,
    required this.detail,
    this.initialMilestoneIndex = 0,
    this.participation,
  });

  @override
  ConsumerState<PathScreen> createState() => _PathScreenState();
}

class _PathScreenState extends ConsumerState<PathScreen> {
  late final List<_PathMilestone> _milestones;
  var _selectedMilestone = 0;

  @override
  void initState() {
    super.initState();
    _milestones = _buildMilestones();
    _selectedMilestone = _milestones.isEmpty
      ? 0
      : widget.initialMilestoneIndex.clamp(0, _milestones.length - 1);
  }

  List<_PathMilestone> _buildMilestones() {
    final apiMilestones = widget.detail.milestones;
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

  int get _completedCount => _milestone.resources.where((resource) => resource.completed).length;

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
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('YOUR PATH')),
        body: const Center(
          child: Text('This challenge has no configured milestones yet.'),
        ),
      );
    }
    final resources = _milestone.resources;
    final totalCount = _milestoneTotalCount;
    final progress = totalCount == 0 ? 0.0 : _milestoneCompletedCount / totalCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background.withValues(alpha: .94),
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('YOUR PATH', style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
          ),
          SliverToBoxAdapter(child: _header(progress)),
          SliverToBoxAdapter(child: _milestoneRail()),
          SliverToBoxAdapter(
            child: resources.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(22),
                    child: Text('No resources are configured for this milestone.'),
                  )
                : _resourceList(resources),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 38)),
        ],
      ),
    );
  }

  Widget _header(double progress) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('THE GRIND', style: TextStyle(color: AppColors.primary, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
      const SizedBox(height: 18),
      Text(widget.challenge.title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 28),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('$_milestoneCompletedCount', style: const TextStyle(fontSize: 64, height: .82, fontWeight: FontWeight.w800, letterSpacing: -4)),
        const Padding(padding: EdgeInsets.only(bottom: 5), child: Text(' / ', style: TextStyle(color: AppColors.textSecondary, fontSize: 24))),
        Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('$_milestoneTotalCount COMPLETE', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 14),
      Stack(children: [
        Container(height: 5, color: AppColors.border),
        FractionallySizedBox(widthFactor: progress, child: Container(height: 5, color: AppColors.primary)),
      ]),
      const SizedBox(height: 12),
      Text('${(progress * 100).round()}% of this milestone complete', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      if (_milestone.loggedMinutes > 0) ...[
        const SizedBox(height: 6),
        Text('${_milestone.loggedMinutes} minutes logged', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ],
    ]),
  );

  Widget _milestoneRail() => Container(
    decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border), bottom: BorderSide(color: AppColors.border))),
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: SizedBox(
      height: 62,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        scrollDirection: Axis.horizontal,
        itemCount: _milestones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => InkWell(
          onTap: () => setState(() => _selectedMilestone = index),
          child: Container(
            width: 180,
            padding: const EdgeInsets.all(12),
            color: index == _selectedMilestone ? AppColors.primaryMuted : Colors.transparent,
            child: Row(children: [
              Text('${(index + 1).toString().padLeft(2, '0')}', style: TextStyle(color: index == _selectedMilestone ? AppColors.primary : AppColors.textSecondary, fontWeight: FontWeight.w800)),
              const SizedBox(width: 12),
              Expanded(child: Text(_milestones[index].title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: index == _selectedMilestone ? AppColors.primary : AppColors.textPrimary))),
            ]),
          ),
        ),
      ),
    ),
  );

  Widget _resourceList(List<_PathResource> resources) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 32, 22, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('MILESTONE ${(_selectedMilestone + 1).toString().padLeft(2, '0')}', style: const TextStyle(color: AppColors.primary, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      Text(_milestone.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.0)),
      const SizedBox(height: 10),
      Text(_milestone.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.35)),
      const SizedBox(height: 22),
      for (var index = 0; index < resources.length; index++) _resourceTile(resources[index], index),
    ]),
  );

  Widget _resourceTile(_PathResource resource, int index) => Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: resource.completed || resource.saving
              ? null
              : () => _completeResource(resource),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: resource.saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(resource.completed ? Icons.check_circle : Icons.radio_button_unchecked, color: resource.completed ? AppColors.primary : AppColors.textDim, size: 22),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${(index + 1).toString().padLeft(2, '0')}  ${resource.type}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          Text(resource.title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: resource.completed ? AppColors.textSecondary : AppColors.textPrimary, decoration: resource.completed ? TextDecoration.lineThrough : null)),
          const SizedBox(height: 5),
          Text(resource.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3)),
        ])),
        const SizedBox(width: 10),
        IconButton(
          tooltip: 'Open resource',
          onPressed: () => _openResource(resource),
          icon: const Icon(Icons.open_in_new, size: 19),
          color: AppColors.primary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ]),
  );

  Future<void> _openResource(_PathResource resource) async {
    final uri = Uri.tryParse(resource.url);
    if (uri == null || !uri.hasScheme) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This resource link is not available yet.')),
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
      builder: (_) => _CompletionDialog(metric: widget.detail.primaryMetric),
    );
    if (input == null) return;

    final wasCompleted = resource.completed;
    setState(() {
      resource.completed = true;
      resource.saving = true;
    });

    final milestone = widget.detail.milestones.isEmpty
        ? null
        : widget.detail.milestones[_selectedMilestone];
    final participation = widget.participation;

    try {
      if (participation != null &&
          milestone != null &&
          milestone.id.isNotEmpty &&
          resource.id.isNotEmpty) {
        await ref.read(participationControllerProvider.notifier).completeResource(
          participation.id,
          milestoneId: milestone.id,
          resourceId: resource.id,
          resourceMinutes: input.resourceMinutes,
          note: input.note,
          logProgress: input.logProgress,
        );
        if (input.logProgress && input.metricValue != null) {
          final metric = widget.detail.primaryMetric;
          if (metric != null) {
            await ref.read(participationControllerProvider.notifier).logMetricAttempt(
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
          resource.saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error, stackTrace) {
      debugPrint('Resource completion failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          resource.completed = wasCompleted;
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
}

class _PathMilestone {
  final String title;
  final String description;
  final int completedResourceCount;
  final int totalResourceCount;
  final int loggedMinutes;
  final List<_PathResource> resources;

  const _PathMilestone({
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

  _PathResource(this.title, this.type, this.description, this.url, this.completed, {this.id = ''});
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
    Navigator.of(context).pop(_CompletionInput(
      resourceMinutes: resourceMinutes,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      logProgress: _logProgress,
      metricValue: metricValue,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mark resource complete'),
    content: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _resourceMinutes,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Minutes on this resource'),
        ),
        TextField(
          controller: _note,
          maxLines: 3,
          maxLength: 5000,
          decoration: const InputDecoration(labelText: 'Description (optional)'),
        ),
        if (widget.metric != null)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _logProgress,
            onChanged: (value) => setState(() => _logProgress = value ?? false),
            title: const Text('Log my measured progress'),
          ),
        if (_logProgress && widget.metric != null)
          TextField(
            controller: _metricValue,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Progress (${widget.metric!.unit})'),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ),
      ]),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _submit, child: const Text('Complete resource')),
    ],
  );
}