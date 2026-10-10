import 'dart:async' show TimeoutException;
import 'dart:math' as math;

import 'package:dio/dio.dart' show DioException, DioExceptionType;
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Same lime as the rest of the app (was a slightly different hex before).
const Color _lime = AppColors.primary;

enum AppErrorKind { generic, offline, server, unavailable, vanished, lost }

class AppErrorInfo {
  final AppErrorKind kind;
  final String title;
  final String message;

  const AppErrorInfo({
    required this.kind,
    required this.title,
    required this.message,
  });

  /// Use for unknown routes (the 404 page).
  static const AppErrorInfo pageNotFound = AppErrorInfo(
    kind: AppErrorKind.lost,
    title: "You've reached the edge of the nerdverse.",
    message: "This page doesn't exist.",
  );

  /// Classifies any error into one of the user-facing kinds.
  ///
  /// Order matters: structured signals from [ApiException] win over string
  /// matching, so a server message that happens to contain "connection" can
  /// never turn into an "offline" screen.
  factory AppErrorInfo.from(Object error, {String? resource}) {
    if (error is AppErrorInfo) return error;

    if (error is ApiException) {
      if (error.isNetworkError) return _offline;
      final status = error.statusCode;
      if (status == null) {
        // No response: a slow server (send/receive timeout) vs. a dead link.
        if (error.isTimeout) return _server;
        return _looksLikeOffline(error.message) ? _offline : _generic;
      }
      // 403/410 share the "doesn't exist, or you don't have access" copy.
      if (status == 404 || status == 403 || status == 410) {
        return _missing(resource);
      }
      if (status >= 500 || status == 408 || status == 429) return _server;
      return _generic;
    }

    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status != null) {
        return AppErrorInfo.from(
          ApiException(status, error.message ?? ''),
          resource: resource,
        );
      }
      switch (error.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
          return _offline;
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return _server;
        default:
          return _looksLikeOffline('${error.error}') ? _offline : _generic;
      }
    }

    if (error is TimeoutException) return _server;
    if (_looksLikeOffline(error.toString())) return _offline;
    return _generic;
  }

  static AppErrorInfo _missing(String? resource) {
    if (resource == null) return _vanished;
    return AppErrorInfo(
      kind: AppErrorKind.unavailable,
      title: '$resource unavailable.',
      message:
          "We couldn't load this ${resource.toLowerCase()}. It might have moved, changed, or temporarily disappeared.",
    );
  }

  static const AppErrorInfo _vanished = AppErrorInfo(
    kind: AppErrorKind.vanished,
    title: 'This nerd has vanished.',
    message:
        "The thing you're looking for doesn't exist anymore, or you don't have access to it.",
  );

  static const AppErrorInfo _server = AppErrorInfo(
    kind: AppErrorKind.server,
    title: 'Our servers need a minute.',
    message: 'Even machines need a timeout sometimes. Try again in a moment.',
  );

  static const AppErrorInfo _generic = AppErrorInfo(
    kind: AppErrorKind.generic,
    title: 'The nerd engine stalled.',
    message:
        'Something went wrong on our end. Your progress is safe. Try again.',
  );

  static const AppErrorInfo _offline = AppErrorInfo(
    kind: AppErrorKind.offline,
    title: 'The internet has left the chat.',
    message: "You're offline. Check your connection and try again.",
  );

  /// Last-resort heuristic for errors that carry no structure.
  static bool _looksLikeOffline(String message) {
    final value = message.toLowerCase();
    return value.contains('connection') ||
        value.contains('offline') ||
        value.contains('network') ||
        value.contains('socket') ||
        value.contains('cors') ||
        value.contains('timed out');
  }
}

/// Full-page error state.
///
/// [onRetry] drives the main "TRY AGAIN" / "RECONNECT" button.
/// [onBack] drives whichever navigation button the kind shows (GO HOME,
/// EXPLORE CHALLENGES, GO BACK, BACK TO NERDMAXXING), so pass the destination
/// that matches the label. If it's null and the screen can be popped, the
/// back-style buttons pop instead of disappearing.
class AppErrorView extends StatelessWidget {
  final Object error;
  final String? resource;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;
  final String? retryLabel;
  final String? secondaryLabel;

