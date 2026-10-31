import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/evidence_submission.dart';
import '../../services/api_client.dart';
import '../../services/evidence_service.dart';

class AdminEvidenceScreen extends StatefulWidget {
  const AdminEvidenceScreen({super.key});

  @override
  State<AdminEvidenceScreen> createState() => _AdminEvidenceScreenState();
}

class _AdminEvidenceScreenState extends State<AdminEvidenceScreen> {
  static const _pageSize = 20;

  final _noteControllers = <String, TextEditingController>{};
  final _reviewingIds = <String>{};
  List<EvidenceSubmission> _submissions = [];
  int _total = 0;
  int _offset = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  bool get _hasMore => _submissions.length < _total;

  @override
  void initState() {
    super.initState();
    _loadSubmissions(refresh: true);
  }

  @override
  void dispose() {
    for (final controller in _noteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSubmissions({bool refresh = false}) async {
    if (_loadingMore || (_loading && !refresh)) return;
    if (refresh) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final page = await context.read<EvidenceService>().listActiveSubmissions(
        limit: _pageSize,
        offset: refresh ? 0 : _offset,
      );
      if (!mounted) return;
      setState(() {
        _submissions = refresh
            ? page.items
            : [..._submissions, ...page.items];
        _total = page.total;
        _offset = page.offset + page.items.length;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  TextEditingController _noteController(String submissionId) {
    return _noteControllers.putIfAbsent(
      submissionId,
      TextEditingController.new,
    );
  }

  Future<void> _review(EvidenceSubmission submission, String decision) async {
    if (_reviewingIds.contains(submission.id)) return;
    setState(() => _reviewingIds.add(submission.id));
    final note = _noteController(submission.id).text.trim();
    try {
      await context.read<EvidenceService>().verify(
        submission.id,
        decision: decision,
        note: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      _noteControllers.remove(submission.id)?.dispose();
      await _loadSubmissions(refresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'APPROVE' ? 'Evidence approved.' : 'Evidence rejected.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _reviewingIds.remove(submission.id));
    }
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this evidence link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evidence requests'),
        actions: [
          IconButton(
            tooltip: 'Refresh queue',
            onPressed: _loading ? null : () => _loadSubmissions(refresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading && _submissions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _submissions.isEmpty
          ? _QueueError(message: _error!, onRetry: () => _loadSubmissions(refresh: true))
          : RefreshIndicator(
              onRefresh: () => _loadSubmissions(refresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '$_total awaiting review',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (_submissions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Center(child: Text('No evidence requests to review.')),
                    ),
                  for (final submission in _submissions)
                    _SubmissionTile(
                      key: ValueKey(submission.id),
                      submission: submission,
                      noteController: _noteController(submission.id),
                      reviewing: _reviewingIds.contains(submission.id),
                      onOpenUrl: _openUrl,
                      onReview: (decision) => _review(submission, decision),
                    ),
                  if (_hasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton(
                        onPressed: _loadingMore
                            ? null
                            : () => _loadSubmissions(),
                        child: Text(_loadingMore ? 'Loading...' : 'Load more'),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  const _SubmissionTile({
    super.key,
    required this.submission,
    required this.noteController,
    required this.reviewing,
    required this.onOpenUrl,
    required this.onReview,
  });

  final EvidenceSubmission submission;
  final TextEditingController noteController;
  final bool reviewing;
  final ValueChanged<String> onOpenUrl;
  final ValueChanged<String> onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          submission.explanation?.trim().isNotEmpty == true
              ? submission.explanation!.trim()
              : 'Evidence submission',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            'User ${submission.userId}  ·  ${submission.submittedAt?.toLocal().toString() ?? 'Date unavailable'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          _InfoLine(label: 'Challenge', value: submission.challengeId),
          _InfoLine(label: 'Submission', value: submission.id),
          _InfoLine(label: 'Participant', value: submission.participantId),
          if (submission.textContent?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Submitted text', style: theme.textTheme.titleSmall),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(submission.textContent!),
            ),
          ],
          if (submission.fileUrl?.isNotEmpty == true)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onOpenUrl(submission.fileUrl!),
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(submission.fileName ?? 'Open submitted file'),
              ),
            ),
          if (submission.externalUrl?.isNotEmpty == true)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onOpenUrl(submission.externalUrl!),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open submitted link'),
              ),
            ),
          TextField(
            controller: noteController,
            maxLength: 5000,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Review note (optional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: reviewing ? null : () => onReview('REJECT'),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: reviewing ? null : () => onReview('APPROVE'),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(reviewing ? 'Saving...' : 'Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _QueueError extends StatelessWidget {
  const _QueueError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}