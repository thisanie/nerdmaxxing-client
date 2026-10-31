import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/evidence_submission.dart';
import '../../services/api_client.dart';
import '../../services/evidence_service.dart';

class EvidenceReviewScreen extends StatefulWidget {
  const EvidenceReviewScreen({super.key});

  @override
  State<EvidenceReviewScreen> createState() => _EvidenceReviewScreenState();
}

class _EvidenceReviewScreenState extends State<EvidenceReviewScreen> {
  final _submissionIdController = TextEditingController();
  final _noteController = TextEditingController();
  EvidenceSubmission? _submission;
  bool _loading = false;
  bool _reviewing = false;
  String? _error;

  @override
  void dispose() {
    _submissionIdController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadSubmission() async {
    final submissionId = _submissionIdController.text.trim();
    if (submissionId.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _submission = null;
      _noteController.clear();
    });
    try {
      final submission = await context
          .read<EvidenceService>()
          .getSubmission(submissionId);
      if (!mounted) return;
      setState(() {
        _submission = submission;
        if (submission == null) _error = 'Submission not found.';
        if (submission?.reviewReason != null) {
          _noteController.text = submission!.reviewReason!;
        }
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(String decision) async {
    final submission = _submission;
    if (submission == null || _reviewing) return;
    setState(() => _reviewing = true);
    try {
      final updated = await context.read<EvidenceService>().verify(
        submission.id,
        decision: decision,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _submission = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'APPROVE'
                ? 'Evidence approved.'
                : 'Evidence rejected. The user can submit again.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  Future<void> _openEvidenceUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this evidence link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Evidence review')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _submissionIdController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _loadSubmission(),
            decoration: InputDecoration(
              labelText: 'Submission ID',
              hintText: 'Enter an evidence submission ID',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Load submission',
                onPressed: _loading ? null : _loadSubmission,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: colorScheme.error)),
          ],
          if (_submission case final submission?) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Submission',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _StatusLabel(status: submission.status),
              ],
            ),
            const SizedBox(height: 12),
            _DetailRow(label: 'ID', value: submission.id),
            _DetailRow(label: 'Challenge', value: submission.challengeId),
            _DetailRow(label: 'Participant', value: submission.participantId),
            _DetailRow(label: 'Submitted by', value: submission.userId),
            if (submission.submittedAt != null)
              _DetailRow(
                label: 'Submitted',
                value: submission.submittedAt!.toLocal().toString(),
              ),
            if (submission.explanation?.isNotEmpty == true) ...[
              const SizedBox(height: 20),
              Text('Explanation', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(submission.explanation!),
            ],
            if (submission.textContent?.isNotEmpty == true) ...[
              const SizedBox(height: 20),
              Text('Submitted text', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              SelectableText(submission.textContent!),
            ],
            if (submission.fileUrl?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _openEvidenceUrl(submission.fileUrl!),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(submission.fileName ?? 'Open submitted file'),
              ),
            ],
            if (submission.externalUrl?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _openEvidenceUrl(submission.externalUrl!),
                icon: const Icon(Icons.link_rounded),
                label: const Text('Open submitted link'),
              ),
            ],
            if (submission.reviewReason?.isNotEmpty == true &&
                submission.status.toUpperCase() != 'PENDING') ...[
              const SizedBox(height: 20),
              Text('Review note', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(submission.reviewReason!),
            ],
            if (submission.status.toUpperCase() == 'PENDING') ...[
              const SizedBox(height: 24),
              TextField(
                controller: _noteController,
                maxLength: 5000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Review note',
                  hintText: 'Optional note for the submitter',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reviewing ? null : () => _review('REJECT'),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _reviewing ? null : () => _review('APPROVE'),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(_reviewing ? 'Saving...' : 'Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPending = status.toUpperCase() == 'PENDING';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isPending ? colorScheme.tertiaryContainer : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(status),
    );
  }
}