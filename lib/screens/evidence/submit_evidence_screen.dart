import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/evidence_submission.dart';
import '../../models/participation.dart';
import '../../providers/participation_provider.dart';
import '../../services/api_client.dart';
import '../../services/evidence_service.dart';
import '../../theme/app_theme.dart';

class SubmitEvidenceScreen extends StatefulWidget {
  final Participation participation;
  const SubmitEvidenceScreen({super.key, required this.participation});

  @override
  State<SubmitEvidenceScreen> createState() => _SubmitEvidenceScreenState();
}

class _SubmitEvidenceScreenState extends State<SubmitEvidenceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _explanation = TextEditingController();
  final _link = TextEditingController();

  bool _submitting = false;
  String? _error;
  EvidenceSubmission? _submission;

  @override
  void dispose() {
    _explanation.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final submission = await context.read<EvidenceService>().submit(
        widget.participation.id,
        explanation: _explanation.text.trim(),
        externalUrl: _link.text.trim(),
      );
      if (!mounted) return;
      setState(() => _submission = submission);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _verify() async {
    if (_submission == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<EvidenceService>().selfVerify(_submission!.id);
      await context.read<ParticipationProvider>().load();
      if (!mounted) return;
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Challenge Complete'),
          content: const Text('You earned a new skill.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Nice'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Evidence')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _submission == null ? _buildForm() : _buildVerify(),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          Text(
            'Tell us what you did. This is your moment to document an accomplishment.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _explanation,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'What did you complete?',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _link,
            decoration: const InputDecoration(
              labelText: 'Link to your work (optional)',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Submitting...' : 'Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerify() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 48,
          color: AppColors.success,
        ),
        const SizedBox(height: 16),
        Text(
          'Evidence submitted',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Confirm you completed this challenge to earn your skill.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _verify,
            child: Text(_submitting ? 'Verifying...' : 'Verify Completion'),
          ),
        ),
      ],
    );
  }
}
