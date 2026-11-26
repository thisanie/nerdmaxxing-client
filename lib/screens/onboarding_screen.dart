import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_quest.dart';
import '../models/onboarding_demo.dart';
import '../services/discussions_service.dart';
import '../services/evidence_service.dart';
import '../theme/app_theme.dart';
import 'challenge/challenge_journey.dart';
import 'challenge/path_screen.dart';
import 'daily_quest/daily_quest_screen.dart';
import 'discover/people_discover_screen.dart';
import 'evidence/submit_evidence_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
  with SingleTickerProviderStateMixin {
  static const _durations = [
    Duration(milliseconds: 1900),
    Duration(milliseconds: 1450),
    Duration(milliseconds: 1450),
    Duration(milliseconds: 1350),
    Duration(milliseconds: 1750),
    Duration(milliseconds: 1550),
    Duration(milliseconds: 700),
    Duration(milliseconds: 1350),
    Duration(milliseconds: 4000),
  ];

  static const _titles = [
    'Find your next challenge',
    'Choose your trial',
    'Make it yours',
    'Log your progress',
    'Finish the milestones',
    'Show what you did',
    'Send your proof',
    'Get verified',
    'Earn Aura',
  ];

  static const _subtitles = [
    'Search the challenge library.',
    'Open a challenge that fits your goal.',
    'Accept it and start your path.',
    'Every attempt moves you forward.',
    'Complete each step at your pace.',
    'Attach a short video as proof.',
    'Your submission goes for review.',
    'Approved proof completes the challenge.',
    'Your reward is added to your total.',
  ];

  int _step = 0;
  bool _finished = false;
  Timer? _timer;
  late final AnimationController _stepProgress;

  @override
  void initState() {
    super.initState();
    _stepProgress = AnimationController(
      vsync: this,
      duration: _durations.first,
    );
    _scheduleNext();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stepProgress.dispose();
    super.dispose();
  }

  void _scheduleNext() {
    _timer?.cancel();
    _stepProgress
      ..duration = _durations[_step]
      ..forward(from: 0);
    _timer = Timer(_durations[_step], () {
      if (!mounted) return;
      if (_step == _durations.length - 1) {
        setState(() => _finished = true);
      } else {
        setState(() => _step++);
        _scheduleNext();
      }
    });
  }

  Future<void> _complete() async {
    _timer?.cancel();
    await widget.onComplete();
  }

  Widget _screenForStep(BuildContext context) {
    final challenge = OnboardingDemoData.challenge;
    final detail = OnboardingDemoData.detail(
      milestonesComplete: _step >= 4,
      hasLoggedProgress: _step >= 3,
    );

    if (_step == 0) {
      return const PeopleDiscoverScreen(
        key: ValueKey('discover-demo'),
        onboardingDemo: true,
      );
    }
    if (_step <= 3) {
      final accepted = _step >= 2;
      return ChallengeJourney(
        key: ValueKey('challenge-demo-$_step'),
        challenge: challenge,
        detail: detail,
        participation: accepted ? OnboardingDemoData.participation : null,
        accepting: false,
        onAccept: () {},
        onTrain: () {},
        onLogProgress: _step == 3 ? () {} : null,
        onProve: () async {},
        onOpenMilestone: (_) {},
        onRefresh: () async => detail,
        saved: false,
        challengeSlug: challenge.slug,
        discussionsService: context.read<DiscussionsService>(),
        evidenceService: context.read<EvidenceService>(),
        demoMode: true,
      );
    }
    if (_step == 4) {
      return PathScreen(
        key: const ValueKey('path-demo'),
        challenge: challenge,
        detail: detail,
        initialMilestoneIndex: 2,
        participation: OnboardingDemoData.participation,
      );
    }
    if (_step <= 7) {
      return SubmitEvidenceScreen(
        key: ValueKey('evidence-demo-$_step'),
        participation: OnboardingDemoData.participation,
        challengeTitle: challenge.title,
        verificationType: 'VIDEO',
        instructions: detail.verification.instructions,
        evidenceRules: detail.verification.evidence,
        onboardingDemo: true,
        demoUploading: _step == 6,
        demoSubmitted: _step == 7,
      );
    }
    return DailyQuestRewardScreen(
      key: const ValueKey('aura-demo'),
      result: DailyQuestAttemptResult(
        attemptId: 'onboarding-aura',
        status: 'COMPLETED',
        completionStatus: 'COMPLETED',
        auraAwarded: challenge.auraPoints,
        dayStreak: 1,
        timezone: 'UTC',
        completedAt: DateTime(2026, 11, 26),
      ),
      demoMode: true,
    );
  }

  Alignment? _tapTarget(int step) => switch (step) {
    0 => const Alignment(.78, -.78),
    1 => const Alignment(.82, .76),
    2 => const Alignment(.68, .68),
    3 => const Alignment(.62, .83),
    4 => const Alignment(.65, -.2),
    5 => const Alignment(.75, .48),
    6 => const Alignment(.7, .82),
    7 => const Alignment(-.7, -.45),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ink = HomePalette.textPrimary(brightness);
    final muted = HomePalette.textSecondary(brightness);
    final surface = HomePalette.surface(brightness);
    final border = HomePalette.border(brightness);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'NERD',
                    style: AppFonts.body(
                      color: ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: HomePalette.primary,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text(
                        'MAXXING',
                        style: AppFonts.body(
                          color: HomePalette.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _complete,
                    style: TextButton.styleFrom(foregroundColor: muted),
                    child: const Text('Skip'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var index = 0; index < _durations.length; index++) ...[
                    if (index > 0) const SizedBox(width: 4),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _stepProgress,
                        builder: (context, _) {
                          final progress = index < _step
                              ? 1.0
                              : index == _step
                              ? _stepProgress.value
                              : 0.0;
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: SizedBox(
                              height: 3,
                              child: Stack(
                                children: [
                                  ColoredBox(color: border),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: progress,
                                      child: const ColoredBox(
                                        color: HomePalette.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Column(
                  key: ValueKey(_step),
                  children: [
                    Text(
                      _titles[_step],
                      textAlign: TextAlign.center,
                      style: AppFonts.display(
                        color: ink,
                        fontSize: 23,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _subtitles[_step],
                      textAlign: TextAlign.center,
                      style: AppFonts.body(color: muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(.035, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Container(
                    key: ValueKey('screen-$_step'),
                    decoration: BoxDecoration(
                      color: surface,
                      border: Border.all(color: border),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .08),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(child: _screenForStep(context)),
                        ),
                        if (_tapTarget(_step) case final target?)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedAlign(
                                duration: const Duration(milliseconds: 420),
                                curve: Curves.easeInOutCubic,
                                alignment: target,
                                child: const _TapCue(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_finished)
                FilledButton(
                  onPressed: _complete,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: HomePalette.primary,
                    foregroundColor: HomePalette.ink,
                  ),
                  child: const Text('Get started'),
                )
              else
                Text(
                  '${_step + 1} of ${_durations.length}',
                  textAlign: TextAlign.center,
                  style: AppFonts.body(color: muted, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TapCue extends StatelessWidget {
  const _TapCue();

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: .65, end: 1),
    duration: const Duration(milliseconds: 550),
    curve: Curves.elasticOut,
    builder: (context, scale, child) => Transform.scale(
      scale: scale,
      child: child,
    ),
    child: Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: HomePalette.primary,
        shape: BoxShape.circle,
        border: Border.all(color: HomePalette.ink.withValues(alpha: .14)),
        boxShadow: [
          BoxShadow(
            color: HomePalette.primary.withValues(alpha: .42),
            blurRadius: 18,
            spreadRadius: 3,
          ),
        ],
      ),
      child: const Icon(
        Icons.touch_app_rounded,
        color: HomePalette.ink,
        size: 25,
      ),
    ),
  );
}

                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Column(
                  key: ValueKey(_step),
                  children: [
                    Text(
                      _titles[_step],
                      textAlign: TextAlign.center,
                      style: AppFonts.display(
                        color: ink,
                        fontSize: 23,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _subtitles[_step],
                      textAlign: TextAlign.center,
                      style: AppFonts.body(color: muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(.035, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Container(
                    key: ValueKey('screen-$_step'),
                    decoration: BoxDecoration(
                      color: surface,
                      border: Border.all(color: border),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .08),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: IgnorePointer(child: _screenForStep(context)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_finished)
                FilledButton(
                  onPressed: _complete,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: HomePalette.primary,
                    foregroundColor: HomePalette.ink,
                  ),
                  child: const Text('Get started'),
                )
              else
                Text(
                  '${_step + 1} of ${_durations.length}',
                  textAlign: TextAlign.center,
                  style: AppFonts.body(color: muted, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuraAddedScene extends StatelessWidget {
  const _AuraAddedScene({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ink = HomePalette.textPrimary(brightness);
    final muted = HomePalette.textSecondary(brightness);

    return Scaffold(
      backgroundColor: HomePalette.background(brightness),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: .65, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    width: 94,
                    height: 94,
                    decoration: const BoxDecoration(
                      color: HomePalette.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: HomePalette.ink,
                      size: 52,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'AURA ADDED',
                  style: AppFonts.label(color: muted, fontSize: 13),
                ),
                const SizedBox(height: 4),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 120, end: 160),
                  duration: const Duration(milliseconds: 1800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Text(
                    '$value',
                    style: AppFonts.poster(color: ink, fontSize: 80, wdth: 100),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: HomePalette.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      '+40 AP',
                      style: AppFonts.body(
                        color: HomePalette.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Challenge complete',
                  style: AppFonts.body(
                    color: ink,
                    fontSize: 16,
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
}