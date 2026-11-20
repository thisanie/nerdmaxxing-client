import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/daily_quest.dart';
import '../../models/user_stats.dart';
import '../../providers/app_state_providers.dart';
import '../../services/api_client.dart';
import '../../services/challenges_service.dart';
import '../../services/daily_quests_service.dart';
import '../../theme/app_theme.dart';
import '../challenge/challenge_detail_screen.dart';

enum _QuestStep { learn, prove }

class _DailyQuestSpacing {
  static const screenHorizontal = 24.0;
  static const majorSection = 24.0;
  static const listRow = 20.0;
  static const relatedItems = 12.0;
  static const cardInset = 16.0;
  static const heroInset = 20.0;
  static const infoTile = 44.0;
  static const infoTileRadius = 14.0;
  static const bannerRadius = 20.0;
  static const bodyMaxWidth = 240.0;
}

enum _Lucide { back, clock, bolt, book, lock, check, play }

/// Draws the same Lucide glyphs the HTML preview uses (24px grid, round strokes).
class _LucideIcon extends StatelessWidget {
  final _Lucide icon;
  final double size;
  final Color? color;

  const _LucideIcon(this.icon, {this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ?? IconTheme.of(context).color ?? DefaultTextStyle.of(context).style.color!;
    return CustomPaint(
      size: Size.square(size),
      painter: _LucidePainter(icon, resolved),
    );
  }
}

class _LucidePainter extends CustomPainter {
  final _Lucide icon;
  final Color color;

  _LucidePainter(this.icon, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final p = Path();
    switch (icon) {
      case _Lucide.back:
        p
          ..moveTo(19, 12)
          ..lineTo(5, 12)
          ..moveTo(12, 19)
          ..lineTo(5, 12)
          ..lineTo(12, 5);
      case _Lucide.clock:
        p
          ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 10))
          ..moveTo(12, 6)
          ..lineTo(12, 12)
          ..lineTo(16, 14);
      case _Lucide.bolt:
        p
          ..moveTo(13, 2)
          ..lineTo(3, 14)
          ..lineTo(12, 14)
          ..lineTo(11, 22)
          ..lineTo(21, 10)
          ..lineTo(12, 10)
          ..close();
      case _Lucide.book:
        p
          ..moveTo(2, 3)
          ..lineTo(8, 3)
          ..arcToPoint(const Offset(12, 7), radius: const Radius.circular(4))
          ..lineTo(12, 21)
          ..arcToPoint(
            const Offset(9, 18),
            radius: const Radius.circular(3),
            clockwise: false,
          )
          ..lineTo(2, 18)
          ..close()
          ..moveTo(22, 3)
          ..lineTo(16, 3)
          ..arcToPoint(
            const Offset(12, 7),
            radius: const Radius.circular(4),
            clockwise: false,
          )
          ..lineTo(12, 21)
          ..arcToPoint(const Offset(15, 18), radius: const Radius.circular(3))
          ..lineTo(22, 18)
          ..close();
      case _Lucide.lock:
        p
          ..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(3, 11, 18, 11),
              const Radius.circular(2),
            ),
          )
          ..moveTo(7, 11)
          ..lineTo(7, 7)
          ..arcToPoint(const Offset(17, 7), radius: const Radius.circular(5))
          ..lineTo(17, 11);
      case _Lucide.check:
        p
          ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 10))
          ..moveTo(9, 12)
          ..lineTo(11, 14)
          ..lineTo(15, 10);
      case _Lucide.play:
        p
          ..moveTo(6, 3)
          ..lineTo(20, 12)
          ..lineTo(6, 21)
          ..close();
    }
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(_LucidePainter old) =>
      old.icon != icon || old.color != color;
}

