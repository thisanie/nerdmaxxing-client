import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../services/challenges_service.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  static const _durations = [
    Duration(milliseconds: 4600),
    Duration(milliseconds: 5000),
    Duration(milliseconds: 5800),
    Duration(milliseconds: 5000),
    Duration(milliseconds: 4400),
  ];
  static const _captions = [
    'Find a challenge and choose it',
    'Accept it and track your progress',
    'Log results and complete milestones',
    'Submit a video as proof',
    'Earn Aura and rank up',
  ];

  int _step = 0;
  bool _finished = false;
  Timer? _timer;
  late final AnimationController _progress;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this);
    _prefetchSuggestedChallenge();
    _startScene();
  }

  Future<void> _prefetchSuggestedChallenge() async {
    try {
      final challenge = await context
          .read<ChallengesService>()
          .getSuggestedOrigamiChallenge();
      final imageUrl = challenge?.imageUrl;
      if (!mounted || imageUrl == null || imageUrl.isEmpty) return;
      await precacheImage(NetworkImage(imageUrl), context);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progress.dispose();
    super.dispose();
  }

  void _startScene() {
    _timer?.cancel();
    _progress
      ..duration = _durations[_step]
      ..forward(from: 0);
    _timer = Timer(_durations[_step], () {
      if (!mounted) return;
      if (_step == _durations.length - 1) {
        setState(() => _finished = true);
      } else {
        setState(() => _step++);
        _startScene();
      }
    });
  }

  void _next() {
    if (_step >= _durations.length - 1) {
      _timer?.cancel();
      _progress.value = 1;
      setState(() => _finished = true);
      return;
    }
    setState(() => _step++);
    _startScene();
  }

  Future<void> _complete() async {
    _timer?.cancel();
    _progress.stop();
    await widget.onComplete();
  }

  void _replay() {
    setState(() {
      _step = 0;
      _finished = false;
    });
    _startScene();
  }

  Widget _scene(_Pal pal, double t) => switch (_step) {
    0 => _SearchScene(pal: pal, t: t),
    1 => _ProgressScene(pal: pal, t: t),
    2 => _MilestoneScene(pal: pal, t: t),
    3 => _ProofScene(pal: pal, t: t),
    _ => _AuraScene(pal: pal, t: t),
  };

  @override
  Widget build(BuildContext context) {
    final pal = _Pal.of(context);

    return Scaffold(
      backgroundColor: pal.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'NERD',
                        style: AppFonts.body(
                          color: pal.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: HomePalette.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          child: Text(
                            'MAXXING',
                            style: AppFonts.body(
                              color: HomePalette.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _complete,
                        style: TextButton.styleFrom(
                          foregroundColor: pal.muted,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _StepBar(
                    count: _durations.length,
                    step: _step,
                    animation: _progress,
                    track: pal.line,
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: pal.surface,
                        border: Border.all(color: pal.line),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(31),
                        child: AnimatedBuilder(
                          animation: _progress,
                          builder: (context, _) => AnimatedSwitcher(
                            duration: const Duration(milliseconds: 420),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(.06, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: KeyedSubtree(
                              key: ValueKey(_step),
                              child: _scene(pal, _progress.value),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _captions[_step],
                      key: ValueKey(_step),
                      textAlign: TextAlign.center,
                      style: AppFonts.body(
                        color: pal.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 56,
                    child: _finished
                        ? Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _replay,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: pal.ink,
                                    side: BorderSide(color: pal.line),
                                    shape: const StadiumBorder(),
                                    textStyle: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  child: const Text('Replay'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton(
                                  onPressed: _complete,
                                  style: _ctaStyle(),
                                  child: const Text('Get started'),
                                ),
                              ),
                            ],
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _next,
                              style: _ctaStyle(),
                              child: const Text('Next'),
                            ),
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

  ButtonStyle _ctaStyle() => FilledButton.styleFrom(
    backgroundColor: HomePalette.primary,
    foregroundColor: HomePalette.ink,
    shape: const StadiumBorder(),
    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
  );
}

class _Pal {
  final bool dark;
  const _Pal(this.dark);

  factory _Pal.of(BuildContext context) =>
      _Pal(Theme.of(context).brightness == Brightness.dark);

  Brightness get _b => dark ? Brightness.dark : Brightness.light;
  Color get bg => HomePalette.background(_b);
  Color get surface => dark ? HomePalette.darkSurface : Colors.white;
  Color get alt => dark ? HomePalette.darkSurfaceAlt : const Color(0xFFF6F6F1);
  Color get ink => dark ? HomePalette.darkTextPrimary : const Color(0xFF11110D);
  Color get muted =>
      dark ? HomePalette.darkTextSecondary : const Color(0xFF6B6B63);
  Color get line => HomePalette.border(_b);
  Color get wash =>
      dark ? HomePalette.darkPrimaryMuted : const Color(0xFFEEFAB9);
  Color get tagText => dark ? HomePalette.primary : const Color(0xFF49620F);
  Color get ok => dark ? HomePalette.primary : const Color(0xFF4A7A10);
  Color get barIdle =>
      dark ? HomePalette.darkBorderStrong : const Color(0xFFD1D0C4);
}

const _heroGradient = LinearGradient(
  colors: [Color(0xFFCDFD4A), Color(0xFF9FF1C0)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

double _seg(double t, double from, double to) =>
    ((t - from) / (to - from)).clamp(0.0, 1.0).toDouble();

class _StepBar extends StatelessWidget {
  final int count;
  final int step;
  final Animation<double> animation;
  final Color track;

  const _StepBar({
    required this.count,
    required this.step,
    required this.animation,
    required this.track,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < count; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final v = i < step ? 1.0 : (i == step ? animation.value : 0.0);
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      ColoredBox(color: track, child: const SizedBox.expand()),
                      FractionallySizedBox(
                        widthFactor: v,
                        child: const ColoredBox(
                          color: HomePalette.primary,
                          child: SizedBox.expand(),
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
    ],
  );
}

class _Label extends StatelessWidget {
  final _Pal pal;
  final String text;
  final Color? color;

  const _Label(this.pal, this.text, {this.color});

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: AppFonts.label(color: color ?? pal.muted, fontSize: 12),
  );
}

class _Tag extends StatelessWidget {
  final _Pal pal;
  final String label;
  final bool pale;

  const _Tag(this.pal, this.label, {required this.pale});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: pale ? pal.wash : pal.alt,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        label,
        style: AppFonts.body(
          color: pale ? pal.tagText : pal.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _SceneBar extends StatelessWidget {
  final _Pal pal;
  final String title;

  const _SceneBar(this.pal, this.title);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.arrow_back_rounded, color: pal.muted, size: 24),
      Expanded(
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: AppFonts.body(
            color: pal.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 24),
    ],
  );
}

class _Track extends StatelessWidget {
  final double value;

  const _Track(this.value);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = c.maxWidth * value.clamp(0.0, 1.0);
      return SizedBox(
        height: 20,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: HomePalette.ink.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            Container(
              width: w,
              height: 10,
              decoration: BoxDecoration(
                color: HomePalette.ink,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            Positioned(
              left: (w - 10).clamp(0.0, c.maxWidth - 20).toDouble(),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: HomePalette.ink,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ResultCard extends StatelessWidget {
  final _Pal pal;
  final String title;
  final String tag;
  final IconData icon;
  final bool selected;

  const _ResultCard({
    required this.pal,
    required this.title,
    required this.tag,
    required this.icon,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 350),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: selected ? pal.wash : pal.surface,
      border: Border.all(
        color: selected ? HomePalette.primary : pal.line,
        width: selected ? 2 : 1,
      ),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: _heroGradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: HomePalette.ink, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.body(
                  color: pal.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  _Tag(pal, 'Beginner', pale: true),
                  _Tag(pal, selected ? 'Accepted' : tag, pale: false),
                ],
              ),
            ],
          ),
        ),
        Icon(
          selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
          color: selected ? pal.ok : pal.muted,
          size: 28,
        ),
      ],
    ),
  );
}

class _SearchScene extends StatelessWidget {
  final _Pal pal;
  final double t;

  const _SearchScene({required this.pal, required this.t});

  @override
  Widget build(BuildContext context) {
    const query = 'plank';
    final typed = (_seg(t, .04, .42) * query.length).round();
    final show = Curves.easeOut.transform(_seg(t, .42, .56));
    final selected = t > .8;

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find your next\nchallenge',
            style: AppFonts.display(color: pal.ink, fontSize: 34, height: 1.05),
          ),
          const SizedBox(height: 20),
          Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: pal.alt,
              border: Border.all(
                color: typed > 0 && typed < query.length
                    ? HomePalette.primary
                    : pal.line,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: pal.muted, size: 24),
                const SizedBox(width: 10),
                Text(
                  query.substring(0, typed),
                  style: AppFonts.body(color: pal.ink, fontSize: 18),
                ),
                if (typed < query.length)
                  Container(
                    width: 2,
                    height: 22,
                    margin: const EdgeInsets.only(left: 2),
                    color: HomePalette.primary,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Label(pal, 'Challenge results'),
          const SizedBox(height: 12),
          Opacity(
            opacity: show,
            child: Transform.translate(
              offset: Offset(0, (1 - show) * 16),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 320),
                scale: selected ? 1.02 : 1,
                child: _ResultCard(
                  pal: pal,
                  title: 'Hold a Plank for 3 Minutes',
                  tag: '32 Aura',
                  icon: Icons.fitness_center_rounded,
                  selected: selected,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 350),
            opacity: show * (selected ? .35 : 1),
            child: _ResultCard(
              pal: pal,
              title: 'Side Plank Hold Challenge',
              tag: '24 Aura',
              icon: Icons.self_improvement_rounded,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _ProgressScene extends StatelessWidget {
  final _Pal pal;
  final double t;

  const _ProgressScene({required this.pal, required this.t});

  static const _attempts = [7, 8, 10, 10, 11];

  @override
  Widget build(BuildContext context) {
    final value =
        3 + (8 * Curves.easeOutCubic.transform(_seg(t, .05, .85))).round();

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SceneBar(pal, 'Advanced  |  Accepted'),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: _heroGradient,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Label(pal, 'You are here', color: HomePalette.ink),
                    const Spacer(),
                    _Tag(pal, '+${value - 3} since start', pale: false),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$value',
                      style:
                          AppFonts.poster(
                            color: HomePalette.ink,
                            fontSize: 76,
                            wdth: 100,
                          ).copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'seconds',
                      style: AppFonts.body(
                        color: const Color(0xFF3B5A10),
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Freestanding hold',
                  style: AppFonts.body(
                    color: HomePalette.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Best so far. Target is 30.',
                  style: AppFonts.body(
                    color: HomePalette.ink.withValues(alpha: .75),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                _Track((value - 3) / 27),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '3 sec',
                      style: AppFonts.body(
                        color: HomePalette.ink,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '30 sec',
                      style: AppFonts.body(
                        color: HomePalette.ink,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your attempts',
                  style: AppFonts.body(
                    color: pal.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '5 logged',
                style: AppFonts.body(color: pal.muted, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                color: pal.alt,
                border: Border.all(color: pal.line),
                borderRadius: BorderRadius.circular(22),
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  const labelSpace = 30.0;
                  final maxBar = (c.maxHeight - labelSpace).clamp(20.0, 600.0);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < _attempts.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: _bar(
                            _attempts[i],
                            maxBar,
                            Curves.easeOutBack.transform(
                              _seg(t, .08 + i * .12, .3 + i * .12),
                            ),
                            i == _attempts.length - 1,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(int value, double maxBar, double reveal, bool highlight) =>
      Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Opacity(
            opacity: reveal > .6 ? 1 : 0,
            child: Text(
              '$value',
              style: AppFonts.body(
                color: highlight ? pal.ink : pal.muted,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: (value / 11 * maxBar * reveal).clamp(0.0, maxBar * 1.1),
            decoration: BoxDecoration(
              color: highlight ? HomePalette.primary : pal.barIdle,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
          ),
        ],
      );
}

class _MilestoneScene extends StatelessWidget {
  final _Pal pal;
  final double t;

  const _MilestoneScene({required this.pal, required this.t});

  static const _titles = [
    "Complete Beginner's Guide",
    'Wrist Strength & Mobility',
    'Warm-Up Routine',
  ];

  @override
  Widget build(BuildContext context) {
    final done = (_seg(t, .1, .75) * _titles.length).floor().clamp(0, 3);
    final unlocked = t > .82;

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SceneBar(pal, 'The Grind  |  Milestone 01'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: _heroGradient,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label(pal, 'You are here', color: HomePalette.ink),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$done',
                      style: AppFonts.poster(
                        color: HomePalette.ink,
                        fontSize: 52,
                        wdth: 100,
                      ),
                    ),
                    Text(
                      ' / 3 done',
                      style: AppFonts.body(
                        color: const Color(0xFF3B5A10),
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    unlocked ? 'Next milestone unlocked!' : 'Prepare Your Body',
                    key: ValueKey(unlocked),
                    style: AppFonts.body(
                      color: HomePalette.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          height: 8,
                          decoration: BoxDecoration(
                            color: i < done
                                ? HomePalette.ink
                                : HomePalette.ink.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < _titles.length; i++)
                  Expanded(child: _row(i, i < done)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(int i, bool done) => AnimatedContainer(
    duration: const Duration(milliseconds: 320),
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: done ? pal.wash : pal.surface,
      border: Border.all(
        color: done ? HomePalette.primary.withValues(alpha: .6) : pal.line,
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: done ? HomePalette.primary : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: done ? pal.ok : pal.muted, width: 1.6),
          ),
          child: done
              ? const Icon(Icons.check_rounded, color: HomePalette.ink, size: 20)
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label(pal, '0${i + 1} / ${i == 0 ? 'Article' : 'Video'}'),
              const SizedBox(height: 4),
              Text(
                _titles[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.body(
                  color: pal.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ).copyWith(
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProofScene extends StatelessWidget {
  final _Pal pal;
  final double t;

  const _ProofScene({required this.pal, required this.t});

  @override
  Widget build(BuildContext context) {
    final picked = t > .2;
    final upload = Curves.easeInOut.transform(_seg(t, .24, .75));
    final submitted = t > .88;

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SceneBar(pal, 'Submit Evidence'),
          const SizedBox(height: 24),
          Text(
            'Submit video proof',
            style: AppFonts.display(color: pal.ink, fontSize: 32, height: 1.05),
          ),
          const SizedBox(height: 10),
          Text(
            'Record your freestanding hold and upload it so it can be verified.',
            style: AppFonts.body(color: pal.muted, fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 24),
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: picked ? pal.wash : pal.alt,
              border: Border.all(
                color: picked ? HomePalette.primary : pal.line,
                width: picked ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  picked
                      ? Icons.check_circle_rounded
                      : Icons.video_library_outlined,
                  color: picked ? pal.ok : pal.ink,
                  size: 40,
                ),
                const SizedBox(height: 10),
                Text(
                  picked ? 'Video selected' : 'Tap to upload a video',
                  style: AppFonts.body(
                    color: pal.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'MP4 or MOV  |  up to 60 s',
                  style: AppFonts.body(color: pal.muted, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: picked ? 1 : 0,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pal.surface,
                border: Border.all(color: pal.line),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: HomePalette.ink,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'freestanding_hold.mp4',
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.body(
                            color: pal.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${(upload * 100).round()}%  |  12.4 MB',
                          style: AppFonts.body(color: pal.muted, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: upload,
                            minHeight: 8,
                            backgroundColor: pal.line,
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFF8FD01C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (submitted)
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: pal.ok,
                        size: 28,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Spacer(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            height: 54,
            decoration: ShapeDecoration(
              color: HomePalette.ink.withValues(alpha: submitted ? 1 : .35),
              shape: const StadiumBorder(),
            ),
            child: Center(
              child: Text(
                submitted ? 'Proof submitted' : 'Submit proof',
                style: AppFonts.body(
                  color: HomePalette.primary.withValues(
                    alpha: submitted ? 1 : .6,
                  ),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuraScene extends StatelessWidget {
  final _Pal pal;
  final double t;

  const _AuraScene({required this.pal, required this.t});

  @override
  Widget build(BuildContext context) {
    final count = Curves.easeOutCubic.transform(_seg(t, .15, .8));
    final aura = 94 + (32 * count).round();
    final rankedUp = aura >= 100;
    final badge = Curves.easeOutBack.transform(_seg(t, .08, .28));
    final pulse = rankedUp ? 1 + .05 * (1 - _seg(t, .45, .6)) : 1.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: pal.dark
              ? const [Color(0xFF252B16), HomePalette.darkSurface]
              : const [Color(0xFFF3FFD0), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Label(pal, 'Challenge complete'),
            const SizedBox(height: 8),
            Text(
              'Hold a Plank for 3 Minutes',
              textAlign: TextAlign.center,
              style: AppFonts.body(
                color: pal.ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 32),
            Transform.scale(
              scale: pulse,
              child: Text(
                '$aura',
                style:
                    AppFonts.poster(
                      color: pal.ink,
                      fontSize: 120,
                      wdth: 100,
                    ).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ),
            _Label(pal, 'Aura points'),
            const SizedBox(height: 20),
            Transform.scale(
              scale: badge.clamp(0.0, 1.3),
              child: Opacity(
                opacity: _seg(t, .08, .2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: HomePalette.ink,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Text(
                      '+32 aura',
                      style: AppFonts.body(
                        color: HomePalette.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            AnimatedContainer(
              duration: const Duration(milliseconds: 380),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: HomePalette.ink,
                borderRadius: BorderRadius.circular(30),
                boxShadow: rankedUp
                    ? [
                        BoxShadow(
                          color: HomePalette.primary.withValues(alpha: .4),
                          blurRadius: 24,
                          spreadRadius: 3,
                        ),
                      ]
                    : const [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: HomePalette.primary,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    rankedUp ? 'Rank D' : 'Rank E',
                    style: AppFonts.body(
                      color: HomePalette.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              rankedUp ? 'Rank D unlocked' : '${100 - aura} AP to Rank D',
              style: AppFonts.body(color: pal.muted, fontSize: 15),
            ),
            const SizedBox(height: 16),
            _Track(((aura - 94) / 6).clamp(0.0, 1.0)),
          ],
        ),
      ),
    );
  }
}