  const AppErrorView({
    super.key,
    required this.error,
    this.resource,
    this.onRetry,
    this.onBack,
    this.retryLabel,
    this.secondaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final info = AppErrorInfo.from(error, resource: resource);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    final VoidCallback? back =
        onBack ??
        (Navigator.canPop(context) ? () => Navigator.maybePop(context) : null);

    final backIsPrimary =
        info.kind == AppErrorKind.vanished || info.kind == AppErrorKind.lost;
    final VoidCallback? primary = backIsPrimary ? (back ?? onRetry) : onRetry;
    final VoidCallback? secondary =
        (backIsPrimary || info.kind == AppErrorKind.offline) ? null : back;

    final primaryLabel =
        retryLabel ??
        switch (info.kind) {
          AppErrorKind.offline => 'RECONNECT',
          AppErrorKind.vanished => 'GO BACK',
          AppErrorKind.lost => 'BACK TO NERDMAXXING',
          _ => 'TRY AGAIN',
        };
    final secondLabel =
        secondaryLabel ??
        (info.kind == AppErrorKind.unavailable
            ? (resource?.toLowerCase() == 'challenge'
                  ? 'EXPLORE CHALLENGES'
                  : 'GO BACK')
            : 'GO HOME');

    final buttonText = AppFonts.body(
      color: scheme.onSurface,
      fontSize: 14,
      height: 1.0,
    ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.6);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (info.kind == AppErrorKind.lost) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: dark ? _lime : const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '404',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                      color: dark ? const Color(0xFF111111) : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Container(
                width: 176,
                height: 176,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark ? AppColors.primaryMuted : AppColors.limeWash,
                ),
                child: ErrorIllustration(kind: info.kind, size: 140),
              ),
              const SizedBox(height: 28),
              Semantics(
                header: true,
                child: Text(
                  info.title,
                  textAlign: TextAlign.center,
                  style: AppFonts.display(
                    color: scheme.onSurface,
                    fontSize: 28,
                    height: 1.08,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                info.message,
                textAlign: TextAlign.center,
                style: AppFonts.body(
                  color: scheme.onSurfaceVariant,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              if (primary != null || secondary != null) ...[
                const SizedBox(height: 28),
                if (primary != null)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: primary,
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: dark
                            ? _lime
                            : const Color(0xFF111111),
                        foregroundColor: dark
                            ? const Color(0xFF111111)
                            : Colors.white,
                      ),
                      child: Text(
                        primaryLabel,
                        style: buttonText.copyWith(
                          color: dark ? const Color(0xFF111111) : Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (primary != null && secondary != null)
                  const SizedBox(height: 10),
                if (secondary != null)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: secondary,
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(
                          color: dark
                              ? const Color(0xFF2D2D29)
                              : const Color(0xFFE4E4D8),
                          width: 1.5,
                        ),
                      ),
                      child: Text(secondLabel, style: buttonText),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Snackbar for failed actions (follow, join, complete a step...).
/// Keep the user in context; don't push an error page for these.
///
/// Wire once: `MaterialApp(scaffoldMessengerKey: AppErrorSnackbar.messengerKey)`.
class AppErrorSnackbar {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void show(
    BuildContext context,
    Object error, {
    String? message,
    VoidCallback? onRetry,
  }) {
    // The caller may have awaited something and been disposed; fall back to
    // the app-level messenger's context instead of throwing on Theme.of.
    final ctx = context.mounted ? context : messengerKey.currentContext;
    if (ctx == null) return;

    final info = AppErrorInfo.from(error);
    final dark = Theme.of(ctx).brightness == Brightness.dark;
    final bg = dark ? _lime : const Color(0xFF111111);
    final fg = dark ? const Color(0xFF111111) : Colors.white;
    final text =
        message ??
        switch (info.kind) {
          AppErrorKind.offline => "You're offline. Try again.",
          AppErrorKind.server => 'Our servers need a minute. Try again.',
          _ => 'Something went wrong. Try again.',
        };

    final messenger =
        messengerKey.currentState ?? ScaffoldMessenger.maybeOf(ctx);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          backgroundColor: bg,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          content: Text(
            text,
            style: TextStyle(color: fg, fontWeight: FontWeight.w500),
          ),
          action: onRetry == null
              ? null
              : SnackBarAction(
                  label: 'RETRY',
                  textColor: dark ? const Color(0xFF111111) : _lime,
                  onPressed: onRetry,
                ),
        ),
      );
  }

  /// Runs [action]; on failure shows the snackbar with a RETRY that re-runs
  /// the same action. Returns the result, or null if it failed.
  ///
  /// ```dart
  /// await AppErrorSnackbar.guard(
  ///   context,
  ///   () => api.joinChallenge(id),
  ///   message: "Couldn't join the challenge. Try again.",
  /// );
  /// ```
  /// 401s are skipped on purpose: the API client already handles an expired
  /// session by signing out, and a toast on top of that would only confuse.
  static Future<T?> guard<T>(
    BuildContext context,
    Future<T> Function() action, {
    String? message,
    bool retry = true,
  }) async {
    try {
      return await action();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) return null;
      if (context.mounted || messengerKey.currentContext != null) {
        show(
          context,
          error,
          message: message,
          onRetry: retry
              ? () {
                  guard<T>(context, action, message: message, retry: retry);
                }
              : null,
        );
      }
      return null;
    }
  }
}

/// Animated sticker-style illustration, one per error kind.
class ErrorIllustration extends StatefulWidget {
  final AppErrorKind kind;
  final double size;

  const ErrorIllustration({super.key, required this.kind, this.size = 140});

  @override
  State<ErrorIllustration> createState() => _ErrorIllustrationState();
}

class _ErrorIllustrationState extends State<ErrorIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.of(context).disableAnimations;
    if (_reduce) {
      _c.stop();
      _c.value = 0.7;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // RepaintBoundary keeps the 60fps animation from repainting the whole page.
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _ArtPainter(
            kind: widget.kind,
            anim: _c,
            ink: theme.colorScheme.onSurface,
            card: dark ? const Color(0xFF1A1A18) : Colors.white,
            bg: theme.scaffoldBackgroundColor,
          ),
        ),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  final AppErrorKind kind;
  final Animation<double> anim;
  final Color ink, card, bg;

  _ArtPainter({
    required this.kind,
    required this.anim,
    required this.ink,
    required this.card,
    required this.bg,
  }) : super(repaint: anim);

  late Canvas c;
  bool sh = false;
  double t = 0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 120);
    t = anim.value;
    c = canvas;
    canvas.save();
    canvas.translate(2.5, 2.5);
    sh = true;
    _draw();
    canvas.restore();
    sh = false;
    _draw();
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) =>
      old.kind != kind || old.ink != ink || old.card != card || old.bg != bg;

  // ---- helpers ----
  Paint _stroke(double w, [double a = 1]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = ink.withValues(alpha: a);

  void _fill(Path p, Color fill) {
    c.drawPath(p, Paint()..color = sh ? ink : fill);
    c.drawPath(p, _stroke(3));
  }

  void _line(Path p, [double w = 3, double a = 1]) =>
      c.drawPath(p, _stroke(w, a));

  void _dot(Offset o, double r, Color col, [double a = 1]) => c.drawCircle(
    o,
    r,
    Paint()..color = (sh ? ink : col).withValues(alpha: a),
  );

  Path _circle(double x, double y, double r) =>
      Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));

