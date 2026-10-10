import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:image_picker/image_picker.dart';

import '../../models/evidence_submission.dart';
import '../../models/challenge_detail.dart';
import '../../models/participation.dart';
import '../../providers/app_state_providers.dart';
import '../../services/api_client.dart';
import '../../services/evidence_service.dart';
import '../../services/integrations_service.dart';
import '../../theme/app_theme.dart';

enum EvidenceMode { account, video, selfReported }

class SubmitEvidenceScreen extends ConsumerStatefulWidget {
  final Participation participation;
  final String challengeTitle;
  final String verificationType;
  final String instructions;
  final VerificationProvider? provider;
  final VerificationEvidenceRules evidenceRules;
  final VerificationCompletion completion;

  const SubmitEvidenceScreen({
    super.key,
    required this.participation,
    this.challengeTitle = 'this challenge',
    this.verificationType = 'SELF_REPORTED',
    this.instructions = '',
    this.provider,
    this.evidenceRules = const VerificationEvidenceRules(),
    this.completion = const VerificationCompletion(),
  });

  @override
  ConsumerState<SubmitEvidenceScreen> createState() =>
      _SubmitEvidenceScreenState();
}

class _SubmitEvidenceScreenState extends ConsumerState<SubmitEvidenceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _explanation = TextEditingController();
  final _link = TextEditingController();
  final _picker = ImagePicker();

  bool _submitting = false;
  bool _accountConnected = false;
  String? _error;
  XFile? _video;
  VerificationAccount? _account;
  EvidenceSubmission? _submission;

  @override
  void initState() {
    super.initState();
    _accountConnected = widget.provider?.connected == true;
    _account = widget.provider?.account;
  }

  EvidenceMode get _mode {
    final verificationSignals = [
      widget.verificationType,
      ...widget.evidenceRules.allowedTypes,
    ].join(' ').toUpperCase();
    if (verificationSignals.contains('VIDEO')) return EvidenceMode.video;
    if (verificationSignals.contains('ACCOUNT') ||
        verificationSignals.contains('CHESS')) {
      return EvidenceMode.account;
    }
    return EvidenceMode.selfReported;
  }

  @override
  void dispose() {
    _explanation.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_mode == EvidenceMode.video &&
        widget.evidenceRules.requiresFile &&
        _video == null) {
      setState(() => _error = 'Choose a video before submitting.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final submission = await context.read<EvidenceService>().submit(
        widget.participation.id,
        explanation: _explanation.text.trim(),
        textContent: _mode == EvidenceMode.account
          ? 'Connected ${widget.provider?.name ?? 'external'} account: ${_account?.username ?? 'connected account'}'
            : null,
        externalUrl: _mode == EvidenceMode.selfReported
          ? _link.text.trim()
          : null,
        fileBytes: _video == null ? null : await _video!.readAsBytes(),
        fileName: _video?.name,
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
      await ref.read(participationControllerProvider.notifier).refresh();
      ref.invalidate(myStatsProvider);
      ref.invalidate(myCompletedChallengesProvider);
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
    final description = widget.instructions.isNotEmpty
        ? widget.instructions
        : switch (_mode) {
            EvidenceMode.account =>
              'Connect the account that proves your result.',
            EvidenceMode.video =>
              'Record a short video showing the completed challenge.',
            EvidenceMode.selfReported =>
              'Tell us what you did. This is your moment to document an accomplishment.',
          };
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          Text(
            widget.challengeTitle,
            style: AppFonts.display(
              color: AppColors.textPrimary,
              fontSize: 30,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: AppFonts.body(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 24),
          if (_mode == EvidenceMode.account) _buildAccountProof(),
          if (_mode == EvidenceMode.video) _buildVideoProof(),
          if (_mode == EvidenceMode.selfReported) _buildSelfReportedProof(),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ||
                    (_mode == EvidenceMode.account && !_accountConnected)
                ? null
                : _submit,
            child: Text(_submitting ? 'Submitting...' : 'Submit evidence'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountProof() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _proofCard(
        icon: Icons.extension_rounded,
        title: '${widget.provider?.name ?? 'External'} account',
        detail: _accountConnected
            ? 'Connected as ${_account?.username ?? 'connected account'}'
            : 'Connect the account used to verify your result.',
        action: _accountConnected
            ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
            : FilledButton.icon(
                onPressed: _submitting ? null : _connectAccount,
                icon: const Icon(Icons.link_rounded),
                label: const Text('Connect account'),
              ),
      ),
      const SizedBox(height: 18),
      TextFormField(
        controller: _explanation,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Add context (optional)'),
      ),
    ],
  );

  Widget _buildVideoProof() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _proofCard(
        icon: Icons.videocam_rounded,
        title: _video?.name ?? 'No video selected',
        detail: _video == null
            ? 'Choose a video from your device. Keep it clear and under the challenge limit.'
            : 'Ready to upload as evidence.',
        action: FilledButton.icon(
          onPressed: _submitting ? null : _pickVideo,
          icon: const Icon(Icons.video_library_rounded),
          label: Text(_video == null ? 'Choose video' : 'Replace video'),
        ),
      ),
      const SizedBox(height: 18),
      TextFormField(
        controller: _explanation,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'What should we notice? (optional)'),
      ),
    ],
  );

  Widget _buildSelfReportedProof() => Column(
    children: [
      TextFormField(
        controller: _explanation,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'What did you complete?'),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _link,
        decoration: const InputDecoration(labelText: 'Link to your work (optional)'),
      ),
    ],
  );

  Widget _proofCard({
    required IconData icon,
    required String title,
    required String detail,
    required Widget action,
  }) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 30, color: AppColors.primary),
        const SizedBox(height: 14),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(detail, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        action,
      ],
    ),
  );

  Future<void> _pickVideo() async {
    final video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null && mounted) setState(() => _video = video);
  }

  Future<void> _connectAccount() async {
    final providerId = widget.provider?.id;
    if (providerId == null || providerId.isEmpty) {
      setState(() => _error = 'This challenge has no account provider configured.');
      return;
    }
    final service = context.read<IntegrationsService>();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final provider = await service.connect(providerId);
      if (!mounted) return;
      setState(() {
        _accountConnected = provider.connected;
        _account = provider.account;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildVerify() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_rounded,
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
