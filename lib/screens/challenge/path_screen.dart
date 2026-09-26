import 'package:flutter/material.dart';

import '../../models/challenge.dart';
import '../../models/challenge_detail.dart';
import '../../theme/app_theme.dart';

class PathScreen extends StatefulWidget {
  final Challenge challenge;
  final ChallengeDetail detail;
  final int initialMilestoneIndex;

  const PathScreen({
    super.key,
    required this.challenge,
    required this.detail,
    this.initialMilestoneIndex = 0,
  });

  @override
  State<PathScreen> createState() => _PathScreenState();
}

class _PathScreenState extends State<PathScreen> {
  late final List<_PathMilestone> _milestones;
  var _selectedMilestone = 0;

  @override
  void initState() {
    super.initState();
    _milestones = _buildMilestones();
    _selectedMilestone = widget.initialMilestoneIndex.clamp(0, _milestones.length - 1);
  }

  List<_PathMilestone> _buildMilestones() {
    final apiMilestones = widget.detail.milestones;
    if (apiMilestones.isEmpty) {
      return [
        _PathMilestone(
          title: 'Build the baseline',
          description: 'Get familiar with the fundamentals before you increase the pace.',
          resources: [
            _PathResource('The beginner guide', 'READ', 'A short primer to get your first session moving.', true),
            _PathResource('Set up your practice space', 'WATCH', 'A quick walkthrough for removing friction.', true),
            _PathResource('First focused session', 'DO', 'Put the ideas into practice for 20 minutes.', false),
          ],
        ),
        _PathMilestone(
          title: 'Raise the standard',
          description: 'Turn the basics into a repeatable routine.',
          resources: [
            _PathResource('The consistency playbook', 'READ', 'A practical system for showing up every day.', false),
            _PathResource('Deliberate practice drill', 'DO', 'One focused drill for your next session.', false),
          ],
        ),
        _PathMilestone(
          title: 'Prove your progress',
          description: 'Take the final step and submit a result you are proud of.',
          resources: [
            _PathResource('Final challenge checklist', 'READ', 'Everything to review before your verified attempt.', false),
            _PathResource('Verified attempt', 'PROVE', 'Submit the evidence that clears this challenge.', false),
          ],
        ),
      ];
    }

    return [
      for (final milestone in apiMilestones)
        _PathMilestone(
          title: milestone.title,
          description: milestone.description,
          resources: _dummyResourcesFor(milestone.orderIndex),
        ),
    ];
  }

  List<_PathResource> _dummyResourcesFor(int order) {
    final resources = [
      _PathResource('Core concept guide', 'READ', 'A focused guide for this stage of the path.', true),
      _PathResource('Practice session', 'DO', 'A short exercise to turn the idea into a habit.', true),
      _PathResource('Checkpoint notes', 'READ', 'A final reference before you move forward.', false),
    ];
    if (order == 1) return resources;
    return [
      for (final resource in resources)
        _PathResource(resource.title, resource.type, resource.description, false),
    ];
  }

  _PathMilestone get _milestone => _milestones[_selectedMilestone];

  int get _completedCount => _milestone.resources.where((resource) => resource.completed).length;

  @override
  Widget build(BuildContext context) {
    final resources = _milestone.resources;
    final progress = resources.isEmpty ? 0.0 : _completedCount / resources.length;

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
          SliverToBoxAdapter(child: _resourceList(resources)),
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
        Text('$_completedCount', style: const TextStyle(fontSize: 64, height: .82, fontWeight: FontWeight.w800, letterSpacing: -4)),
        const Padding(padding: EdgeInsets.only(bottom: 5), child: Text(' / ', style: TextStyle(color: AppColors.textSecondary, fontSize: 24))),
        Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('${_milestone.resources.length} COMPLETE', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 14),
      Stack(children: [
        Container(height: 5, color: AppColors.border),
        FractionallySizedBox(widthFactor: progress, child: Container(height: 5, color: AppColors.primary)),
      ]),
      const SizedBox(height: 12),
      Text('${(progress * 100).round()}% of this milestone complete', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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

  Widget _resourceTile(_PathResource resource, int index) => InkWell(
    onTap: () => setState(() => resource.completed = !resource.completed),
    child: Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(resource.completed ? Icons.check_circle : Icons.radio_button_unchecked, color: resource.completed ? AppColors.primary : AppColors.textDim, size: 22),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${(index + 1).toString().padLeft(2, '0')}  ${resource.type}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          Text(resource.title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: resource.completed ? AppColors.textSecondary : AppColors.textPrimary, decoration: resource.completed ? TextDecoration.lineThrough : null)),
          const SizedBox(height: 5),
          Text(resource.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3)),
        ])),
        const SizedBox(width: 10),
        Icon(resource.completed ? Icons.done : Icons.arrow_forward, color: resource.completed ? AppColors.primary : AppColors.textSecondary, size: 18),
      ]),
    ),
  );
}

class _PathMilestone {
  final String title;
  final String description;
  final List<_PathResource> resources;

  const _PathMilestone({required this.title, required this.description, required this.resources});
}

class _PathResource {
  final String title;
  final String type;
  final String description;
  bool completed;

  _PathResource(this.title, this.type, this.description, this.completed);
}