import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/daily_quest.dart';
import '../../services/api_client.dart';
import '../../services/challenges_service.dart';
import '../../services/daily_quests_service.dart';
import '../../theme/app_theme.dart';
import '../challenge/challenge_detail_screen.dart';

enum _QuestStep { learn, prove }

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
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
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
                      const SizedBox(width: 12),
                      Text(
                        'Daily quest',
                        style: AppFonts.home(
                          color: foreground,
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    _QuestHero(quest: quest, today: _today, attempt: _attempt),
                    const SizedBox(height: 13),
                    _buildStepSelector(brightness),
                    const SizedBox(height: 14),
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
              if (_showStartQuestAction)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          eyebrow: 'YOUR 10-MINUTE MISSION',
          title: 'Learn something you can explain',
        ),
        if (instructions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            instructions,
            style: AppFonts.body(color: muted, fontSize: 14, height: 1.45),
          ),
        ],
        if (quest.articleUrl != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openArticle,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open learning resource'),
          ),
        ],
        const SizedBox(height: 20),
        _InfoLine(
          icon: _Lucide.check,
          title: 'How to complete it',
          detail: quest.verificationType == 'QUIZ'
              ? 'Score at least 80% on the quiz. One retry is available before the quest expires.'
              : 'Submit ${quest.verificationType == 'VIDEO' ? 'a video' : 'a photo'} for review. Your submission stays private.',
        ),
        const SizedBox(height: 14),
        _InfoLine(
          icon: _Lucide.bolt,
          title: 'Earn ${quest.auraReward} Aura',
          detail: quest.verificationType == 'QUIZ'
              ? 'Awarded once when you pass.'
              : 'Awarded once after your submission is approved.',
        ),
        if (_attempt?.isCompleted == true)
          const _InlineMessage(
            message: 'Quest complete. Your streak is up to date.',
            icon: Icons.verified_rounded,
          )
        else if (_attempt?.isPendingReview == true)
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

  const DailyQuestRewardScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final challenge = result.relatedMajorChallenge;
    final completed =
        result.completionStatus.toUpperCase() == 'COMPLETED' ||
        result.status.toUpperCase() == 'COMPLETED' ||
        result.status.toUpperCase() == 'APPROVED';
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
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      decoration: BoxDecoration(
        color: DailyQuestPalette.ink,
        borderRadius: BorderRadius.circular(26),
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
                      _LucideIcon(
                        _Lucide.clock,
                        size: 16,
                        color: DailyQuestPalette.heroMuted(brightness),
                      ),
                      const SizedBox(width: 6),
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
          const SizedBox(height: 22),
          Text(
            quest.title,
            style: AppFonts.home(
              color: DailyQuestPalette.heroText(brightness),
              fontSize: 30,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
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
      const SizedBox(width: 7),
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
          color: DailyQuestPalette.iconAccent(Theme.of(context).brightness),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacingEm: .04,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        title,
        style: AppFonts.home(
          color: DailyQuestPalette.text(Theme.of(context).brightness),
          fontSize: 23,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
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
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DailyQuestPalette.iconBackground(brightness),
            border: Border.all(color: DailyQuestPalette.border(brightness)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: _LucideIcon(
            icon,
            size: 22,
            color: DailyQuestPalette.iconAccent(brightness),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                title,
                style: AppFonts.home(
                  color: DailyQuestPalette.text(brightness),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
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

  const _InlineMessage({
    required this.message,
    this.isError = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.error
        : DailyQuestPalette.iconAccent(Theme.of(context).brightness);
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
