import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/challenge.dart';
import '../../models/participation.dart';
import '../../models/progress_log.dart';
import '../../providers/participation_provider.dart';
import '../../services/api_client.dart';
import '../../services/challenges_service.dart';
import '../../services/participation_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/difficulty_badge.dart';
import '../evidence/submit_evidence_screen.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final String slug;
  final Challenge? initialChallenge;

  const ChallengeDetailScreen({
    super.key,
    required this.slug,
    this.initialChallenge,
  });

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  Challenge? _challenge;
  String? _error;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _challenge = widget.initialChallenge;
    if (_challenge == null) _load();
  }

  Future<void> _load() async {
    try {
      final challenge = await context.read<ChallengesService>().getBySlug(
        widget.slug,
      );
      if (!mounted) return;
      setState(() => _challenge = challenge);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await context.read<ParticipationProvider>().accept(widget.slug);
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
    final participation = context.watch<ParticipationProvider>().forChallenge(
      challenge.id,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: challenge.imageUrl != null
                  ? Image.network(
                      challenge.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: AppColors.surfaceAlt),
                    )
                  : Container(color: AppColors.surfaceAlt),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    challenge.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DifficultyBadge(level: challenge.difficultyLevel),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            challenge.effortLabel,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt,
                            size: 18,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${challenge.auraPoints} aura',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    challenge.shortDescription,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  _actionButton(participation),
                  const SizedBox(height: 32),
                  Text(
                    'What you will do',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    challenge.fullDescription,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (challenge.resources.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Text(
                      'Resources',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    ...challenge.resources.map(
                      (r) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                r.rationale,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Text(
                    'Verification',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    challenge.verificationType == 'SELF_REPORTED'
                        ? 'You\'ll confirm you completed this yourself.'
                        : 'This challenge requires verification of your evidence.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(Participation? participation) {
    if (participation == null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _accepting ? null : _accept,
          child: Text(_accepting ? 'Accepting...' : 'Accept Challenge'),
        ),
      );
    }
    final status = participation.status;
    if (status == 'ACCEPTED' || status == 'IN_PROGRESS' || status == 'PAUSED') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _ProgressDialog(participation: participation),
            ),
            icon: const Icon(Icons.timer_outlined),
            label: const Text('Log Progress'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    SubmitEvidenceScreen(participation: participation),
              ),
            ),
            child: const Text('Submit Evidence'),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success),
          const SizedBox(width: 8),
          Text('Status: ${status.toString().toLowerCase()}'),
        ],
      ),
    );
  }
}

class _ProgressDialog extends StatefulWidget {
  final Participation participation;

  const _ProgressDialog({required this.participation});

  @override
  State<_ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<_ProgressDialog> {
  final _hoursController = TextEditingController();
  final _noteController = TextEditingController();
  List<ProgressLog> _logs = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await context.read<ParticipationService>().listProgress(
        widget.participation.id,
      );
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      await context.read<ParticipationService>().logProgress(
        widget.participation.id,
        hoursSpent: hours,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      _hoursController.clear();
      _noteController.clear();
      await _loadLogs();
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
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_logs.isEmpty)
                const Text('No progress logged yet.')
              else
                ..._logs.map(
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
