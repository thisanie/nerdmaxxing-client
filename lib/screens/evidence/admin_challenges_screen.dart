import 'package:flutter/material.dart' hide SnackBar;
import 'package:provider/provider.dart';

import '../../models/challenge.dart';
import '../../services/api_client.dart';
import '../../services/challenges_service.dart';
import '../../widgets/app_snack_bar.dart';

class _AdminResourceFields {
  final title = TextEditingController();
  final url = TextEditingController();
  final rationale = TextEditingController();

  void dispose() {
    title.dispose();
    url.dispose();
    rationale.dispose();
  }
}

class _AdminMilestoneFields {
  final title = TextEditingController();
  final description = TextEditingController();
  final target = TextEditingController(text: '1');
  final resourceIndexes = <int>{};

  void dispose() {
    title.dispose();
    description.dispose();
    target.dispose();
  }
}

class AdminChallengesScreen extends StatefulWidget {
  const AdminChallengesScreen({super.key});

  @override
  State<AdminChallengesScreen> createState() => _AdminChallengesScreenState();
}

class _AdminChallengesScreenState extends State<AdminChallengesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _imageUrl = TextEditingController();
  final _shortDescription = TextEditingController();
  final _fullDescription = TextEditingController();
  final _effortMin = TextEditingController();
  final _effortMax = TextEditingController();
  final _duration = TextEditingController();
  final _verificationInstructions = TextEditingController();
  final _requiredRuns = TextEditingController(text: '1');
  final _resources = <_AdminResourceFields>[_AdminResourceFields()];
  final _milestones = <_AdminMilestoneFields>[_AdminMilestoneFields()];

  String _difficulty = 'BEGINNER';
  String _verificationType = 'SELF_REPORTED';
  DateTime _dailyDate = DateUtils.dateOnly(DateTime.now());
  double _bonusMultiplier = 2;
  Challenge? _createdChallenge;
  bool _creating = false;
  bool _scheduling = false;
  bool _scheduled = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _imageUrl,
      _shortDescription,
      _fullDescription,
      _effortMin,
      _effortMax,
      _duration,
      _verificationInstructions,
      _requiredRuns,
    ]) {
      controller.dispose();
    }
    for (final resource in _resources) {
      resource.dispose();
    }
    for (final milestone in _milestones) {
      milestone.dispose();
    }
    super.dispose();
  }

  Future<void> _createChallenge() async {
    if (!_formKey.currentState!.validate()) return;
    final effortMin = _optionalPositiveInt(_effortMin.text);
    final effortMax = _optionalPositiveInt(_effortMax.text);
    if (effortMin != null && effortMax != null && effortMax < effortMin) {
      setState(() => _error = 'Maximum effort must be at least the minimum.');
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final challenge = await context
          .read<ChallengesService>()
          .createAdminChallenge(payload: _buildPayload(effortMin, effortMax));
      if (!mounted) return;
      setState(() => _createdChallenge = challenge);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created ${challenge.title}.')),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Map<String, dynamic> _buildPayload(int? effortMin, int? effortMax) {
    final imageUrl = _imageUrl.text.trim();
    final duration = _optionalPositiveInt(_duration.text);
    return {
      'title': _title.text.trim(),
      'image_url': imageUrl.isEmpty ? null : imageUrl,
      'resources': [
        for (var index = 0; index < _resources.length; index++)
          {
            'title': _resources[index].title.text.trim(),
            'url': _resources[index].url.text.trim().isEmpty
                ? null
                : _resources[index].url.text.trim(),
            'resource_type': 'LINK',
            'rationale': _resources[index].rationale.text.trim(),
            'order_index': index,
            'required': true,
          },
      ],
      'short_description': _shortDescription.text.trim(),
      'full_description': _fullDescription.text.trim(),
      'difficulty_level': _difficulty,
      if (effortMin != null) 'estimated_effort_min_minutes': effortMin,
      if (effortMax != null) 'estimated_effort_max_minutes': effortMax,
      if (duration != null) 'estimated_duration_minutes': duration,
      'verification_type': _verificationType,
      'verification_instructions': _verificationInstructions.text.trim(),
      'required_runs': int.parse(_requiredRuns.text.trim()),
      'metrics': <Map<String, dynamic>>[],
      'requirements': <Map<String, dynamic>>[],
      'milestones': [
        for (final milestone in _milestones)
          {
            'title': milestone.title.text.trim(),
            'description': milestone.description.text.trim(),
            'target_value': double.parse(milestone.target.text.trim()),
            'resource_order_indexes': milestone.resourceIndexes.toList()..sort(),
          },
      ],
    };
  }

  Future<void> _scheduleChallenge() async {
    final challenge = _createdChallenge;
    if (challenge == null || _scheduling || _scheduled) return;
    setState(() {
      _scheduling = true;
      _error = null;
    });
    try {
      await context.read<ChallengesService>().scheduleDailyChallenge(
        challengeId: challenge.id,
        date: _dailyDate,
        bonusMultiplier: _bonusMultiplier,
      );
      if (!mounted) return;
      setState(() => _scheduled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scheduled ${challenge.title} for the day.')),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _scheduling = false);
    }
  }

  Future<void> _selectDailyDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _dailyDate.isBefore(today) ? today : _dailyDate,
      firstDate: today,
      lastDate: DateTime(today.year + 2),
    );
    if (selected != null) setState(() => _dailyDate = DateUtils.dateOnly(selected));
  }

  void _addResource() {
    if (_resources.length >= 20) return;
    setState(() => _resources.add(_AdminResourceFields()));
  }

  void _removeResource(int index) {
    if (_resources.length == 1) return;
    final removed = _resources.removeAt(index);
    removed.dispose();
    for (final milestone in _milestones) {
      milestone.resourceIndexes.remove(index);
      final shifted = milestone.resourceIndexes
          .map((resourceIndex) => resourceIndex > index ? resourceIndex - 1 : resourceIndex)
          .toSet();
      milestone.resourceIndexes
        ..clear()
        ..addAll(shifted);
    }
    setState(() {});
  }

  void _addMilestone() {
    if (_milestones.length >= 20) return;
    setState(() => _milestones.add(_AdminMilestoneFields()));
  }

  void _removeMilestone(int index) {
    if (_milestones.length == 1) return;
    _milestones.removeAt(index).dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final challenge = _createdChallenge;
    return Scaffold(
      appBar: AppBar(title: const Text('Daily challenges')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          if (challenge == null) ...[
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionTitle(
                    title: 'Challenge details',
                    subtitle: 'Create a public challenge for the daily schedule.',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _title,
                    maxLength: 160,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) =>
                        (value?.trim().length ?? 0) < 3 ? 'Enter at least 3 characters.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _imageUrl,
                    decoration: const InputDecoration(labelText: 'Image URL (optional)'),
                    validator: _validateOptionalUrl,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _shortDescription,
                    maxLength: 300,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Short description'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fullDescription,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'Full description'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _difficulty,
                    decoration: const InputDecoration(labelText: 'Difficulty'),
                    items: const [
                      DropdownMenuItem(value: 'BEGINNER', child: Text('Beginner')),
                      DropdownMenuItem(value: 'INTERMEDIATE', child: Text('Intermediate')),
                      DropdownMenuItem(value: 'ADVANCED', child: Text('Advanced')),
                    ],
                    onChanged: (value) => setState(() => _difficulty = value ?? 'BEGINNER'),
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(
                    title: 'Estimated effort',
                    subtitle: 'Optional time estimates in minutes.',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _optionalMinutesField(_effortMin, 'Minimum')),
                      const SizedBox(width: 12),
                      Expanded(child: _optionalMinutesField(_effortMax, 'Maximum')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _optionalMinutesField(_duration, 'Estimated duration'),
                  const SizedBox(height: 20),
                  _SectionTitle(
                    title: 'Resources',
                    subtitle: 'Add at least one resource to guide participants.',
                  ),
                  const SizedBox(height: 12),
                  for (var index = 0; index < _resources.length; index++)
                    _resourceFields(index),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _creating || _resources.length >= 20 ? null : _addResource,
                      icon: const Icon(Icons.add_rounded),
                      label: Text('Add resource (${_resources.length}/20)'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(
                    title: 'Milestones',
                    subtitle: 'Define at least one milestone and its target.',
                  ),
                  const SizedBox(height: 12),
                  for (var index = 0; index < _milestones.length; index++)
                    _milestoneFields(index),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _creating || _milestones.length >= 20 ? null : _addMilestone,
                      icon: const Icon(Icons.add_rounded),
                      label: Text('Add milestone (${_milestones.length}/20)'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(
                    title: 'Verification',
                    subtitle: 'Tell participants what counts as completion.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _verificationType,
                    decoration: const InputDecoration(labelText: 'Verification type'),
                    items: const [
                      DropdownMenuItem(value: 'SELF_REPORTED', child: Text('Self-reported')),
                      DropdownMenuItem(value: 'ADMIN_REVIEW', child: Text('Admin review')),
                    ],
                    onChanged: (value) => setState(
                      () => _verificationType = value ?? 'SELF_REPORTED',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _verificationInstructions,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Verification instructions'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _requiredRuns,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Required runs'),
                    validator: _positiveIntegerValidator,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _ErrorText(message: _error!),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _creating ? null : _createChallenge,
                    icon: _creating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_task_rounded),
                    label: Text(_creating ? 'Creating challenge...' : 'Create challenge'),
                  ),
                ],
              ),
            ),
          ] else ...[
            _CreatedChallengeSummary(challenge: challenge),
            const SizedBox(height: 24),
            _SectionTitle(
              title: 'Schedule for a day',
              subtitle: 'Choose when this challenge becomes the daily challenge.',
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _scheduling || _scheduled ? null : _selectDailyDate,
              icon: const Icon(Icons.event_rounded),
              label: Text(MaterialLocalizations.of(context).formatMediumDate(_dailyDate)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<double>(
              initialValue: _bonusMultiplier,
              decoration: const InputDecoration(labelText: 'Aura bonus multiplier'),
              items: const [1.25, 1.5, 2, 2.5, 3, 4, 5]
                  .map(
                    (multiplier) => DropdownMenuItem(
                      value: multiplier,
                      child: Text('${multiplier}x'),
                    ),
                  )
                  .toList(),
              onChanged: _scheduling || _scheduled
                  ? null
                  : (value) => setState(() => _bonusMultiplier = value ?? 2),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _ErrorText(message: _error!),
            ],
            const SizedBox(height: 18),
            if (_scheduled)
              const _ScheduledBanner()
            else
              FilledButton.icon(
                onPressed: _scheduling ? null : _scheduleChallenge,
                icon: _scheduling
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.calendar_month_rounded),
                label: Text(_scheduling ? 'Scheduling...' : 'Schedule daily challenge'),
              ),
            if (_scheduled) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _startAnotherChallenge,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create another challenge'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _resourceFields(int index) {
    final resource = _resources[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Resource ${index + 1}', style: Theme.of(context).textTheme.titleSmall)),
              if (_resources.length > 1)
                IconButton(
                  tooltip: 'Remove resource',
                  onPressed: _creating ? null : () => _removeResource(index),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          TextFormField(
            controller: resource.title,
            maxLength: 160,
            decoration: const InputDecoration(labelText: 'Resource title'),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: resource.url,
            decoration: const InputDecoration(labelText: 'URL (optional)'),
            validator: _validateOptionalUrl,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: resource.rationale,
            maxLength: 1000,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Why this resource is useful'),
            validator: _requiredValidator,
          ),
        ],
      ),
    );
  }

  Widget _milestoneFields(int index) {
    final milestone = _milestones[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Milestone ${index + 1}', style: Theme.of(context).textTheme.titleSmall)),
              if (_milestones.length > 1)
                IconButton(
                  tooltip: 'Remove milestone',
                  onPressed: _creating ? null : () => _removeMilestone(index),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          TextFormField(
            controller: milestone.title,
            maxLength: 160,
            decoration: const InputDecoration(labelText: 'Title'),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: milestone.description,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Description'),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: milestone.target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Target value'),
            validator: _nonNegativeNumberValidator,
          ),
          if (_resources.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Linked resources', style: Theme.of(context).textTheme.labelLarge),
            for (var resourceIndex = 0; resourceIndex < _resources.length; resourceIndex++)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  _resources[resourceIndex].title.text.trim().isEmpty
                      ? 'Resource ${resourceIndex + 1}'
                      : _resources[resourceIndex].title.text.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                value: milestone.resourceIndexes.contains(resourceIndex),
                onChanged: _creating
                    ? null
                    : (selected) => setState(() {
                        if (selected == true) {
                          milestone.resourceIndexes.add(resourceIndex);
                        } else {
                          milestone.resourceIndexes.remove(resourceIndex);
                        }
                      }),
              ),
          ],
        ],
      ),
    );
  }

  Widget _optionalMinutesField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: '$label (minutes)'),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return null;
        return _optionalPositiveInt(value) == null ? 'Enter a positive number.' : null;
      },
    );
  }

  void _startAnotherChallenge() {
    for (final controller in [
      _title,
      _imageUrl,
      _shortDescription,
      _fullDescription,
      _effortMin,
      _effortMax,
      _duration,
      _verificationInstructions,
    ]) {
      controller.clear();
    }
    _requiredRuns.text = '1';
    for (final resource in _resources) {
      resource.dispose();
    }
    for (final milestone in _milestones) {
      milestone.dispose();
    }
    setState(() {
      _resources
        ..clear()
        ..add(_AdminResourceFields());
      _milestones
        ..clear()
        ..add(_AdminMilestoneFields());
      _difficulty = 'BEGINNER';
      _verificationType = 'SELF_REPORTED';
      _dailyDate = DateUtils.dateOnly(DateTime.now());
      _bonusMultiplier = 2;
      _createdChallenge = null;
      _scheduled = false;
      _error = null;
    });
  }

  String? _requiredValidator(String? value) =>
      value == null || value.trim().isEmpty ? 'Required.' : null;

  String? _positiveIntegerValidator(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    return parsed == null || parsed < 1 ? 'Enter a positive whole number.' : null;
  }

  String? _nonNegativeNumberValidator(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    return parsed == null || parsed < 0 ? 'Enter a number of 0 or more.' : null;
  }

  String? _validateOptionalUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    return uri == null || !uri.hasScheme || uri.host.isEmpty
        ? 'Enter a valid URL.'
        : null;
  }

  int? _optionalPositiveInt(String value) {
    if (value.trim().isEmpty) return null;
    final parsed = int.tryParse(value.trim());
    return parsed == null || parsed < 1 ? null : parsed;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 3),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _CreatedChallengeSummary extends StatelessWidget {
  const _CreatedChallengeSummary({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Challenge created', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(challenge.title),
                const SizedBox(height: 2),
                Text(
                  '${challenge.auraPoints} aura points · ${challenge.difficultyLevel.toLowerCase()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduledBanner extends StatelessWidget {
  const _ScheduledBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.event_available_rounded),
          SizedBox(width: 10),
          Expanded(child: Text('Daily challenge scheduled successfully.')),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Text(
    message,
    style: TextStyle(color: Theme.of(context).colorScheme.error),
  );
}