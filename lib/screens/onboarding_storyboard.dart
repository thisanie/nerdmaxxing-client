import 'dart:async';

import 'package:flutter/material.dart';

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
    Duration(milliseconds: 4300),
    Duration(milliseconds: 4700),
    Duration(milliseconds: 5700),
    Duration(milliseconds: 4700),
    Duration(milliseconds: 5700),
  ];
  static const _captions = [
    'Find a challenge and choose it',
    'Accept it and track your progress',
    'Log a result and complete milestones',
    'Submit a video as proof',
    'Earn Aura and rank up',
  ];
  static const _milestoneTitles = [
    "Complete Beginner's Guide",
    'Wrist Strength & Mobility',
    'Warm-Up Routine',
  ];

  int _step = 0;
  bool _finished = false;
  Timer? _timer;
  late final AnimationController _progress;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _ink =>
      _dark ? HomePalette.darkTextPrimary : const Color(0xFF11110D);
  Color get _muted =>
      _dark ? HomePalette.darkTextSecondary : const Color(0xFF6B6B63);
  Color get _paper => _dark ? HomePalette.darkBackground : Colors.white;
  Color get _line => HomePalette.border(Theme.of(context).brightness);

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: _durations.first);
    _startScene();
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

  Widget _brand() => Row(
    children: [
      Text(
        'NERD',
        style: AppFonts.body(
          color: _ink,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(width: 4),
      DecoratedBox(
        decoration: BoxDecoration(
          color: HomePalette.primary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            'MAXXING',
            style: AppFonts.body(
              color: HomePalette.ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      const Spacer(),
      Icon(Icons.notifications_none_rounded, color: _muted, size: 20),
    ],
  );

  Widget _label(String text) => Text(
    text.toUpperCase(),
    style: AppFonts.label(color: _muted, fontSize: 9),
  );

  Widget _sceneHeading(String title, {String? trailing}) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: AppFonts.body(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      if (trailing != null)
        Text(trailing, style: AppFonts.body(color: _muted, fontSize: 10)),
    ],
  );

  Widget _searchScene(double progress) {
    const query = 'plank';
    final visibleCharacters = (progress * 2 * query.length)
        .floor()
        .clamp(0, query.length)
        .toInt();
    final resultVisible = progress > .42;
    final selected = progress > .8;
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 8, 15, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _brand(),
          const SizedBox(height: 17),
          Text(
            'Find your next\nchallenge',
            style: AppFonts.display(color: _ink, fontSize: 23, height: 1.08),
          ),
          const SizedBox(height: 13),
          Container(
            height: 43,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _dark
                  ? HomePalette.darkSurfaceAlt
                  : const Color(0xFFF6F6F1),
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: _muted, size: 18),
                const SizedBox(width: 8),
                Text(
                  query.substring(0, visibleCharacters),
                  style: AppFonts.body(color: _ink, fontSize: 13),
                ),
                if (visibleCharacters < query.length)
                  Container(
                    width: 1.5,
                    height: 16,
                    margin: const EdgeInsets.only(left: 2),
                    color: HomePalette.primary,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 17),
          _label('Challenge results'),
          const SizedBox(height: 8),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 350),
            opacity: resultVisible ? 1 : 0,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 320),
              scale: selected ? .975 : 1,
              child: _challengeCard(selected: selected),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _challengeCard({required bool selected}) => AnimatedContainer(
    duration: const Duration(milliseconds: 350),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: selected
          ? (_dark ? HomePalette.darkPrimaryMuted : const Color(0xFFEEFAB9))
          : _paper,
      border: Border.all(
        color: selected ? HomePalette.primary : _line,
        width: selected ? 1.5 : 1,
      ),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFCDFD4A), Color(0xFF9FF1C0)],
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.fitness_center_rounded,
            color: HomePalette.ink,
            size: 23,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hold a Plank for 3 Minutes',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.body(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 5,
                children: [
                  _smallTag('Beginner', pale: true),
                  _smallTag(selected ? 'Accepted' : '32 Aura', pale: false),
                ],
              ),
            ],
          ),
        ),
        Icon(
          selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
          color: selected ? const Color(0xFF4A7A10) : _muted,
          size: 21,
        ),
      ],
    ),
  );

  Widget _smallTag(String label, {required bool pale}) => DecoratedBox(
    decoration: BoxDecoration(
      color: pale
          ? (_dark ? HomePalette.darkPrimaryMuted : const Color(0xFFEEFAB9))
          : (_dark ? HomePalette.darkSurfaceAlt : const Color(0xFFEFEFE8)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: Text(
        label,
        style: AppFonts.body(
          color: pale ? const Color(0xFF49620F) : _muted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  Widget _progressScene(double progress) {
    final value = 3 + (8 * progress).round();
    const heights = [7, 8, 10, 10, 11];
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.arrow_back_rounded, color: _muted, size: 18),
              const Spacer(),
              Text(
                'Advanced  |  ',
                style: AppFonts.body(color: _muted, fontSize: 10),
              ),
              Text(
                'Accepted',
                style: AppFonts.body(
                  color: _ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(Icons.more_vert_rounded, color: _muted, size: 18),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFCDFD4A), Color(0xFF9FF1C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: Color(0xFF0B0C05)),
                    const SizedBox(width: 7),
                    _label('You are here'),
                    const Spacer(),
                    _smallTag('+${value - 3} since start', pale: false),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$value',
                      style: AppFonts.poster(
                        color: HomePalette.ink,
                        fontSize: 54,
                        wdth: 100,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'seconds',
                      style: AppFonts.body(
                        color: const Color(0xFF3B5A10),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Freestanding hold',
                  style: AppFonts.body(
                    color: HomePalette.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Best so far. Target is 30.',
                  style: AppFonts.body(
                    color: HomePalette.ink.withValues(alpha: .75),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 12),
                _track((value - 3) / 27),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '3 sec',
                      style: AppFonts.body(color: HomePalette.ink, fontSize: 9),
                    ),
                    Text(
                      '30 sec',
                      style: AppFonts.body(color: HomePalette.ink, fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sceneHeading('Your attempts', trailing: '5 logged'),
          const SizedBox(height: 7),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(9, 12, 9, 7),
              decoration: BoxDecoration(
                color: _paper,
                border: Border.all(color: _line),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var index = 0; index < heights.length; index++)
                    _attemptBar(
                      heights[index],
                      progress,
                      index == heights.length - 1,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _track(double value) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final progressWidth = width * value.clamp(0.0, 1.0).toDouble();
      return SizedBox(
        height: 15,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 7,
              decoration: BoxDecoration(
                color: HomePalette.ink.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            Container(
              width: progressWidth,
              height: 7,
              decoration: BoxDecoration(
                color: HomePalette.ink,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            Positioned(
              left: progressWidth.clamp(0.0, width - 12).toDouble(),
              child: Container(
                width: 13,
                height: 13,
                decoration: const BoxDecoration(
                  color: HomePalette.ink,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _attemptBar(int height, double progress, bool highlighted) {
    final reveal = ((progress - .08) / .72).clamp(0.0, 1.0);
    final currentHeight = height * 6.0 * reveal;
    return SizedBox(
      width: 27,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Opacity(
            opacity: reveal > .6 ? 1 : 0,
            child: Text(
              '$height',
              style: AppFonts.body(color: _muted, fontSize: 9),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 27,
            height: currentHeight,
            decoration: BoxDecoration(
              color: highlighted
                  ? HomePalette.primary
                  : (_dark
                        ? HomePalette.darkBorderStrong
                        : const Color(0xFFD1D0C4)),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _milestoneScene(double progress) {
    final doneCount = ((progress - .08) / .67 * _milestoneTitles.length)
        .floor()
        .clamp(0, _milestoneTitles.length)
        .toInt();
    final unlocked = progress > .82;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.arrow_back_rounded, color: _muted, size: 18),
              const Spacer(),
              Text(
                'The Grind  |  Milestone 01',
                style: AppFonts.body(
                  color: _ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(Icons.more_vert_rounded, color: _muted, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFCDFD4A), Color(0xFF9FF1C0)],
              ),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('You are here'),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$doneCount',
                      style: AppFonts.poster(
                        color: HomePalette.ink,
                        fontSize: 43,
                        wdth: 100,
                      ),
                    ),
                    Text(
                      ' / 3 done',
                      style: AppFonts.body(
                        color: const Color(0xFF3B5A10),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Prepare Your Body',
                  style: AppFonts.body(
                    color: HomePalette.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    for (var index = 0; index < 3; index++) ...[
                      if (index > 0) const SizedBox(width: 5),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          height: 5,
                          decoration: BoxDecoration(
                            color: index < doneCount
                                ? HomePalette.ink
                                : HomePalette.ink.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 9),
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: FilledButton(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      backgroundColor: HomePalette.ink,
                      foregroundColor: HomePalette.primary,
                      disabledBackgroundColor: HomePalette.ink,
                      disabledForegroundColor: HomePalette.primary,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      progress < .2 ? 'Log a result' : 'Result logged',
                      style: AppFonts.body(
                        color: HomePalette.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Expanded(
            child: Column(
              children: [
                for (var index = 0; index < _milestoneTitles.length; index++)
                  Expanded(
                    child: _checklistRow(index, done: index < doneCount),
                  ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 420),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: unlocked ? const Color(0xFFEEFAB9) : Colors.transparent,
              border: Border.all(
                color: unlocked ? HomePalette.primary : _line,
                style: unlocked ? BorderStyle.solid : BorderStyle.none,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  unlocked
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                  size: 17,
                  color: unlocked ? const Color(0xFF49620F) : _muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    unlocked
                        ? 'Milestone complete. Next one unlocked!'
                        : 'Finish the checklist to unlock the next milestone.',
                    style: AppFonts.body(
                      color: unlocked ? const Color(0xFF2C4A05) : _muted,
                      fontSize: 10,
                      fontWeight: unlocked ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _checklistRow(int index, {required bool done}) => AnimatedContainer(
    duration: const Duration(milliseconds: 320),
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: done
          ? (_dark ? HomePalette.darkPrimaryMuted : const Color(0xFFFBFFF0))
          : _paper,
      border: Border.all(
        color: done ? HomePalette.primary.withValues(alpha: .55) : _line,
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          width: 21,
          height: 21,
          decoration: BoxDecoration(
            color: done ? HomePalette.primary : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: done ? const Color(0xFF4A7A10) : _muted,
              width: 1.3,
            ),
          ),
          child: done
              ? const Icon(
                  Icons.check_rounded,
                  color: HomePalette.ink,
                  size: 14,
                )
              : null,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '0${index + 1} / ${index == 0 ? 'ARTICLE' : 'VIDEO'}',
                style: AppFonts.label(color: _muted, fontSize: 8),
              ),
              const SizedBox(height: 2),
              Text(
                _milestoneTitles[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    AppFonts.body(
                      color: _ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ).copyWith(
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
              ),
              Text(
                index == 0
                    ? 'Starter guide with full progression.'
                    : 'A step-by-step practice guide.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.body(color: _muted, fontSize: 8),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _proofScene(double progress) {
    final fileVisible = progress > .22;
    final uploaded = ((progress - .24) / .45).clamp(0.0, 1.0).toDouble();
    final submitted = progress > .88;
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.arrow_back_rounded, color: _muted, size: 18),
              const Spacer(),
              Text(
                'Submit Evidence',
                style: AppFonts.body(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 18),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Submit video proof',
            style: AppFonts.display(color: _ink, fontSize: 22, height: 1.08),
          ),
          const SizedBox(height: 6),
          Text(
            'Record your freestanding hold and upload it so it can be verified.',
            style: AppFonts.body(color: _muted, fontSize: 11, height: 1.35),
          ),
          const SizedBox(height: 15),
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            height: 112,
            decoration: BoxDecoration(
              color: progress > .1
                  ? const Color(0xFFEEFAB9)
                  : (_dark
                        ? HomePalette.darkSurfaceAlt
                        : const Color(0xFFF8F8F3)),
              border: Border.all(
                color: progress > .1 ? const Color(0xFF6AA00F) : _line,
                width: progress > .1 ? 1.5 : 1,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_library_outlined, color: _ink, size: 25),
                const SizedBox(height: 6),
                Text(
                  fileVisible ? 'Video selected' : 'Tap to upload a video',
                  style: AppFonts.body(
                    color: _ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'MP4 or MOV  |  up to 60 s',
                  style: AppFonts.body(color: _muted, fontSize: 9),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: fileVisible ? 1 : 0,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _paper,
                border: Border.all(color: _line),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: HomePalette.ink,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'freestanding_hold.mp4',
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.body(
                            color: _ink,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${(uploaded * 100).round()}%  |  12.4 MB',
                          style: AppFonts.body(color: _muted, fontSize: 9),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: uploaded,
                            minHeight: 5,
                            backgroundColor: _line,
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFF8FD01C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (submitted)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF4A7A10),
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                backgroundColor: HomePalette.ink,
                foregroundColor: HomePalette.primary,
                disabledBackgroundColor: submitted
                    ? HomePalette.ink
                    : HomePalette.ink.withValues(alpha: .35),
                disabledForegroundColor: submitted
                    ? HomePalette.primary
                    : HomePalette.primary.withValues(alpha: .55),
                shape: const StadiumBorder(),
              ),
              child: Text(
                submitted ? 'Proof submitted' : 'Submit proof',
                style: AppFonts.body(
                  color: submitted
                      ? HomePalette.primary
                      : HomePalette.primary.withValues(alpha: .65),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _auraScene(double progress) {
    final aura = 94 + (32 * progress).round();
    final rankedUp = aura >= 100;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _dark
              ? const [Color(0xFF252B16), HomePalette.darkBackground]
              : const [Color(0xFFF3FFD0), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _label('Challenge complete'),
            const SizedBox(height: 5),
            Text(
              'Hold a Plank for 3 Minutes',
              textAlign: TextAlign.center,
              style: AppFonts.body(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              '$aura',
              style: AppFonts.poster(color: _ink, fontSize: 75, wdth: 100),
            ),
            _label('Aura points'),
            const SizedBox(height: 14),
            AnimatedScale(
              duration: const Duration(milliseconds: 360),
              scale: progress > .06 ? 1 : .7,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: progress > .06 ? 1 : 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: HomePalette.ink,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 8,
                    ),
                    child: Text(
                      '+32 aura',
                      style: AppFonts.body(
                        color: HomePalette.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            AnimatedContainer(
              duration: const Duration(milliseconds: 380),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                color: HomePalette.ink,
                borderRadius: BorderRadius.circular(22),
                boxShadow: rankedUp
                    ? [
                        BoxShadow(
                          color: HomePalette.primary.withValues(alpha: .35),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : const [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    color: HomePalette.primary,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    rankedUp ? 'Rank D' : 'Rank E',
                    style: AppFonts.body(
                      color: HomePalette.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              rankedUp ? 'Rank D unlocked' : '6 AP to Rank D',
              style: AppFonts.body(color: _muted, fontSize: 10),
            ),
            const SizedBox(height: 10),
            _track(((aura - 94) / 6).clamp(0.0, 1.0).toDouble()),
          ],
        ),
      ),
    );
  }

  Widget _scene(double progress) => switch (_step) {
    0 => _searchScene(progress),
    1 => _progressScene(progress),
    2 => _milestoneScene(progress),
    3 => _proofScene(progress),
    _ => _auraScene(progress),
  };

  Widget _progressIndicators(Color border) {
    final segments = <Widget>[];
    for (var index = 0; index < _durations.length; index++) {
      if (index > 0) segments.add(const SizedBox(width: 5));
      segments.add(
        Expanded(
          child: AnimatedBuilder(
            animation: _progress,
            builder: (context, _) {
              final value = index < _step
                  ? 1.0
                  : index == _step
                  ? _progress.value
                  : 0.0;
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 4,
                  child: Stack(
                    children: [
                      Container(color: border),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: value,
                          child: const ColoredBox(
                            color: HomePalette.primary,
                            child: SizedBox.expand(),
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
      );
    }
    return Row(children: segments);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = HomePalette.background(brightness);
    final foreground = HomePalette.textPrimary(brightness);
    final muted = HomePalette.textSecondary(brightness);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 5, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'NERDMAXXING',
                    style: AppFonts.body(
                      color: foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
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
              const SizedBox(height: 4),
              _progressIndicators(HomePalette.border(brightness)),
              const SizedBox(height: 11),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: SizedBox.expand(
                      child: AnimatedBuilder(
                        animation: _progress,
                        builder: (context, _) => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 360),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(.045, .02),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: KeyedSubtree(
                            key: ValueKey(_step),
                            child: _scene(_progress.value),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  _captions[_step],
                  key: ValueKey(_step),
                  textAlign: TextAlign.center,
                  style: AppFonts.body(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < _durations.length; index++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: index == _step ? 22 : 7,
                      height: 5,
                      decoration: BoxDecoration(
                        color: foreground.withValues(
                          alpha: index == _step ? .85 : .2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_finished)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _replay,
                        child: const Text('Replay'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _complete,
                        style: FilledButton.styleFrom(
                          backgroundColor: HomePalette.primary,
                          foregroundColor: HomePalette.ink,
                        ),
                        child: const Text('Get started'),
                      ),
                    ),
                  ],
                ),
              if (!_finished)
                Text(
                  '${_step + 1} / ${_durations.length}',
                  style: AppFonts.body(color: muted, fontSize: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
