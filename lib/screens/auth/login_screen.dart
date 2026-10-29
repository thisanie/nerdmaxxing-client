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
    setState(() {
      _showPasswordForm = !_showPasswordForm;
      _credentialError = null;
      _showRecoveryHint = false;
    });
    context.read<AuthProvider>().clearErrorMessage();
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
    final panel = isLight ? AppColors.lightSurface : AppColors.surface;
    final textColor = isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
    final mutedColor = isLight ? AppColors.lightTextSecondary : AppColors.textSecondary;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;
            return Stack(
              children: [
                Positioned(
                  right: -120,
                  top: -90,
                  child: IgnorePointer(
                    child: Container(
                      width: 340,
                      height: 340,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isLight
                            ? AppColors.limeWash
                            : AppColors.primaryMuted,
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  26,
                                  26,
                                  26,
                                  28,
                                ),
                                child: _Entrance(
                                  delay: .08,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          _SparkMark(
                                            controller: _motion,
                                            size: 30,
                                          ),
                                          const SizedBox(width: 8),
                                          _Brand(
                                            textColor: textColor,
                                            controller: _motion,
                                            fontSize: 19,
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: compact ? 30 : 48),
                                      _Headline(
                                        textColor: textColor,
                                        controller: _motion,
                                        fontSize: compact ? 48 : 56,
                                      ),
                                      const SizedBox(height: 16),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 340,
                                        ),
                                        child: Text(
                                          'The internet should make you more interesting, not more addicted.',
                                          style: AppFonts.body(
                                            color: mutedColor,
                                            fontSize: 18,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Expanded(child: SizedBox.shrink()),
                              Container(
                                decoration: BoxDecoration(
                                  color: panel,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(28),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isLight ? .08 : .22,
                                      ),
                                      blurRadius: 32,
                                      offset: const Offset(0, -8),
                                    ),
                                  ],
                                ),
                                padding: EdgeInsets.fromLTRB(
                                  22,
                                  22,
                                  22,
                                  22 + bottomInset,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SegmentedButton<bool>(
                                      segments: const [
                                        ButtonSegment<bool>(
                                          value: true,
                                          label: Text('Log in'),
                                        ),
                                        ButtonSegment<bool>(
                                          value: false,
                                          label: Text('Sign up'),
                                        ),
                                      ],
                                      selected: {_isLogin},
                                      onSelectionChanged: auth.isBusy
                                          ? null
                                          : (selection) =>
                                                _selectMode(selection.first),
                                    ),
                                    const SizedBox(height: 18),
                                    if (auth.errorMessage != null ||
                                        _credentialError != null) ...[
                                      _AuthMessage(
                                        message:
                                            _credentialError ??
                                            auth.errorMessage!,
                                        isError: true,
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                    SizedBox(
                                      height: 56,
                                      child: _checkingPrivacy
                                          ? const FilledButton(
                                              onPressed: null,
                                              child: Text(
                                                'Checking privacy policy...',
                                              ),
                                            )
                                          : _privacyAccepted
                                          ? buildGoogleAuthButton(
                                              isBusy: auth.isBusy,
                                              onPressed: () => context
                                                  .read<AuthProvider>()
                                                  .signInWithGoogle(),
                                            )
                                          : FilledButton.icon(
                                              onPressed: auth.isBusy
                                                  ? null
                                                  : _continueWithGoogle,
                                              icon: const Icon(
                                                Icons.shield_outlined,
                                              ),
                                              label: const Text(
                                                'Review privacy policy',
                                              ),
                                            ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _isLogin
                                          ? 'Log in with Google'
                                          : 'Sign up is with Google only.',
                                      textAlign: TextAlign.center,
                                      style: AppFonts.body(
                                        color: mutedColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (!_isLogin)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'No new password to remember.',
                                          textAlign: TextAlign.center,
                                          style: AppFonts.body(
                                            color: mutedColor,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    if (_isLogin) ...[
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: _togglePasswordForm,
                                        child: Text(
                                          _showPasswordForm
                                              ? 'Hide username and password'
                                              : 'Use username and password',
                                        ),
                                      ),
                                    ],
                                    if (_isLogin && _showPasswordForm) ...[
                                      const Divider(height: 20),
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
                                        onChanged: (_) =>
                                            _clearCredentialFeedback(),
                                        textCapitalization:
                                            TextCapitalization.none,
                                        autocorrect: false,
                                        autofillHints: const [
                                          AutofillHints.username,
                                        ],
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(
                                          labelText: 'Username',
                                          prefixIcon: Icon(
                                            Icons.person_outline,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _passwordController,
                                        onChanged: (_) =>
                                            _clearCredentialFeedback(),
                                        obscureText: _obscurePassword,
                                        autocorrect: false,
                                        autofillHints: const [
                                          AutofillHints.password,
                                        ],
                                        onSubmitted: (_) => auth.isBusy
                                            ? null
                                            : _submitPasswordLogin(),
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          prefixIcon: const Icon(
                                            Icons.lock_outline,
                                          ),
                                          suffixIcon: IconButton(
                                            tooltip: _obscurePassword
                                                ? 'Show password'
                                                : 'Hide password',
                                            onPressed: () => setState(
                                              () => _obscurePassword =
                                                  !_obscurePassword,
                                            ),
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                        .visibility_off_outlined,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed:
                                              _showPasswordRecoveryHint,
                                          child: const Text('Forgot password?'),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 52,
                                        child: OutlinedButton(
                                          onPressed: auth.isBusy
                                              ? null
                                              : _submitPasswordLogin,
                                          child: auth.isBusy
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Text('Log in'),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          'By continuing, you acknowledge our ',
                                          style: AppFonts.body(
                                            color: mutedColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: _showPrivacyPolicy,
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: const Text(
                                            'privacy policy',
                                            style: TextStyle(fontSize: 12),
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
                      ),
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
// Floating stickers: the app's loop in three words
// ---------------------------------------------------------------------------

class _StickerCluster extends StatelessWidget {
  final Animation<double> controller;
  final double height;
  final bool isLight;
  final Color textColor;

  const _StickerCluster({
    required this.controller,
    required this.height,
    required this.isLight,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final edge = isLight ? AppColors.ink : AppColors.primary;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 6,
            child: _Float(
              controller: controller,
              phase: 0,
              angle: -.10,
              child: _Sticker(
                background: AppColors.primary,
                edge: edge,
                shadow: isLight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Train it.',
                      style: AppFonts.display(
                        color: AppColors.ink,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacingEm: -.04,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'tiny reps, every day',
                      style: AppFonts.body(color: AppColors.ink, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: height * .30,
            child: _Float(
              controller: controller,
              phase: .33,
              angle: .08,
              child: _Sticker(
                background: AppColors.ink,
                edge: AppColors.ink,
                shadow: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prove it.',
                      style: AppFonts.display(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacingEm: -.04,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'show your work',
                      style: AppFonts.body(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 34,
            bottom: 0,
            child: _Float(
              controller: controller,
              phase: .66,
              angle: -.04,
              child: _Sticker(
                background: isLight ? Colors.white : const Color(0xFF1B1B1B),
                edge: isLight
                    ? AppColors.ink.withValues(alpha: .15)
                    : Colors.white24,
                shadow: false,
                radius: 99,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        size: 15,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Climb the ranks',
                      style: AppFonts.body(color: textColor, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Float extends StatelessWidget {
  final Animation<double> controller;
  final double phase;
  final double angle;
  final Widget child;

  const _Float({
    required this.controller,
    required this.phase,
    required this.angle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final dy = math.sin((controller.value + phase) * math.pi * 2) * 6;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(angle: angle, child: child),
        );
      },
      child: child,
    );
  }
}

class _Sticker extends StatelessWidget {
  final Color background;
  final Color edge;
  final bool shadow;
  final double radius;
  final EdgeInsets padding;
  final Widget child;

  const _Sticker({
    required this.background,
    required this.edge,
    required this.shadow,
    required this.child,
    this.radius = 22,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 18, 14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: edge, width: 1.5),
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: AppColors.ink,
                  offset: Offset(3, 3),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Ticker: slow marquee of the app's verbs
// ---------------------------------------------------------------------------

class _Ticker extends StatelessWidget {
  final Animation<double> controller;
  final bool isLight;
  final Color textColor;

  const _Ticker({
    required this.controller,
    required this.isLight,
    required this.textColor,
  });

  static const _items = [
    'Train',
    'Prove it',
    'Rank up',
    'Stay curious',
    'Be interesting',
    'Nerd on',
  ];
  static const _itemWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    final segment = _items.length * _itemWidth;
    final lineColor = isLight
        ? AppColors.ink.withValues(alpha: .10)
        : Colors.white12;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: lineColor, width: .5),
        ),
      ),
      child: ClipRect(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              child: Transform.translate(
                offset: Offset(-controller.value * segment, 0),
                child: child,
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < 3; r++)
                for (final item in _items)
                  SizedBox(
                    width: _itemWidth,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            item,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: AppFonts.body(color: textColor, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Spark mark
// ---------------------------------------------------------------------------

class _SparkMark extends StatelessWidget {
  final Animation<double> controller;
  final double size;

  const _SparkMark({required this.controller, this.size = 92});

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

  const _AnimatedCta({required this.child, this.radius = _ctaRadius});

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
    // Static, built once: the soft-edged shine bar.
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
                    child: const Icon(
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