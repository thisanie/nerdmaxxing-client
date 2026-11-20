import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/daily_quest.dart';
import '../../services/api_client.dart';
import '../../services/daily_quests_service.dart';

class AdminDailyQuestEvidenceScreen extends StatefulWidget {
  const AdminDailyQuestEvidenceScreen({super.key});

  @override
  State<AdminDailyQuestEvidenceScreen> createState() =>
      _AdminDailyQuestEvidenceScreenState();
}

class _AdminDailyQuestEvidenceScreenState
    extends State<AdminDailyQuestEvidenceScreen> {
  final _notes = <String, TextEditingController>{};
  final _openingIds = <String>{};
  final _reviewingIds = <String>{};
  List<AdminDailyQuestAttempt> _attempts = [];
  Map<String, String> _questTitles = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAttempts();
  }

  @override
  void dispose() {
    for (final controller in _notes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAttempts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = context.read<DailyQuestsService>();
      final attempts = await service.listAdminAttempts();
      var questTitles = <String, String>{};
      try {
        final quests = await service.listAdminQuests();
        questTitles = {for (final quest in quests) quest.id: quest.title};
      } on ApiException {
        // The review queue remains usable when quest titles are unavailable.
      }
      if (mounted) {
        setState(() {
          _attempts = attempts;
          _questTitles = questTitles;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  TextEditingController _noteController(String attemptId) =>
      _notes.putIfAbsent(attemptId, TextEditingController.new);

  Future<void> _openEvidence(AdminDailyQuestAttempt attempt) async {
    if (_openingIds.contains(attempt.id)) return;
    setState(() => _openingIds.add(attempt.id));
    try {
      final url = await context
          .read<DailyQuestsService>()
          .getAdminAttemptEvidenceUrl(attempt.id);
      if (!mounted) return;
      if (attempt.evidenceContentType?.toLowerCase().startsWith('image/') ==
          true) {
        await showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: const Text('Daily Quest photo'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width * .9,
                  height: MediaQuery.sizeOf(context).height * .7,
                  child: InteractiveViewer(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(child: Text('Could not load this image.')),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        final uri = Uri.tryParse(url);
        if (uri == null ||
            !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw ApiException(null, 'Could not open this evidence link.');
        }
      }
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _openingIds.remove(attempt.id));
    }
  }

  Future<void> _review(
    AdminDailyQuestAttempt attempt,
    String decision,
  ) async {
    if (_reviewingIds.contains(attempt.id)) return;
    setState(() => _reviewingIds.add(attempt.id));
    final note = _noteController(attempt.id).text.trim();
    try {
      await context.read<DailyQuestsService>().reviewAdminAttempt(
        attemptId: attempt.id,
        decision: decision,
        note: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      _notes.remove(attempt.id)?.dispose();
      await _loadAttempts();
      if (mounted) {
        _showMessage(
          decision == 'APPROVE'
              ? 'Daily Quest evidence approved.'
              : 'Daily Quest evidence rejected.',
        );
      }
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _reviewingIds.remove(attempt.id));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Quest evidence'),
        actions: [
          IconButton(
            tooltip: 'Refresh queue',
            onPressed: _loading ? null : _loadAttempts,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading && _attempts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _attempts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loadAttempts,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAttempts,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${_attempts.length} awaiting review',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (_attempts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Center(
                        child: Text('No Daily Quest evidence to review.'),
                      ),
                    ),
                  for (final attempt in _attempts)
                    _buildAttemptTile(attempt),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildAttemptTile(AdminDailyQuestAttempt attempt) {
    final reviewing = _reviewingIds.contains(attempt.id);
    final opening = _openingIds.contains(attempt.id);
    final questTitle = _questTitles[attempt.questId];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          questTitle ?? 'Daily Quest ${attempt.questId}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'User ${attempt.userId} · ${attempt.localDate} · '
          '${attempt.evidenceContentType ?? 'File type unavailable'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          _detailRow('Attempt', attempt.id),
          _detailRow('Quest ID', attempt.questId),
          _detailRow('Submitted', attempt.createdAt?.toLocal().toString() ?? 'Unavailable'),
          _detailRow('Timezone', attempt.timezone),
          if (attempt.reviewNote?.isNotEmpty == true)
            _detailRow('Review note', attempt.reviewNote!),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: opening ? null : () => _openEvidence(attempt),
              icon: opening
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.visibility_outlined),
              label: Text(opening ? 'Loading evidence...' : 'View evidence'),
            ),
          ),
          TextField(
            controller: _noteController(attempt.id),
            maxLength: 1000,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Review note (optional)',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: reviewing ? null : () => _review(attempt, 'REJECT'),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: reviewing ? null : () => _review(attempt, 'APPROVE'),
                  icon: reviewing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(reviewing ? 'Reviewing...' : 'Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 94,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(child: SelectableText(value.isEmpty ? '—' : value)),
      ],
    ),
  );
}