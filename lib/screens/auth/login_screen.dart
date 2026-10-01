import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/google_auth_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLight = Theme.of(context).brightness == Brightness.light;
    final background = isLight ? AppColors.lightBackground : AppColors.background;
    final textColor = isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
    final mutedColor = isLight ? AppColors.lightTextSecondary : AppColors.textSecondary;
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;
            return Stack(
              children: [
                AnimatedBuilder(
                  animation: _motion,
                  builder: (context, child) {
                    final t = (math.sin(_motion.value * math.pi * 2) + 1) / 2;
                    return Positioned(
                      left: -120 + t * 28,
                      top: constraints.maxHeight * .28 - t * 20,
                      child: child!,
                    );
                  },
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isLight
                          ? const Color(0xFFEBF3CC)
                          : AppColors.primaryMuted,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: .12),
                          blurRadius: 42,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    compact ? 84 : 180,
                    24,
                    32,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (compact ? 116 : 212),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            _Entrance(
                              delay: .05,
                              child: _SparkMark(controller: _motion),
                            ),
                            SizedBox(height: compact ? 26 : 40),
                            _Entrance(
                              delay: .22,
                              child: _Brand(
                                textColor: textColor,
                                controller: _motion,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _Entrance(
                              delay: .38,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 310),
                                child: Text(
                                  'The internet should make you more interesting,\nnot more addicted.',
                                  textAlign: TextAlign.center,
                                  style: AppFonts.body(
                                    color: mutedColor,
                                    fontSize: 18,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        _Entrance(
                          delay: .42,
                          child: RepaintBoundary(
                            child: Column(
                              children: [
                                if (auth.errorMessage != null) ...[
                                  Text(
                                    auth.errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: AppFonts.body(
                                      color: AppColors.danger,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                _AnimatedCta(
                                  controller: _motion,
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 64,
                                    child: buildGoogleAuthButton(
                                      isBusy: auth.isBusy,
                                      onPressed: () => context
                                          .read<AuthProvider>()
                                          .signInWithGoogle(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Entrance extends StatelessWidget {
  final double delay;
  final Widget child;

  const _Entrance({required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 850),
      curve: Interval(delay, 1, curve: Curves.easeOutCubic),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _SparkMark extends StatelessWidget {
  final Animation<double> controller;

  const _SparkMark({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final pulse = (math.sin(controller.value * math.pi * 2) + 1) / 2;
        final twinkle = (math.sin(controller.value * math.pi * 4) + 1) / 2;
        return Transform.scale(
          scale: .94 + pulse * .08,
          child: CustomPaint(
            size: const Size(92, 92),
            painter: _SparkPainter(
              topOpacity: .25 + twinkle * .75,
              bottomOpacity: 1 - twinkle * .65,
            ),
          ),
        );
      },
      child: const SizedBox(width: 92, height: 92),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final double topOpacity;
  final double bottomOpacity;

  const _SparkPainter({this.topOpacity = 1, this.bottomOpacity = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 92;
    canvas.save();
    canvas.scale(scale);

    final lime = Paint()..color = AppColors.primary;
    final ink = Paint()..color = AppColors.ink;
    final outline = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    final main = Path()
      ..moveTo(38, 22)
      ..cubicTo(40, 36, 46, 42, 60, 44)
      ..cubicTo(46, 46, 40, 52, 38, 66)
      ..cubicTo(36, 52, 30, 46, 16, 44)
      ..cubicTo(30, 42, 36, 36, 38, 22)
      ..close();
    canvas.drawPath(main, lime);
    canvas.drawPath(main, outline);

    final top = Path()
      ..moveTo(70, 8)
      ..cubicTo(71, 14, 73, 16, 79, 17)
      ..cubicTo(73, 18, 71, 20, 70, 26)
      ..cubicTo(69, 20, 67, 18, 61, 17)
      ..cubicTo(67, 16, 69, 14, 70, 8)
      ..close();
    final bottom = Path()
      ..moveTo(72, 62)
      ..cubicTo(73, 67, 75, 69, 80, 70)
      ..cubicTo(75, 71, 73, 73, 72, 78)
      ..cubicTo(71, 73, 69, 71, 64, 70)
      ..cubicTo(69, 69, 71, 67, 72, 62)
      ..close();
    canvas.drawPath(top, ink..color = ink.color.withValues(alpha: topOpacity));
    canvas.drawPath(
      bottom,
      ink..color = ink.color.withValues(alpha: bottomOpacity),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Brand extends StatelessWidget {
  final Color textColor;
  final Animation<double> controller;

  const _Brand({required this.textColor, required this.controller});

  @override
  Widget build(BuildContext context) {
    final style = AppFonts.display(
      color: textColor,
      fontSize: 42,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacingEm: -.03,
    );
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final wipe = Curves.easeInOut.transform(
          ((controller.value - .08) / .28).clamp(0.0, 1.0),
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('NERD', style: style),
            const SizedBox(width: 5),
            ClipRect(
              child: Stack(
                children: [
                  Text('MAXXING', style: style.copyWith(color: AppColors.ink)),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: wipe,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'MAXXING',
                    style: style.copyWith(color: AppColors.ink),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedCta extends StatelessWidget {
  final Animation<double> controller;
  final Widget child;

  const _AnimatedCta({required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final shine = Curves.easeInOut.transform(
          ((controller.value - .32) / .34).clamp(0.0, 1.0),
        );
        final nudge = math.sin(controller.value * math.pi * 2);
        return Stack(
          children: [
            child!,
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Align(
                    alignment: Alignment(-1.4 + shine * 4.8, 0),
                    child: Transform.rotate(
                      angle: -.25,
                      child: Container(
                        width: 58,
                        height: 92,
                        color: AppColors.primary.withValues(alpha: .28),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Transform.translate(
                  offset: Offset(nudge * 4, 0),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}