  Path _rrect(double x, double y, double w, double h, double r) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
    );

  Path _seg(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    return p;
  }

  Path _gear(double cx, double cy, double r, int n, double d) {
    final pts = <Offset>[];
    final h = math.pi / n;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n;
      for (final q in const [
        [-.8, 0.0],
        [-.4, 1.0],
        [.4, 1.0],
        [.8, 0.0],
      ]) {
        final an = a + q[0] * h;
        final rr = r + q[1] * d;
        pts.add(Offset(cx + rr * math.cos(an), cy + rr * math.sin(an)));
      }
    }
    return _seg(pts)..close();
  }

  double _pulse(double x) {
    x = (x % 1 + 1) % 1;
    return x < .4 ? math.sin(x / .4 * math.pi) : 0;
  }

  double _fade(double p) => p < .3 ? p / .3 : (1 - p) / .7;

  void _rot(double deg, double cx, double cy, VoidCallback body) {
    c.save();
    c.translate(cx, cy);
    c.rotate(deg * math.pi / 180);
    c.translate(-cx, -cy);
    body();
    c.restore();
  }

  void _draw() {
    switch (kind) {
      case AppErrorKind.generic:
        _gen();
      case AppErrorKind.offline:
        _off();
      case AppErrorKind.server:
        _srv();
      case AppErrorKind.unavailable:
        _chl();
      case AppErrorKind.vanished:
        _van();
      case AppErrorKind.lost:
        _lost();
    }
  }

  // ---- illustrations ----
  void _gen() {
    final p = t < .5 ? t * 2 : (1 - t) * 2;
    var ang = 70 * Curves.easeInOut.transform(math.min(p / .6, 1));
    if (p > .6 && p < .8) {
      ang += 3 * math.sin((p - .6) * 80) * (1 - (p - .6) / .2);
    }
    _rot(ang, 54, 70, () {
      _fill(_gear(54, 70, 26, 10, 9), _lime);
      _fill(_circle(54, 70, 9), bg);
    });
    _rot(-ang * 10 / 7, 96, 34, () {
      _fill(_gear(96, 34, 13, 7, 6), card);
      _fill(_circle(96, 34, 4), bg);
    });
    if (p > .58 && p < .8) {
      _line(
        _seg(const [Offset(82, 58), Offset(77, 64), Offset(84, 65), Offset(80, 72)]),
      );
      _line(
        Path()
          ..moveTo(22, 30)
          ..relativeLineTo(5, 5)
          ..moveTo(16, 38)
          ..relativeLineTo(7, 0)
          ..moveTo(28, 24)
          ..relativeLineTo(0, 6),
      );
    }
  }

  void _off() {
    const radii = [22.0, 42.0, 62.0];
    for (var i = 0; i < 3; i++) {
      final op = .12 + .88 * _pulse(t * 2 - i * .15);
      c.drawArc(
        Rect.fromCircle(center: const Offset(60, 95), radius: radii[i]),
        (-90 - 45.5) * math.pi / 180,
        91 * math.pi / 180,
        false,
        _stroke(8, op),
      );
    }
    _fill(_circle(60, 94, 8), _lime);
    final s = t < .15
        ? 0.0
        : t < .35
        ? (t - .15) / .2
        : t < .88
        ? 1.0
        : 1 - (t - .88) / .12;
    if (s > 0) {
      const a = Offset(24, 20), b = Offset(96, 104);
      final e = Offset.lerp(a, b, Curves.easeOut.transform(s))!;
      c.drawLine(a, e, _stroke(15));
      c.drawLine(
        a,
        e,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = sh ? ink : _lime,
      );
    }
  }

  void _srv() {
    _fill(_rrect(22, 22, 68, 26, 9), _lime);
    _fill(_rrect(22, 54, 68, 26, 9), card);
    _fill(_rrect(22, 86, 68, 26, 9), card);
    for (final x in const [34.0, 54.0]) {
      _line(
        Path()
          ..moveTo(x, 37)
          ..quadraticBezierTo(x + 5, 42, x + 10, 37),
      );
    }
    final ph = t % 1;
    _dot(const Offset(78, 35), 3.5, ink, (ph > .6 && ph < .9) ? .15 : 1);
    _dot(const Offset(34, 67), 3, ink);
    _dot(const Offset(34, 99), 3, ink);
    _line(_seg(const [Offset(46, 67), Offset(76, 67)]));
    _line(_seg(const [Offset(46, 99), Offset(76, 99)]));
    void z(double bx, double by, double w, double h, double phase) {
      final p = ((t - phase) % 1 + 1) % 1;
      final a = _fade(p).clamp(0.0, 1.0);
      c.save();
      c.translate(bx + 8 * p, by + 10 * (1 - p) - 12 * p);
      _line(
        _seg([Offset(0, 0), Offset(w, 0), Offset(0, h), Offset(w, h)]),
        2.5,
        a,
      );
      c.restore();
    }

    z(92, 12, 8, 10, 0);
    z(102, 2, 6, 8, .33);
  }

  void _chl() {
    _fill(_rrect(14, 14, 70, 92, 14), card);
    _fill(_circle(49, 50, 22), _lime);
    _fill(_circle(49, 50, 13), card);
    _dot(const Offset(49, 50), 4, ink);
    _line(_seg(const [Offset(30, 86), Offset(68, 86)]));
    _line(_seg(const [Offset(30, 95), Offset(52, 95)]));
    final s = math.sin(t * 2 * math.pi) * .5 + .5;
    c.save();
    c.translate(5 * s, -5 * s);
    _rot(8 * s, 100, 40, () {
      _line(_seg(const [Offset(112, 20), Offset(84, 56)]));
      _line(_seg(const [Offset(112, 20), Offset(110, 33)]));
      _line(_seg(const [Offset(112, 20), Offset(99, 22)]));
      _line(_seg(const [Offset(84, 56), Offset(81, 60)]), 7);
    });
    c.restore();
  }

  void _van() {
    final u = (1 - math.cos(t * 2 * math.pi)) / 2;
    c.save();
    c.translate(0, -8 * u);
    _rot(-4 + 8 * u, 60, 60, () {
      final body = Path()
        ..moveTo(30, 98)
        ..lineTo(30, 54)
        ..arcToPoint(
          const Offset(90, 54),
          radius: const Radius.circular(30),
          clockwise: true,
        )
        ..lineTo(90, 98)
        ..lineTo(80, 90)
        ..lineTo(70, 98)
        ..lineTo(60, 90)
        ..lineTo(50, 98)
        ..lineTo(40, 90)
        ..close();
      _fill(body, card);
      _fill(_circle(46, 56, 8), bg);
      _fill(_circle(74, 56, 8), bg);
      _line(_seg(const [Offset(54, 56), Offset(66, 56)]));
      _dot(const Offset(47, 57), 2.5, ink);
      _dot(const Offset(73, 57), 2.5, ink);
      _line(
        Path()
          ..moveTo(54, 74)
          ..quadraticBezierTo(60, 79, 66, 74),
      );
    });
    c.restore();
    const specks = [
      [38.0, 106.0, 4.0, 0.0],
      [80.0, 108.0, 3.5, .333],
      [60.0, 110.0, 5.0, .667],
    ];
    for (final s in specks) {
      final p = ((t - s[3]) % 1 + 1) % 1;
      _dot(
        Offset(s[0], s[1] + 8 - 30 * p),
        s[2],
        _lime,
        _fade(p).clamp(0.0, 1.0),
      );
    }
  }

  void _lost() {
    const stars = [
      [16.0, 24.0, 3.0, 0.0],
      [100.0, 100.0, 2.5, .33],
      [62.0, 14.0, 2.5, .66],
    ];
    for (final s in stars) {
      final a = .2 + .8 * (.5 + .5 * math.sin((t - s[3]) * 2 * math.pi));
      _dot(Offset(s[0], s[1]), s[2], ink, a);
    }
    final tether = Path()
      ..moveTo(46, 76)
      ..quadraticBezierTo(64, 72, 74, 56);
    for (final m in tether.computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        c.drawPath(m.extractPath(d, math.min(d + 3, m.length)), _stroke(3));
      }
    }
    _fill(_circle(32, 90, 20), _lime);
    c.save();
    c.translate(32, 90);
    c.rotate(-20 * math.pi / 180);
    _line(
      Path()
        ..addOval(Rect.fromCenter(center: Offset.zero, width: 64, height: 16)),
    );
    c.restore();

    final u = math.sin(t * 2 * math.pi);
    c.save();
    c.translate(0, -4 * u);
    _rot(4 * u, 86, 42, () {
      _fill(_circle(86, 42, 18), card);
      _fill(_circle(79, 40, 6), bg);
      _fill(_circle(93, 40, 6), bg);
      _line(_seg(const [Offset(85, 40), Offset(87, 40)]));
      _line(
        Path()
          ..moveTo(78, 52)
          ..quadraticBezierTo(86, 58, 94, 52),
      );
    });
    c.restore();
  }
}