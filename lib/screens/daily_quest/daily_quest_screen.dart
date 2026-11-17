import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/daily_quest.dart';
import '../../services/api_client.dart';
import '../../services/daily_quests_service.dart';
import '../../theme/app_theme.dart';

enum _QuestStep { learn, prove }

class DailyQuestScreen extends StatefulWidget {
  final DailyQuestToday today;

  const DailyQuestScreen({super.key, required this.today});

  @override
  State<DailyQuestScreen> createState() => _DailyQuestScreenState();
}

class _DailyQuestScreenState extends State<DailyQuestScreen> {
  final _picker = ImagePicker();
  late DailyQuestToday _today;
  late _QuestStep _step;
  late List<int?> _answers;
  XFile? _evidenceFile;
  Uint8List? _evidenceBytes;
  int _quizAttemptsUsed = 0;
  Timer? _countdownTimer;
  bool _starting = false;
  bool _submitting = false;
  String? _error;

  DailyQuest get _quest => _today.quest!;
  DailyQuestAttempt? get _attempt => _today.attempt;

  @override
  void initState() {
    super.initState();
    _today = widget.today;
    _step = _QuestStep.learn;
    _answers = List<int?>.filled(_today.quest?.questions.length ?? 0, null);
    _quizAttemptsUsed = _attempt?.quizAttemptsUsed ?? 0;
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quest = _today.quest;
    if (quest == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Daily Quest')),
        body: const Center(child: Text('There is no quest assigned today.')),
      );
    }