ThemeData _dailyQuestActionTheme(ThemeData theme) {
  final brightness = theme.brightness;
  return theme.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: theme.filledButtonTheme.style?.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.disabled)
              ? DailyQuestPalette.segment(brightness)
              : DailyQuestPalette.lime,
        ),
        foregroundColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.disabled)
              ? DailyQuestPalette.muted(brightness)
              : DailyQuestPalette.ink,
        ),
      ),
    ),
  );
}

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
  XFile? _evidenceFile;
  Uint8List? _evidenceBytes;
  Timer? _countdownTimer;
  Timer? _quizTimer;
  DailyQuestQuizSession? _quizSession;
  DailyQuestQuizResult? _quizResult;
  int? _selectedAnswerIndex;
  int _secondsRemaining = 0;
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
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _quizTimer?.cancel();
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
    final theme = Theme.of(context);
    final foreground = DailyQuestPalette.text(brightness);
    final muted = DailyQuestPalette.muted(brightness);
    return Theme(
      data: _dailyQuestActionTheme(theme),
      child: Scaffold(
        backgroundColor: DailyQuestPalette.background(brightness),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _DailyQuestSpacing.screenHorizontal,
                  4,
                  _DailyQuestSpacing.screenHorizontal,
                  10,
                ),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const _LucideIcon(_Lucide.back, size: 20),
                        style: IconButton.styleFrom(
                          fixedSize: const Size(38, 38),
                          padding: EdgeInsets.zero,
                          side: BorderSide(
                            color: DailyQuestPalette.border(brightness),
                          ),
                          backgroundColor: DailyQuestPalette.background(
                            brightness,
                          ),
                        ),
                      ),
                      const SizedBox(width: _DailyQuestSpacing.relatedItems),
                      Text(
                        'Daily quest',
                        style: AppFonts.home(
                          color: foreground,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    _DailyQuestSpacing.screenHorizontal,
                    0,
                    _DailyQuestSpacing.screenHorizontal,
                    _DailyQuestSpacing.majorSection,
                  ),
                  children: [
                    _QuestHero(quest: quest, today: _today, attempt: _attempt),
                    const SizedBox(height: _DailyQuestSpacing.majorSection),
                    _buildStepSelector(brightness),
                    const SizedBox(height: _DailyQuestSpacing.majorSection),
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
              if (_attempt?.isCompleted == true && _step == _QuestStep.learn)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _DailyQuestSpacing.screenHorizontal,
                    _DailyQuestSpacing.majorSection,
                    _DailyQuestSpacing.screenHorizontal,
                    _DailyQuestSpacing.majorSection,
                  ),
                  child: const _InlineMessage(
                    message: 'Quest complete. Your streak is up to date.',
                    icon: Icons.check_circle_rounded,
                    banner: true,
                  ),
                )
              else if (_showStartQuestAction)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _DailyQuestSpacing.screenHorizontal,
                    _DailyQuestSpacing.relatedItems,
                    _DailyQuestSpacing.screenHorizontal,
                    14,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                      ),
                      onPressed: _starting ? null : _startQuest,
                      icon: _starting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const _LucideIcon(_Lucide.play, size: 18),
                      label: Text(
                        _starting ? 'Starting...' : 'Start quest',
                        style: AppFonts.home(
                          color: foreground,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _showStartQuestAction => _step == _QuestStep.learn
      ? _attempt?.isCompleted != true && _attempt?.isPendingReview != true
      : _attempt == null;

  Widget _buildStepSelector(Brightness brightness) {
    Widget segment({
      required _QuestStep step,
      required _Lucide icon,
      required String label,
      required bool locked,
    }) {
      final selected = _step == step;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() {
              _step = step;
              _error = null;
            }),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 44,
              decoration: BoxDecoration(
                color: selected ? DailyQuestPalette.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LucideIcon(
                    locked ? _Lucide.lock : icon,
                    size: 19,
                    color: selected
                        ? DailyQuestPalette.lime
                        : DailyQuestPalette.muted(brightness),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: AppFonts.home(
                      color: selected
                          ? DailyQuestPalette.lime
                          : DailyQuestPalette.muted(brightness),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DailyQuestPalette.segment(brightness),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          segment(
            step: _QuestStep.learn,
            icon: _Lucide.book,
            label: 'Learn',
            locked: false,
          ),
          segment(
            step: _QuestStep.prove,
            icon: _Lucide.check,
            label: 'Prove',
            locked: _attempt == null,
          ),
        ],
      ),
    );
  }

  Widget _buildLearn(DailyQuest quest, Color muted) {
    final instructions = quest.instructions.trim().isNotEmpty
        ? quest.instructions.trim()
        : quest.description.trim();
    final duplicateInstructions =
        instructions.toLowerCase() == quest.title.trim().toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          eyebrow: 'Your 10-minute mission',
          title: 'Learn something you can explain',
        ),
        if (instructions.isNotEmpty && !duplicateInstructions) ...[
          const SizedBox(height: _DailyQuestSpacing.relatedItems),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: _DailyQuestSpacing.bodyMaxWidth,
            ),
            child: Text(
              instructions,
              style: AppFonts.body(
                color: DailyQuestPalette.lightMuted,
                fontSize: 14,
                height: 20 / 14,
              ),
            ),
          ),
        ],
        if (quest.articleUrl != null) ...[
          const SizedBox(height: _DailyQuestSpacing.relatedItems),
          OutlinedButton.icon(
            onPressed: _openArticle,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open learning resource'),
          ),
        ],
        const SizedBox(height: _DailyQuestSpacing.majorSection),
        _InfoLine(
          icon: _Lucide.check,
          title: 'How to complete it',
          detail: quest.verificationType == 'QUIZ'
              ? 'Score at least 80% on the quiz. One retry is available before the quest expires.'
              : 'Submit ${quest.verificationType == 'VIDEO' ? 'a video' : 'a photo'} for review. Your submission stays private.',
        ),
        const SizedBox(height: _DailyQuestSpacing.listRow),
        _InfoLine(
          icon: _Lucide.bolt,
          title: 'Earn ${quest.auraReward} Aura',
          detail: quest.verificationType == 'QUIZ'
              ? 'Awarded once when you pass.'
              : 'Awarded once after your submission is approved.',
        ),
        if (_attempt?.isPendingReview == true)
          const _InlineMessage(
            message: 'Your proof is in review. We will update your quest when it is checked.',
            icon: Icons.hourglass_top_rounded,
          ),
      ],
    );
  }

  Widget _buildProve(DailyQuest quest, Color foreground, Color muted) {
    if (_attempt == null) {
      return const _LockedProof();
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
    final result = _quizResult;
    final session = _quizSession;
    if (result != null) {
      final canRetry = result.quizAttemptsRemaining > 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(eyebrow: 'QUIZ RESULT', title: 'The result is in.'),
          const SizedBox(height: 12),
          _ResultPanel(
            title: result.passed == true ? 'Quest complete' : 'Not quite yet',
            detail: result.passed == true
                ? 'Score: ${result.scorePercent?.round() ?? 0}%. '
                      'Aura awarded: ${result.auraAwarded}.'
                : 'Score: ${result.scorePercent?.round() ?? 0}%. '
                      '${canRetry ? '${result.quizAttemptsRemaining} retry remaining.' : 'No retries remain today.'}',
            icon: result.passed == true
                ? Icons.verified_rounded
                : Icons.refresh_rounded,
          ),
          if (canRetry) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _starting ? null : _startQuizSession,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_starting ? 'Starting...' : 'Try again'),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(eyebrow: 'TIMED QUIZ', title: 'Show what stuck.'),
        const SizedBox(height: 8),
        if (session == null)
          _SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'One question at a time',
                  style: AppFonts.body(
                    color: foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Each answer has a server-timed window. Your score and reward are confirmed when the session ends.',
                  style: AppFonts.body(color: muted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _starting ? null : _startQuizSession,
                    icon: _starting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(_starting ? 'Starting...' : 'Begin timed quiz'),
                  ),
                ),
              ],
            ),
          )
        else
          _buildActiveQuestion(session, foreground),
      ],
    );
  }

  Widget _buildActiveQuestion(DailyQuestQuizSession session, Color foreground) {
    final question = session.question;
    if (question == null) {
      return const _InlineMessage(
        message: 'The next quiz question could not be loaded.',
        isError: true,
      );
    }
    final questionNumber =
        session.questionNumber ??
        (session.questionIndex == null ? 1 : session.questionIndex! + 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (session.timedOut) ...[
          const _InlineMessage(
            message:
                'The previous answer timed out. Continue with this question.',
            icon: Icons.timer_off_rounded,
          ),
          const SizedBox(height: 10),
        ],
        _SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'QUESTION $questionNumber OF ${session.totalQuestions}',
                      style: AppFonts.home(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacingEm: .1,
                      ),
                    ),
                  ),
                  Text(
                    session.answerDeadlineAt == null
                        ? 'TIMER --'
                        : '$_secondsRemaining s',
                    style: AppFonts.home(
                      color: _secondsRemaining <= 5
                          ? Theme.of(context).colorScheme.error
                          : foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: session.totalQuestions == 0
                    ? 0
                    : questionNumber / session.totalQuestions,
                minHeight: 4,
              ),
              const SizedBox(height: 14),
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
              for (
                var optionIndex = 0;
                optionIndex < question.options.length;
                optionIndex++
              )
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: _AnswerOption(
                    label: question.options[optionIndex],
                    selected: _selectedAnswerIndex == optionIndex,
                    onTap: _submitting
                        ? null
                        : () => setState(
                            () => _selectedAnswerIndex = optionIndex,
                          ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _submitting || _selectedAnswerIndex == null
                ? null
                : () => _submitQuizAnswer(timedOut: false),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_submitting ? 'Submitting...' : 'Submit answer'),
          ),
        ),
      ],
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
                color: Theme.of(context).colorScheme.primary,
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
                icon: Icon(
                  isVideo
                      ? Icons.video_library_outlined
                      : Icons.add_photo_alternate_outlined,
                ),
                label: Text(
                  _evidenceFile == null
                      ? 'Choose ${isVideo ? 'video' : 'photo'}'
                      : 'Replace file',
                ),
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
      final attempt = await context.read<DailyQuestsService>().startToday(
        timezone: _today.timezone,
      );
      if (!mounted) return;
      setState(() {
        _today = _today.withAttempt(attempt);
        _step = _QuestStep.prove;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _startQuizSession() async {
    setState(() {
      _starting = true;
      _error = null;
      _quizResult = null;
    });
    try {
      final session = await context.read<DailyQuestsService>().startQuizSession(
        timezone: _today.timezone,
      );
      if (!mounted) return;
      _acceptQuizSession(session);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _acceptQuizSession(DailyQuestQuizSession session) {
    if (session.result != null) {
      _finishQuiz(session.result!);
      return;
    }
    setState(() {
      _quizSession = session;
      _selectedAnswerIndex = null;
      _error = null;
    });
    _startQuestionTimer();
  }

  void _startQuestionTimer() {
    _quizTimer?.cancel();
    final deadline = _quizSession?.answerDeadlineAt;
    if (deadline == null) {
      setState(() => _secondsRemaining = 0);
      return;
    }
    void updateRemaining() {
      if (!mounted || _submitting) return;
      final remaining = deadline.difference(DateTime.now()).inMilliseconds;
      final seconds = math.max(0, (remaining / 1000).ceil()).toInt();
      setState(() => _secondsRemaining = seconds);
      if (seconds == 0) _submitQuizAnswer(timedOut: true);
    }

    updateRemaining();
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      updateRemaining();
    });
  }

  Future<void> _submitQuizAnswer({required bool timedOut}) async {
    final session = _quizSession;
    if (session == null || _submitting) return;
    final questionIndex =
        session.questionIndex ??
        (session.questionNumber == null ? null : session.questionNumber! - 1);
    if (questionIndex == null || questionIndex < 0) {
      setState(
        () => _error = 'The current quiz question could not be identified.',
      );
      return;
    }
    _quizTimer?.cancel();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final nextSession = await context
          .read<DailyQuestsService>()
          .submitQuizAnswer(
            sessionId: session.sessionId,
            questionIndex: questionIndex,
            answerOptionIndex: timedOut ? null : _selectedAnswerIndex,
          );
      if (!mounted) return;
      if (nextSession.result != null) {
        _finishQuiz(nextSession.result!);
      } else {
        _acceptQuizSession(nextSession);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
        _startQuestionTimer();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _finishQuiz(DailyQuestQuizResult result) async {
    _quizTimer?.cancel();
    final attempt = DailyQuestAttempt(
      id: result.attemptId,
      status: result.status,
      quizAttemptsUsed: result.quizAttemptCount,
      quizAttemptsRemaining: result.quizAttemptsRemaining,
      score: result.scorePercent?.round(),
      passed: result.passed,
    );
    setState(() {
      _quizResult = result;
      _quizSession = null;
      _today = _today.withAttempt(attempt);
    });
    try {
      final attemptResult = await context
          .read<DailyQuestsService>()
          .getAttemptResult(result.attemptId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DailyQuestRewardScreen(result: attemptResult),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
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
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        setState(() => _error = 'Could not open the learning resource.');
      }
    }
  }
}

class DailyQuestRewardScreen extends StatelessWidget {
  final DailyQuestAttemptResult result;
  final bool rewardAlreadyApplied;

  const DailyQuestRewardScreen({
    super.key,
    required this.result,
    this.rewardAlreadyApplied = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final challenge = result.relatedMajorChallenge;
    final completed =
        result.completionStatus.toUpperCase() == 'COMPLETED' ||
        result.status.toUpperCase() == 'COMPLETED' ||
        result.status.toUpperCase() == 'APPROVED';
    if (completed) {
      return _DailyQuestCelebration(
        result: result,
        rewardAlreadyApplied: rewardAlreadyApplied,
        onOpenChallenge: (item) => _openChallenge(context, item),
      );
    }
    return Theme(
      data: _dailyQuestActionTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: HomePalette.background(brightness),
        appBar: AppBar(title: const Text('Daily Quest Result')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: .65, end: 1),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          completed
                              ? Icons.bolt_rounded
                              : Icons.hourglass_bottom_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 52,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      completed ? 'Quest complete' : 'Quest result',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (result.scorePercent != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Score ${result.scorePercent!.round()}%',
                        style: AppFonts.body(
                          color: HomePalette.textSecondary(brightness),
                          fontSize: 15,
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: _RewardMetric(
                            icon: Icons.bolt_rounded,
                            label: 'AURA',
                            value: result.auraAwarded,
                            suffix: 'earned',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RewardMetric(
                            icon: Icons.local_fire_department_rounded,
                            label: 'DAY STREAK',
                            value: result.dayStreak,
                            suffix: 'days',
                          ),
                        ),
                      ],
                    ),
                    if (challenge != null) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openChallenge(context, challenge),
                          icon: const Icon(Icons.flag_rounded),
                          label: Text('View ${challenge.title}'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back to Daily Quest'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openChallenge(
    BuildContext context,
    DailyQuestRelatedChallenge challenge,
  ) async {
    try {
      final item = await context.read<ChallengesService>().getBySlug(
        challenge.slug,
      );
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ChallengeDetailScreen(slug: item.slug, initialChallenge: item),
        ),
      );
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _DailyQuestCelebration extends ConsumerStatefulWidget {
  final DailyQuestAttemptResult result;
  final bool rewardAlreadyApplied;
  final Future<void> Function(DailyQuestRelatedChallenge challenge)
  onOpenChallenge;

  const _DailyQuestCelebration({
    required this.result,
    required this.rewardAlreadyApplied,
    required this.onOpenChallenge,
  });

  @override
  ConsumerState<_DailyQuestCelebration> createState() =>
      _DailyQuestCelebrationState();
}

class _DailyQuestCelebrationState extends ConsumerState<_DailyQuestCelebration>
  with TickerProviderStateMixin {
  late final AnimationController _flamePulse;
  late final AnimationController _auraCounter;
  Timer? _flameTimer;
  Timer? _streakTimer;
  Timer? _auraChipTimer;
  Timer? _auraFlyTimer;
  int _frame = 0;
  int _streakValue = 0;
  bool _flameLit = false;
  bool _todayChecked = false;
  bool _statsReady = false;
  bool _auraSequenceStarted = false;
  bool _auraChipVisible = false;
  bool _auraChipFlying = false;
  bool _auraCountStarted = false;
  int? _auraBefore;
  int? _auraAfter;
  int? _rankProgressAfter;
  int? _auraToNextAfter;
  String _rank = 'E';
  String? _nextRank;
  List<UserActivityDay> _activityDays = const [];

  int get _awardedAura => widget.result.auraAwarded;
  Color get _primary => HomePalette.primary;
  Color get _onPrimary => HomePalette.ink;
  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get _textSecondary => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _border => Theme.of(context).colorScheme.outline;

  @override
  void initState() {
    super.initState();
    _streakValue = math.max(0, widget.result.dayStreak - 1).toInt();
    _flamePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _auraCounter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    final previousStats = ref.read(myStatsProvider).valueOrNull;
    final currentAura = previousStats?.auraPoints ?? 0;
    _auraBefore = widget.rewardAlreadyApplied
      ? math.max(0, currentAura - _awardedAura).toInt()
      : currentAura;
    _auraAfter = widget.rewardAlreadyApplied
      ? currentAura
      : currentAura + _awardedAura;
    if (previousStats != null) {
      _rank = previousStats.rank;
      _nextRank = previousStats.nextRank;
      _rankProgressAfter = previousStats.rankProgress.clamp(0, 100).toInt();
      _auraToNextAfter = previousStats.auraToNextRank;
      _activityDays = previousStats.activityDays;
      _statsReady = true;
    }
    _loadUpdatedStats(previousStats);
    _flameTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _flameLit = true);
    });
    _streakTimer = Timer(const Duration(milliseconds: 1250), () {
      if (!mounted) return;
      setState(() {
        _streakValue = widget.result.dayStreak;
        _todayChecked = true;
      });
    });
  }

  @override
  void dispose() {
    _flameTimer?.cancel();
    _streakTimer?.cancel();
    _auraChipTimer?.cancel();
    _auraFlyTimer?.cancel();
    _flamePulse.dispose();
    _auraCounter.dispose();
    super.dispose();
  }

  Future<void> _loadUpdatedStats(UserStats? previousStats) async {
    ref.invalidate(myStatsProvider);
    try {
      final stats = await ref.read(myStatsProvider.future);
      if (!mounted) return;
      final auraAwarded = widget.result.auraAwarded;
      final cachedAuraIsBefore =
          previousStats != null &&
          stats.auraPoints - previousStats.auraPoints == auraAwarded;

      setState(() {
        _auraBefore = widget.rewardAlreadyApplied
            ? math.max(0, stats.auraPoints - auraAwarded).toInt()
            : cachedAuraIsBefore
            ? previousStats.auraPoints
            : math.max(0, stats.auraPoints - auraAwarded).toInt();
        _auraAfter = widget.rewardAlreadyApplied
            ? stats.auraPoints
            : math.max(
                stats.auraPoints,
                _auraBefore! + auraAwarded,
              ).toInt();
        _rankProgressAfter = stats.rankProgress.clamp(0, 100).toInt();
        _auraToNextAfter = stats.auraToNextRank;
        _rank = stats.rank;
        _nextRank = stats.nextRank;
        _activityDays = stats.activityDays;
        _statsReady = previousStats != null;
      });
      _maybeStartAuraCount();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (previousStats != null) {
          _auraBefore = widget.rewardAlreadyApplied
              ? math.max(0, previousStats.auraPoints - _awardedAura).toInt()
              : previousStats.auraPoints;
          _auraAfter = widget.rewardAlreadyApplied
              ? previousStats.auraPoints
              : previousStats.auraPoints + _awardedAura;
          _rank = previousStats.rank;
          _nextRank = previousStats.nextRank;
          _rankProgressAfter = previousStats.rankProgress.clamp(0, 100).toInt();
          _auraToNextAfter = previousStats.auraToNextRank;
          _activityDays = previousStats.activityDays;
        }
        _statsReady = true;
      });
      _maybeStartAuraCount();
    }
  }

  void _openAuraFrame() {
    setState(() => _frame = 1);
    _startAuraAnimation();
    _maybeStartAuraCount();
  }

  void _startAuraAnimation() {
    if (_auraSequenceStarted) return;
    _auraSequenceStarted = true;
    _auraChipTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _auraChipVisible = true);
    });
    _auraFlyTimer = Timer(const Duration(milliseconds: 1150), () {
      if (mounted) setState(() => _auraChipFlying = true);
    });
  }

  void _maybeStartAuraCount() {
    if (_auraCountStarted || _frame != 1) {
      return;
    }
    setState(() => _auraCountStarted = true);
    _auraCounter.forward(from: 0);
  }

  List<DateTime> _weekDates() {
    final statsDates = _activityDays
        .map((day) => DateTime.tryParse(day.date))
        .whereType<DateTime>()
        .toList(growable: false);
    if (statsDates.length == 7) return statsDates;

    final parsed = DateTime.tryParse(
      widget.result.completionDate ??
          widget.result.completedAt?.toIso8601String() ??
          '',
    );
    final end = parsed == null
        ? DateTime.now()
        : DateTime(parsed.year, parsed.month, parsed.day);
    return List.generate(
      7,
      (index) => end.subtract(Duration(days: 6 - index)),
    );
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Widget _header(String title) => Row(
    children: [
      IconButton(
        tooltip: 'Back',
        onPressed: _frame == 0
            ? () => Navigator.of(context).pop()
            : () => setState(() => _frame = 0),
        icon: const Icon(Icons.arrow_back_rounded),
        color: _textPrimary,
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: AppFonts.body(
          color: _textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _continueButton({required String label, required VoidCallback onTap}) =>
      SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: _onPrimary,
            shape: const StadiumBorder(),
            textStyle: AppFonts.body(
              color: _onPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(label),
        ),
      );

  Widget _streakFrame() {
    const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final dates = _weekDates();
    final activeDays = {for (final day in _activityDays) day.date: day.active};
    return Column(
      key: const ValueKey('streak-frame'),
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _flamePulse,
                builder: (context, child) {
                  final pulse = _flamePulse.value;
                  return AnimatedScale(
                    scale: _flameLit ? 1 : .76,
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.elasticOut,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: _flameLit
                            ? [
                                BoxShadow(
                                  color: _primary.withValues(
                                    alpha: .2 + pulse * .32,
                                  ),
                                  blurRadius: 28 + pulse * 18,
                                  spreadRadius: 5 + pulse * 6,
                                ),
                              ]
                            : const [],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        size: 142,
                        color: _flameLit ? _primary : _textSecondary,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(
                height: 112,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 700),
                  transitionBuilder: (child, animation) => ClipRect(
                    child: FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: animation.drive(
                          Tween<Offset>(
                            begin: const Offset(0, .8),
                            end: Offset.zero,
                          ),
                        ),
                        child: child,
                      ),
                    ),
                  ),
                  child: Text(
                    '$_streakValue',
                    key: ValueKey(_streakValue),
                    style: AppFonts.poster(
                      color: _primary,
                      fontSize: 96,
                      wdth: 100,
                    ),
                  ),
                ),
              ),
              Text(
                'DAY STREAK',
                style: AppFonts.label(
                  color: _textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _todayChecked
                    ? 'Streak extended. Come back tomorrow.'
                    : 'Your daily quest keeps the streak going.',
                textAlign: TextAlign.center,
                style: AppFonts.body(
                  color: _textPrimary.withValues(alpha: .82),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            for (var index = 0; index < dates.length; index++) ...[
              if (index > 0) const SizedBox(width: 4),
              Expanded(
                child: _weekDay(
                  dates[index],
                  index == dates.length - 1
                      ? 'Today'
                      : weekdayLabels[dates[index].weekday - 1],
                  isToday: index == dates.length - 1,
                  activeDays: activeDays,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 22),
        _continueButton(label: 'Continue', onTap: _openAuraFrame),
      ],
    );
  }

  Widget _weekDay(
    DateTime date,
    String label, {
    required bool isToday,
    required Map<String, bool> activeDays,
  }) {
    final filled = isToday ? _todayChecked : activeDays[_dateKey(date)] == true;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? _primary : Colors.transparent,
            border: Border.all(
                color: filled ? _primary : _border,
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: _primary.withValues(alpha: .28),
                      blurRadius: 12,
                    ),
                  ]
                : const [],
          ),
          child: Icon(
            Icons.check_rounded,
            size: 16,
            color: filled ? _onPrimary : Colors.transparent,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          style: AppFonts.body(
            color: _textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _auraFrame(UserStats? watchedStats) {
    final auraBefore = _auraBefore ?? 0;
    final auraAfter = _auraAfter ?? _awardedAura;
    final progressAfter = _rankProgressAfter ?? watchedStats?.rankProgress;
    final auraToNextAfter = _auraToNextAfter ?? watchedStats?.auraToNextRank;
    final nextRank = _nextRank ?? watchedStats?.nextRank;
    final hasRankStats = _statsReady || watchedStats != null;
    final isMaxRank = hasRankStats && nextRank == null;
    final rankProgress = isMaxRank ? 100 : progressAfter ?? 0;
    return Column(
      key: const ValueKey('aura-frame'),
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Rank $_rank',
                  style: AppFonts.body(
                    color: _onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'TOTAL AURA',
                style: AppFonts.label(
                  color: _textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 128,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _auraCounter,
                    builder: (context, _) {
                      final progress = Curves.easeOutCubic.transform(
                        _auraCounter.value,
                      );
                      final value = auraBefore +
                          ((auraAfter - auraBefore) * progress).round();
                      return Text(
                        value.toString(),
                        style: AppFonts.poster(
                          color: _auraCountStarted ? _primary : _textPrimary,
                          fontSize: 88,
                          wdth: 100,
                        ),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(
                height: 42,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    AnimatedSlide(
                      offset: _auraChipFlying
                          ? const Offset(0, -2.6)
                          : _auraChipVisible
                          ? Offset.zero
                          : const Offset(0, .6),
                      duration: Duration(
                        milliseconds: _auraChipFlying ? 550 : 450,
                      ),
                      curve: Curves.easeOutBack,
                      child: AnimatedOpacity(
                        opacity: _auraChipVisible && !_auraChipFlying ? 1 : 0,
                        duration: const Duration(milliseconds: 350),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: _primary.withValues(alpha: .35),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: Text(
                            '+$_awardedAura Aura',
                            style: AppFonts.body(
                              color: _onPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: 10,
                        child: hasRankStats && (isMaxRank || progressAfter != null)
                            ? TweenAnimationBuilder<double>(
                                key: ValueKey('aura-progress-$_statsReady'),
                                tween: Tween<double>(
                                  begin: 0,
                                  end: rankProgress / 100,
                                ),
                                duration: const Duration(milliseconds: 900),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) =>
                                    LinearProgressIndicator(
                                  value: value.clamp(0, 1).toDouble(),
                                  backgroundColor: _textPrimary.withValues(
                                    alpha: .12,
                                  ),
                                  valueColor: AlwaysStoppedAnimation(_primary),
                                ),
                              )
                            : LinearProgressIndicator(
                                value: 0,
                                backgroundColor: _textPrimary.withValues(
                                  alpha: .12,
                                ),
                                valueColor: AlwaysStoppedAnimation(_primary),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            !hasRankStats
                              ? 'Loading next rank'
                              : isMaxRank
                              ? 'MAX RANK'
                              : '${auraToNextAfter ?? 0} AP to ${nextRank ?? 'next rank'}',
                          style: AppFonts.body(
                            color: _textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${hasRankStats ? rankProgress : 0}%',
                          style: AppFonts.body(
                            color: _textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.result.relatedMajorChallenge case final challenge?) ...[
          TextButton(
            onPressed: () => widget.onOpenChallenge(challenge),
            style: TextButton.styleFrom(foregroundColor: _primary),
            child: Text('View ${challenge.title}'),
          ),
        ],
        _continueButton(
          label: 'Continue',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final watchedStats = ref.watch(myStatsProvider).valueOrNull;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  _header(_frame == 0 ? 'Streak' : 'Quest complete'),
                  const SizedBox(height: 12),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                        child: _frame == 0
                          ? _streakFrame()
                          : _auraFrame(watchedStats),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final String suffix;

  const _RewardMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return _SurfacePanel(
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppFonts.home(
              color: HomePalette.textSecondary(brightness),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, current, _) => Text(
              '${current.round()} $suffix',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestHero extends StatelessWidget {
  final DailyQuest quest;
  final DailyQuestToday today;
  final DailyQuestAttempt? attempt;

  const _QuestHero({
    required this.quest,
    required this.today,
    required this.attempt,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final remaining = today.expiresAt?.difference(DateTime.now());
    final countdown = remaining == null
        ? 'Today'
        : remaining.isNegative
        ? 'Expired'
        : '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m left';
    final status = attempt?.isCompleted == true
        ? 'Completed'
        : attempt?.isPendingReview == true
        ? 'In review'
        : countdown;
    return Container(
      padding: const EdgeInsets.all(_DailyQuestSpacing.heroInset),
      decoration: BoxDecoration(
        color: DailyQuestPalette.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: DailyQuestPalette.lime,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      quest.category
                          .toLowerCase()
                          .split(' ')
                          .map((word) {
                            if (word.isEmpty) return word;
                            return '${word[0].toUpperCase()}${word.substring(1)}';
                          })
                          .join(' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.home(
                        color: DailyQuestPalette.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: DailyQuestPalette.heroText(brightness)
                          .withValues(alpha: .3),
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (attempt?.isCompleted == true)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: DailyQuestPalette.heroMuted(brightness),
                        )
                      else
                        _LucideIcon(
                          _Lucide.clock,
                          size: 16,
                          color: DailyQuestPalette.heroMuted(brightness),
                        ),
                      const SizedBox(width: _DailyQuestSpacing.relatedItems),
                      Flexible(
                        child: Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.home(
                            color: DailyQuestPalette.heroMuted(brightness),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _DailyQuestSpacing.relatedItems),
          Text(
            quest.title,
            style: AppFonts.home(
              color: DailyQuestPalette.heroText(brightness),
              fontSize: 28,
              fontWeight: FontWeight.w500,
              height: 34 / 28,
            ),
          ),
          const SizedBox(height: _DailyQuestSpacing.relatedItems),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _HeroMetric(
                icon: _Lucide.clock,
                label: '${quest.estimatedMinutes} min',
              ),
              _HeroMetric(
                icon: _Lucide.bolt,
                label: '+${quest.auraReward} Aura',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final _Lucide icon;
  final String label;

  const _HeroMetric({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _LucideIcon(icon, color: DailyQuestPalette.lime, size: 18),
      const SizedBox(width: _DailyQuestSpacing.relatedItems),
      Text(
        label,
        style: AppFonts.home(
          color: DailyQuestPalette.lime,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
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
          color: const Color(0xFF3B6D11),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ).copyWith(letterSpacing: .4),
      ),
      const SizedBox(height: _DailyQuestSpacing.relatedItems),
      if (MediaQuery.textScalerOf(context).scale(22) <= 22)
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            maxLines: 1,
            style: AppFonts.home(
              color: DailyQuestPalette.text(Theme.of(context).brightness),
              fontSize: 22,
              fontWeight: FontWeight.w500,
              height: 28 / 22,
            ),
          ),
        )
      else
        Text(
          title,
          style: AppFonts.home(
            color: DailyQuestPalette.text(Theme.of(context).brightness),
            fontSize: 22,
            fontWeight: FontWeight.w500,
            height: 28 / 22,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
    ],
  );
}

class _SurfacePanel extends StatelessWidget {
  final Widget child;

  const _SurfacePanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: DailyQuestPalette.card(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(19),
      ),
      child: child,
    );
  }
}

class _InfoLine extends StatelessWidget {
  final _Lucide icon;
  final String title;
  final String detail;

  const _InfoLine({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _DailyQuestSpacing.infoTile,
          height: _DailyQuestSpacing.infoTile,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DailyQuestPalette.iconBackground(brightness),
            border: Border.all(
              color: DailyQuestPalette.lightBorder,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(
              _DailyQuestSpacing.infoTileRadius,
            ),
          ),
          child: _LucideIcon(
            icon,
            size: 22,
            color: DailyQuestPalette.iconAccent(brightness),
          ),
        ),
        const SizedBox(width: _DailyQuestSpacing.relatedItems),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppFonts.home(
                  color: DailyQuestPalette.text(brightness),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 22 / 16,
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _DailyQuestSpacing.bodyMaxWidth,
                ),
                child: Text(
                  detail,
                  style: AppFonts.body(
                    color: DailyQuestPalette.lightMuted,
                    fontSize: 14,
                    height: 20 / 14,
                  ),
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

  const _AnswerOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = DailyQuestPalette.iconAccent(brightness);
    return Material(
      color: selected
          ? primary.withValues(alpha: brightness == Brightness.dark ? .15 : .1)
          : DailyQuestPalette.background(brightness),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? primary : DailyQuestPalette.border(brightness),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? primary : DailyQuestPalette.muted(brightness),
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppFonts.body(
                    color: DailyQuestPalette.text(brightness),
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
  const _LockedProof();

  @override
  Widget build(BuildContext context) => const _ResultPanel(
    title: 'Ready when you are',
    detail: "Start today's quest to unlock its proof step.",
    icon: Icons.lock_outline_rounded,
    lucide: _Lucide.lock,
  );
}

class _ResultPanel extends StatelessWidget {
  final String title;
  final String detail;
  final IconData icon;
  final _Lucide? lucide;

  const _ResultPanel({
    required this.title,
    required this.detail,
    required this.icon,
    this.lucide,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return _SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DailyQuestPalette.iconBackground(brightness),
              border: Border.all(color: DailyQuestPalette.border(brightness)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: lucide != null
                ? _LucideIcon(
                    lucide!,
                    size: 22,
                    color: DailyQuestPalette.iconAccent(brightness),
                  )
                : Icon(
                    icon,
                    color: DailyQuestPalette.iconAccent(brightness),
                    size: 22,
                  ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: AppFonts.home(
              color: DailyQuestPalette.text(brightness),
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            style: AppFonts.body(
              color: DailyQuestPalette.muted(brightness),
              fontSize: 14,
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
  final bool banner;

  const _InlineMessage({
    required this.message,
    this.isError = false,
    this.icon,
    this.banner = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = isError
        ? Theme.of(context).colorScheme.error
        : DailyQuestPalette.iconAccent(brightness);
    final textColor = banner && !isError
        ? DailyQuestPalette.iconAccent(brightness)
        : color;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        banner ? _DailyQuestSpacing.cardInset : 13,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(
          banner ? _DailyQuestSpacing.bannerRadius : 12,
        ),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? Icons.info_outline_rounded,
            size: banner ? 24 : 18,
            color: color,
          ),
          SizedBox(
            width: banner ? _DailyQuestSpacing.relatedItems : 9,
          ),
          Expanded(
            child: Text(
              message,
              style: AppFonts.body(
                color: textColor,
                fontSize: banner ? 14 : 12,
                height: banner ? 20 / 14 : 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
