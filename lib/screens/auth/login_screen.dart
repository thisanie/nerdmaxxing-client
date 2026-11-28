import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/google_auth_button.dart';
import '../../widgets/privacy_policy_dialog.dart';

/// Login and sign-up entry using the app's existing theme and auth providers.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  static const _privacyAcknowledgedKey = 'privacy_policy_acknowledged_v1';

  late final AnimationController _motion; // 6s loop: blob, spark, wipe, CTA
  bool _checkingPrivacy = true;
  bool _privacyAccepted = false;
  bool _privacyPromptOpen = false;
  bool _isLogin = true;
  bool _showPasswordForm = false;
  bool _obscurePassword = true;
  bool _showRecoveryHint = false;
  String? _credentialError;
  final _pageScrollController = ScrollController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPrivacyAcknowledgment();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _motion.dispose();
    _pageScrollController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadPrivacyAcknowledgment() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _privacyAccepted = preferences.getBool(_privacyAcknowledgedKey) ?? false;
      _checkingPrivacy = false;
    });
    if (!_privacyAccepted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestPrivacyAcknowledgment();
      });
    }
  }

  Future<void> _continueWithGoogle() async {
    if (_checkingPrivacy) return;
    final accepted = await _requestPrivacyAcknowledgment();
    if (!accepted || !mounted) return;
    if (!kIsWeb) {
      await context.read<AuthProvider>().signInWithGoogle();
    }
  }

  Future<bool> _requestPrivacyAcknowledgment() async {
    if (_privacyAccepted) return true;
    if (_privacyPromptOpen || !mounted) return false;
    _privacyPromptOpen = true;
    try {
      final accepted = await showPrivacyPolicyDialog(
        context,
        requireAcceptance: true,
      );
      if (accepted != true || !mounted) return false;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_privacyAcknowledgedKey, true);
      if (!mounted) return false;
      setState(() => _privacyAccepted = true);
      return true;
    } finally {
      _privacyPromptOpen = false;
    }
  }

  Future<void> _showPrivacyPolicy() async {
    await showPrivacyPolicyDialog(context);
  }

  Future<void> _submitPasswordLogin() async {
    if (_checkingPrivacy || context.read<AuthProvider>().isBusy) return;
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _credentialError = 'Enter your username and password.');
      return;
    }
    final accepted = await _requestPrivacyAcknowledgment();
    if (!accepted || !mounted) return;
    setState(() {
      _credentialError = null;
      _showRecoveryHint = false;
    });
    try {
      await context.read<AuthProvider>().signInWithPassword(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
    } catch (error) {
      if (mounted) setState(() => _credentialError = error.toString());
    }
  }

  void _selectMode(bool isLogin) {
    setState(() {
      _isLogin = isLogin;
      _credentialError = null;
      _showRecoveryHint = false;
      if (!isLogin) _showPasswordForm = false;
    });
    context.read<AuthProvider>().clearErrorMessage();
  }

  void _togglePasswordForm() {
    final opening = !_showPasswordForm;
    setState(() {
      _showPasswordForm = opening;
      _credentialError = null;
      _showRecoveryHint = false;
    });
    context.read<AuthProvider>().clearErrorMessage();
    if (opening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageScrollController.hasClients) return;
        final position = _pageScrollController.position;
        if (position.maxScrollExtent <= 0) return;
        _pageScrollController.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  void _clearCredentialFeedback() {
    if (_credentialError == null &&
        context.read<AuthProvider>().errorMessage == null) {
      return;
    }
    setState(() => _credentialError = null);
    context.read<AuthProvider>().clearErrorMessage();
  }

  void _showPasswordRecoveryHint() {
    setState(() {
      _showRecoveryHint = true;
      _credentialError = null;
    });
    context.read<AuthProvider>().clearErrorMessage();
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
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 850) {
              final horizontalPadding = math.min(
                76.0,
                math.max(24.0, constraints.maxWidth * .06),
              );
              final availableWidth = math.min(
                constraints.maxWidth - horizontalPadding * 2,
                1180.0 - horizontalPadding * 2,
              );
              final cardWidth = math.min(
                450.0,
                math.max(360.0, availableWidth * .42),
              );
              final gap = math.min(100.0, math.max(36.0, availableWidth * .07));
              final minimumPageHeight = _showPasswordForm ? 820.0 : 690.0;
              final verticalPadding = math.min(
                44.0,
                math.max(0.0, (constraints.maxHeight - minimumPageHeight) / 2),
              );
              final pageHeight = math.max(
                minimumPageHeight,
                constraints.maxHeight - verticalPadding * 2,
              );
              return SingleChildScrollView(
                controller: _pageScrollController,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: SizedBox(
                        height: pageHeight,
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildHero(
                                desktop: true,
                                isLight: isLight,
                                textColor: textColor,
                                mutedColor: mutedColor,
                              ),
                            ),
                            SizedBox(width: gap),
                            SizedBox(
                              width: cardWidth,
                              child: Center(
                                child: _buildAuthCard(
                                  auth: auth,
                                  isLight: isLight,
                                  mobile: false,
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

            return SingleChildScrollView(
              controller: _pageScrollController,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHero(
                        desktop: false,
                        isLight: isLight,
                        textColor: textColor,
                        mutedColor: mutedColor,
                      ),
                      const Spacer(),
                      _buildAuthCard(
                        auth: auth,
                        isLight: isLight,
                        mobile: true,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero({
    required bool desktop,
    required bool isLight,
    required Color textColor,
    required Color mutedColor,
  }) {
    final orbSize = desktop ? 470.0 : 360.0;
    final orbRight = desktop ? -245.0 : -190.0;
    final orbTop = desktop ? 0.0 : -72.0;
    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SparkMark(
          controller: _motion,
          color: textColor,
          size: desktop ? 34 : 28,
        ),
        SizedBox(width: desktop ? 12 : 8),
        _Brand(
          textColor: textColor,
          controller: _motion,
          fontSize: desktop ? 22 : 20,
        ),
      ],
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Headline(
          textColor: textColor,
          controller: _motion,
          fontSize: desktop ? 76 : 54,
        ),
        SizedBox(height: desktop ? 28 : 22),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: desktop ? 470 : 440),
          child: Text(
            'The internet should make you more interesting, not more addicted.',
            style: AppFonts.body(
              color: mutedColor,
              fontSize: desktop ? 23 : 20,
              height: 1.5,
            ),
          ),
        ),
        if (desktop) ...[
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _PrinciplePill(label: 'Learn real skills'),
              _PrinciplePill(label: 'Do things offline'),
              _PrinciplePill(label: 'Earn your progress'),
            ],
          ),
        ],
      ],
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: orbTop,
          right: orbRight,
          child: IgnorePointer(
            child: Container(
              width: orbSize,
              height: orbSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLight ? AppColors.limeWash : AppColors.primaryMuted,
              ),
            ),
          ),
        ),
        if (desktop)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Entrance(delay: .05, child: brand),
                _Entrance(delay: .18, child: copy),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'LESS SCROLLING. MORE BECOMING.',
                    style: AppFonts.label(
                      color: mutedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 30, 28, 42),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Entrance(delay: .05, child: brand),
                const SizedBox(height: 52),
                _Entrance(delay: .18, child: copy),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAuthCard({
    required AuthProvider auth,
    required bool isLight,
    required bool mobile,
  }) {
    final card = isLight ? AppColors.lightSurface : AppColors.surface;
    final border = isLight ? AppColors.lightBorder : AppColors.border;
    final muted = isLight ? AppColors.lightTextSecondary : AppColors.textSecondary;
    final bottomInset = mobile ? MediaQuery.paddingOf(context).bottom : 0.0;
    final horizontalPadding = mobile && MediaQuery.sizeOf(context).width <= 390
        ? 22.0
        : mobile
        ? 28.0
        : 34.0;
    final modeHeading = _isLogin ? 'Welcome back.' : 'Start becoming.';
    final modeSubtitle = _isLogin
        ? 'Pick up where your next level begins.'
        : 'Build skills, take on challenges, and become more you.';
    final helper = _isLogin
        ? 'Fast, secure sign-in. No new password to remember.'
        : 'Free to start. Make progress at your own pace.';

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: mobile
            ? const BorderRadius.vertical(top: Radius.circular(30))
            : BorderRadius.circular(28),
        border: mobile ? null : Border.all(color: border.withValues(alpha: .4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: mobile ? .045 : .07),
            blurRadius: mobile ? 45 : 70,
            offset: Offset(0, mobile ? -12 : 20),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        mobile ? 28 : 34,
        horizontalPadding,
        (mobile ? 30 : 34) + bottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            modeHeading,
            style: AppFonts.display(
              color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacingEm: -.045,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            modeSubtitle,
            style: AppFonts.body(color: muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          _ModeTabs(
            isLogin: _isLogin,
            isLight: isLight,
            onChanged: auth.isBusy ? null : _selectMode,
          ),
          const SizedBox(height: 22),
          if (auth.errorMessage != null || _credentialError != null) ...[
            _AuthMessage(
              message: _credentialError ?? auth.errorMessage!,
              isError: true,
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            height: 60,
            child: _checkingPrivacy
                ? const FilledButton(
                    onPressed: null,
                    child: Text('Checking privacy policy...'),
                  )
                : _privacyAccepted
                ? buildGoogleAuthButton(
                    isBusy: auth.isBusy,
                    label: _isLogin
                        ? 'Continue with Google'
                        : 'Sign up with Google',
                    onPressed: () => context
                        .read<AuthProvider>()
                        .signInWithGoogle(),
                  )
                : FilledButton.icon(
                    onPressed: auth.isBusy ? null : _continueWithGoogle,
                    icon: const Icon(Icons.shield_outlined),
                    label: const Text('Review privacy policy'),
                  ),
          ),
          if (_isLogin) ...[
            const _OrDivider(),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _togglePasswordForm,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isLight
                      ? AppColors.lightTextPrimary
                      : AppColors.textPrimary,
                  side: BorderSide(color: border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _showPasswordForm
                      ? 'Hide username and password'
                      : 'Use username and password',
                ),
              ),
            ),
            if (_showPasswordForm) ...[
              const SizedBox(height: 16),
              if (_showRecoveryHint) ...[
                const _AuthMessage(
                  message:
                      'Password reset is not available here. Continue with Google to get back into your account.',
                  isError: false,
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _usernameController,
                onChanged: (_) => _clearCredentialFeedback(),
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                onChanged: (_) => _clearCredentialFeedback(),
                obscureText: _obscurePassword,
                autocorrect: false,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => auth.isBusy ? null : _submitPasswordLogin(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showPasswordRecoveryHint,
                  child: const Text('Forgot password?'),
                ),
              ),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: auth.isBusy ? null : _submitPasswordLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: auth.isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Log in'),
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          Text(
            helper,
            textAlign: TextAlign.center,
            style: AppFonts.body(color: muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 15, color: muted),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Your account is yours. Your progress is personal.',
                  textAlign: TextAlign.center,
                  style: AppFonts.body(color: muted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'By continuing, you agree to our ',
                style: AppFonts.body(color: muted, fontSize: 12, height: 1.6),
              ),
              TextButton(
                onPressed: _showPrivacyPolicy,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              Text(
                '.',
                style: AppFonts.body(color: muted, fontSize: 12, height: 1.6),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Entrance
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Headline: "Get more" + lime-wiped "interesting."
// ---------------------------------------------------------------------------

class _Headline extends StatelessWidget {
  final Color textColor;
  final Animation<double> controller;
  final double fontSize;

  const _Headline({
    required this.textColor,
    required this.controller,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppFonts.display(
      color: textColor,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.05,
      letterSpacingEm: -.03,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Get more', style: style),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: _Wipe(
            text: 'interesting.',
            style: style,
            controller: controller,
            textColor: textColor,
          ),
        ),
      ],
    );
  }
}

/// Lime highlight that sweeps across a word, then holds. Text flips to ink
/// as the highlight passes so it stays readable in both themes.
class _Wipe extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Animation<double> controller;
  final Color textColor;

  const _Wipe({
    required this.text,
    required this.style,
    required this.controller,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final wipe = Curves.easeInOut.transform(
          ((controller.value - .08) / .28).clamp(0.0, 1.0),
        );
        return Stack(
          children: [
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                text,
                style: style.copyWith(
                  color: Color.lerp(textColor, AppColors.ink, wipe),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Brand extends StatelessWidget {
  final Color textColor;
  final Animation<double> controller;
  final double fontSize;

  const _Brand({
    required this.textColor,
    required this.controller,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppFonts.display(
      color: textColor,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacingEm: -.03,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('NERD', style: style),
        const SizedBox(width: 3),
        _Wipe(
          text: 'MAXXING',
          style: style,
          controller: controller,
          textColor: textColor,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Spark mark
// ---------------------------------------------------------------------------

class _SparkMark extends StatelessWidget {
  final Animation<double> controller;
  final Color color;
  final double size;

  const _SparkMark({
    required this.controller,
    required this.color,
    this.size = 92,
  });

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
            size: Size(size, size),
              painter: _SparkPainter(
              topOpacity: .25 + twinkle * .75,
              bottomOpacity: 1 - twinkle * .65,
            ),
          ),
        );
      },
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
    canvas.drawPath(
      top,
      Paint()..color = AppColors.ink.withValues(alpha: topOpacity),
    );
    canvas.drawPath(
      bottom,
      Paint()..color = AppColors.ink.withValues(alpha: bottomOpacity),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.topOpacity != topOpacity || old.bottomOpacity != bottomOpacity;
}

// ---------------------------------------------------------------------------
// CTA: owns its own controllers so it animates independently, in its own
// repaint layer, with a soft gradient shine and tactile press feedback.
// ---------------------------------------------------------------------------

/// Corner radius shared by the button clip and the shine overlay, so the two
/// can never disagree. Set this to your Google button's own radius
/// (use 32 for a full pill at height 64).
const double _ctaRadius = 20;

class _AnimatedCta extends StatefulWidget {
  final Widget child;
  final double radius;

  const _AnimatedCta({required this.child}) : radius = _ctaRadius;

  @override
  State<_AnimatedCta> createState() => _AnimatedCtaState();
}

class _AnimatedCtaState extends State<_AnimatedCta>
    with TickerProviderStateMixin {
  late final AnimationController _shine;
  late final AnimationController _arrow;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    // Sweep for ~1.6s, then rest, so the motion feels deliberate.
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
    // Gentle ping-pong, easing at both ends.
    _arrow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shine.dispose();
    _arrow.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final shineBar = Transform.rotate(
      angle: -.25,
      child: const SizedBox(
        width: 90,
        height: 110,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0x00C8F53A),
                Color(0x47C8F53A),
                Color(0x00C8F53A),
              ],
            ),
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? .975 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(widget.radius),
                clipBehavior: Clip.antiAlias,
                child: widget.child,
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(widget.radius),
                    clipBehavior: Clip.antiAlias,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        return AnimatedBuilder(
                          animation: _shine,
                          child: shineBar,
                          builder: (context, bar) {
                            final t = Curves.easeInOutSine.transform(
                              (_shine.value / .45).clamp(0.0, 1.0),
                            );
                            final x = -110 + t * (box.maxWidth + 130);
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Transform.translate(
                                offset: Offset(x, 0),
                                child: bar,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _arrow,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    builder: (context, icon) {
                      final dx = Curves.easeInOutSine.transform(_arrow.value) * 5;
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: icon,
                      );
                    },
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

class _AuthMessage extends StatelessWidget {
  final String message;
  final bool isError;

  const _AuthMessage({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final background = isError
        ? AppColors.danger.withValues(alpha: isLight ? .10 : .16)
        : AppColors.primary.withValues(alpha: isLight ? .22 : .14);
    final foreground = isError ? AppColors.danger : Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: AppFonts.body(color: foreground, fontSize: 13),
      ),
    );
  }
}

class _ModeTabs extends StatelessWidget {
  final bool isLogin;
  final bool isLight;
  final ValueChanged<bool>? onChanged;

  const _ModeTabs({
    required this.isLogin,
    required this.isLight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = isLight ? AppColors.lightBorder : AppColors.border;
    final muted = isLight ? AppColors.lightTextSecondary : AppColors.textSecondary;
    final ink = isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
    final base = isLight ? AppColors.lightBackground : AppColors.surfaceAlt;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _ModeTab(
            label: 'Log in',
            selected: isLogin,
            ink: ink,
            muted: muted,
            onTap: onChanged == null ? null : () => onChanged!(true),
          ),
          _ModeTab(
            label: 'Sign up',
            selected: !isLogin,
            ink: ink,
            muted: muted,
            onTap: onChanged == null ? null : () => onChanged!(false),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Color ink;
  final Color muted;
  final VoidCallback? onTap;

  const _ModeTab({
    required this.label,
    required this.selected,
    required this.ink,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
          color: selected ? AppColors.limeWash : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(
                label,
                style: AppFonts.body(
                  color: selected ? ink : muted,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.light
        ? AppColors.lightBorder
        : AppColors.border;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Row(
        children: [
          Expanded(child: Divider(color: color, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'OR',
              style: AppFonts.label(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: color, height: 1)),
        ],
      ),
    );
  }
}

class _PrinciplePill extends StatelessWidget {
  final String label;

  const _PrinciplePill({required this.label});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ink = isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
    final muted = isLight ? AppColors.lightTextSecondary : AppColors.textSecondary;
    final border = isLight ? AppColors.lightBorder : AppColors.border;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: isLight ? AppColors.lightSurface.withValues(alpha: .72) : AppColors.surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppFonts.body(
          color: Color.lerp(ink, muted, .22)!,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}