    final brightness = Theme.of(context).brightness;
    final foreground = HomePalette.textPrimary(brightness);
    final muted = HomePalette.textSecondary(brightness);
    return Scaffold(
      backgroundColor: HomePalette.background(brightness),
      appBar: AppBar(
        title: const Text('Daily Quest'),
        backgroundColor: HomePalette.background(brightness),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            _QuestHero(
              quest: quest,
              today: _today,
              attempt: _attempt,
            ),
            const SizedBox(height: 18),
            SegmentedButton<_QuestStep>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _QuestStep.learn,
                  icon: Icon(Icons.menu_book_outlined),
                  label: Text('Learn'),
                ),
                ButtonSegment(
                  value: _QuestStep.prove,
                  icon: Icon(Icons.task_alt_rounded),
                  label: Text('Prove'),
                ),
              ],
              selected: {_step},
              onSelectionChanged: (selection) {
                setState(() {
                  _step = selection.first;
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 20),
            if (_step == _QuestStep.learn)
              _buildLearn(quest, muted)
            else
              _buildProve(quest, foreground, muted),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _InlineMessage(message: _error!, isError: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLearn(DailyQuest quest, Color muted) {
    final instructions = quest.instructions.trim().isNotEmpty
        ? quest.instructions.trim()
        : quest.description.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          eyebrow: 'YOUR 10-MINUTE MISSION',
          title: 'Learn something you can explain.',
        ),
        const SizedBox(height: 12),
        _SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                instructions.isEmpty
                    ? 'Explore the topic, then complete the proof for this quest.'
                    : instructions,
                style: AppFonts.body(color: muted, fontSize: 14, height: 1.5),
              ),
              if (quest.articleUrl != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _openArticle,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open learning resource'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _InfoLine(
          icon: Icons.check_circle_outline_rounded,
          title: 'How to complete it',
          detail: quest.verificationType == 'QUIZ'
              ? 'Score at least 80% on the quiz. One retry is available before the quest expires.'
              : 'Submit ${quest.verificationType == 'VIDEO' ? 'a video' : 'a photo'} for review. Your submission stays private.',
        ),
        const SizedBox(height: 8),
        _InfoLine(
          icon: Icons.bolt_rounded,
          title: 'Earn ${quest.auraReward} Aura',
          detail: quest.verificationType == 'QUIZ'
              ? 'Awarded once when you pass.'
              : 'Awarded once after your submission is approved.',
        ),
        const SizedBox(height: 24),
        if (_attempt?.isCompleted == true)
          const _InlineMessage(
            message: 'Quest complete. Your streak is up to date.',
            icon: Icons.verified_rounded,
          )
        else if (_attempt?.isPendingReview == true)
          const _InlineMessage(
            message: 'Your proof is in review. We will update your quest when it is checked.',
            icon: Icons.hourglass_top_rounded,
          )
        else
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _starting ? null : _startQuest,
              icon: _starting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(_starting ? 'Starting...' : 'Start quest'),
            ),
          ),
      ],
    );
  }

  Widget _buildProve(DailyQuest quest, Color foreground, Color muted) {
    if (_attempt == null) {
      return _LockedProof(onStart: _starting ? null : _startQuest);
    }
    if (_attempt!.isCompleted) {
      return const _ResultPanel(
        title: 'Quest complete',
        detail: 'You earned Aura and kept your daily streak going.',
        icon: Icons.verified_rounded,
      );
    }
    if (_attempt!.isPendingReview ||
        _attempt!.evidenceStatus?.toUpperCase() == 'PENDING_REVIEW') {
      return const _ResultPanel(
        title: 'Proof submitted',
        detail: 'Your submission is private and waiting for review.',
        icon: Icons.hourglass_top_rounded,
      );
    }
    if (quest.verificationType == 'QUIZ') {
      return _buildQuiz(quest, foreground, muted);
    }
    return _buildMediaProof(quest, foreground, muted);
  }

  Widget _buildQuiz(DailyQuest quest, Color foreground, Color muted) {
    final cannotRetry = _quizAttemptsUsed >= 2 || _attempt!.isFailed;
    final passed = _attempt?.isCompleted == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          eyebrow: 'QUIZ · ${quest.questions.length} QUESTIONS',
          title: 'Show what stuck.',
        ),
        const SizedBox(height: 8),
        if (_attempt?.score != null && !passed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _InlineMessage(
              message: cannotRetry
                  ? 'You scored ${_attempt!.score}%. This quest has expired.'
                  : 'You scored ${_attempt!.score}%. Review the material and use your one retry.',
              isError: cannotRetry,
              icon: cannotRetry ? Icons.info_outline : Icons.refresh_rounded,
            ),
          ),
        if (quest.questions.isEmpty)
          const _InlineMessage(
            message: 'The quiz for this quest is unavailable right now.',
            isError: true,
          )
        else
          for (var index = 0; index < quest.questions.length; index++)
            _buildQuestion(quest.questions[index], index, foreground, muted),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _submitting ||
                    cannotRetry ||
                    quest.questions.isEmpty ||
                    _answers.any((answer) => answer == null)
                ? null
                : _submitQuiz,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_submitting ? 'Checking...' : 'Check answers'),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion(
    DailyQuestQuestion question,
    int questionIndex,
    Color foreground,
    Color muted,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _SurfacePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QUESTION ${questionIndex + 1}',
              style: AppFonts.home(
                color: HomePalette.lightLink,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacingEm: .1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              question.prompt,
              style: AppFonts.body(
                color: foreground,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            for (var optionIndex = 0;
                optionIndex < question.options.length;
                optionIndex++)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: _AnswerOption(
                  label: question.options[optionIndex],
                  selected: _answers[questionIndex] == optionIndex,
                  onTap: _submitting || _attempt!.isFailed
                      ? null
                      : () => setState(
                          () => _answers[questionIndex] = optionIndex,
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaProof(DailyQuest quest, Color foreground, Color muted) {
    final isVideo = quest.verificationType == 'VIDEO';
    final maxSizeLabel = isVideo ? '50 MiB' : '10 MiB';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          eyebrow: isVideo ? 'VIDEO PROOF' : 'PHOTO PROOF',
          title: isVideo ? 'Capture your attempt.' : 'Show what you made.',
        ),
        const SizedBox(height: 8),
        Text(
          quest.instructions.isNotEmpty
              ? quest.instructions
              : 'Choose clear ${isVideo ? 'video' : 'image'} evidence for this quest.',
          style: AppFonts.body(color: muted, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 16),
        _SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isVideo ? Icons.videocam_outlined : Icons.photo_outlined,
                size: 28,
                color: HomePalette.lightLink,
              ),
              const SizedBox(height: 12),
              Text(
                _evidenceFile?.name ?? 'No file selected',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.body(
                  color: foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _evidenceFile == null
                    ? 'Private submission · Up to $maxSizeLabel'
                    : 'Ready to submit privately',
                style: AppFonts.body(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _pickEvidence,
                icon: Icon(isVideo ? Icons.video_library_outlined : Icons.add_photo_alternate_outlined),
                label: Text(_evidenceFile == null ? 'Choose ${isVideo ? 'video' : 'photo'}' : 'Replace file'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _InlineMessage(
          message: 'Uploading does not award Aura yet. Your proof is reviewed first.',
          icon: Icons.lock_outline_rounded,
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _submitting || _evidenceFile == null
                ? null
                : () => _submitEvidence(quest),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_submitting ? 'Uploading...' : 'Submit for review'),
          ),
        ),
      ],
    );
  }

  Future<void> _startQuest() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final attempt = await context.read<DailyQuestsService>().startToday();
      if (!mounted) return;
      setState(() {
        _today = _today.withAttempt(attempt);
        _quizAttemptsUsed = math.max(
          _quizAttemptsUsed,
          attempt.quizAttemptsUsed,
        ).toInt();
        _step = _QuestStep.prove;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _submitQuiz() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final attempt = await context.read<DailyQuestsService>().submitQuiz(
        _answers.cast<int>(),
      );
      if (!mounted) return;
      setState(() {
        _quizAttemptsUsed = math
            .max(_quizAttemptsUsed + 1, attempt.quizAttemptsUsed)
            .toInt();
        _today = _today.withAttempt(attempt);
        _answers = List<int?>.filled(_quest.questions.length, null);
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickEvidence() async {
    final isVideo = _quest.verificationType == 'VIDEO';
    final file = isVideo
        ? await _picker.pickVideo(source: ImageSource.gallery)
        : await _picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 88,
          );
    if (file == null) return;
    final size = await file.length();
    final maxSize = (isVideo ? 50 : 10) * 1024 * 1024;
    if (size > maxSize) {
      if (mounted) {
        setState(() {
          _evidenceFile = null;
          _evidenceBytes = null;
          _error = 'Choose a file smaller than ${isVideo ? '50' : '10'} MiB.';
        });
      }
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _evidenceFile = file;
      _evidenceBytes = bytes;
      _error = null;
    });
  }

  Future<void> _submitEvidence(DailyQuest quest) async {
    final file = _evidenceFile;
    final bytes = _evidenceBytes;
    if (file == null || bytes == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final attempt = await context.read<DailyQuestsService>().submitEvidence(
        bytes: bytes,
        filename: file.name,
        verificationType: quest.verificationType,
      );
      if (!mounted) return;
      setState(() => _today = _today.withAttempt(attempt));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openArticle() async {
    final articleUrl = _quest.articleUrl;
    if (articleUrl == null) return;
    final uri = Uri.tryParse(articleUrl);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        setState(() => _error = 'Could not open the learning resource.');
      }
    }
  }
}

class _QuestHero extends StatelessWidget {
  final DailyQuest quest;
  final DailyQuestToday today;
  final DailyQuestAttempt? attempt;

  const _QuestHero({required this.quest, required this.today, required this.attempt});

  @override
  Widget build(BuildContext context) {
    final remaining = today.expiresAt?.difference(DateTime.now());
    final countdown = remaining == null
        ? 'LOCAL DAY'
        : remaining.isNegative
        ? 'EXPIRED'
        : '${remaining.inHours}H ${remaining.inMinutes.remainder(60)}M LEFT';
    final status = attempt?.isCompleted == true
        ? 'COMPLETED'
        : attempt?.isPendingReview == true
        ? 'IN REVIEW'
        : countdown;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: HomePalette.ink,
        borderRadius: BorderRadius.circular(28),
        gradient: const RadialGradient(
          center: Alignment(1, -1),
          radius: 1.2,
          colors: [Color(0x24CFFF47), HomePalette.ink],
          stops: [0, .74],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                quest.category.toUpperCase(),
                style: AppFonts.home(
                  color: HomePalette.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacingEm: .14,
                ),
              ),
              Text(
                status,
                style: AppFonts.home(
                  color: Colors.white.withValues(alpha: .75),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            quest.title,
            style: AppFonts.home(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: HomePalette.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                '~${quest.estimatedMinutes} min',
                style: AppFonts.home(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.bolt_rounded, color: HomePalette.primary, size: 16),
              const SizedBox(width: 4),
              Text(
                '+${quest.auraReward} Aura',
                style: AppFonts.home(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String eyebrow;
  final String title;

  const _SectionHeading({required this.eyebrow, required this.title});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: AppFonts.home(
          color: HomePalette.lightLink,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacingEm: .12,
        ),
      ),
      const SizedBox(height: 5),
      Text(title, style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}

class _SurfacePanel extends StatelessWidget {
  final Widget child;

  const _SurfacePanel({required this.child});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomePalette.surface(brightness),
        border: Border.all(color: HomePalette.border(brightness)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _InfoLine({required this.icon, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: HomePalette.lightLink),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 3),
              Text(
                detail,
                style: AppFonts.body(
                  color: HomePalette.textSecondary(brightness),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnswerOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _AnswerOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = brightness == Brightness.dark
        ? HomePalette.primary
        : HomePalette.lightLink;
    return Material(
      color: selected
          ? primary.withValues(alpha: brightness == Brightness.dark ? .15 : .1)
          : HomePalette.surface(brightness),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? primary : HomePalette.border(brightness),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? primary : HomePalette.textSecondary(brightness),
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppFonts.body(
                    color: HomePalette.textPrimary(brightness),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockedProof extends StatelessWidget {
  final VoidCallback? onStart;

  const _LockedProof({required this.onStart});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const _ResultPanel(
        title: 'Ready when you are',
        detail: 'Start today’s quest to unlock its proof step.',
        icon: Icons.lock_outline_rounded,
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start quest'),
        ),
      ),
    ],
  );
}

class _ResultPanel extends StatelessWidget {
  final String title;
  final String detail;
  final IconData icon;

  const _ResultPanel({required this.title, required this.detail, required this.icon});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return _SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: HomePalette.lightLink, size: 28),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 5),
          Text(
            detail,
            style: AppFonts.body(
              color: HomePalette.textSecondary(brightness),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final String message;
  final bool isError;
  final IconData? icon;

  const _InlineMessage({
    required this.message,
    this.isError = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.error
        : HomePalette.lightLink;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? Icons.info_outline_rounded, size: 18, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: AppFonts.body(color: color, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}