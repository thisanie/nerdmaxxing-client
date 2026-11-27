import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

enum CardType { challenge, quest }

class CardTheme {
  final Color background;
  final Color text;
  final Color muted;
  final Color accent;
  final Color title;

  const CardTheme({
    required this.background,
    required this.text,
    required this.muted,
    required this.accent,
    required this.title,
  });
}

CardTheme resolveTheme({String? rank, Color? fill}) {
  final normalizedRank = rank?.trim().toUpperCase();
  final isRankE = normalizedRank == 'E';
  final base = switch (normalizedRank) {
    'E' => const Color(0xFFFF4D6D),
    'D' => const Color(0xFF3DDC97),
    'C' => const Color(0xFF35C4FF),
    'A' => const Color(0xFFFF8A1F),
    'S' => const Color(0xFF04060C),
    _ => const Color(0xFF8B7BFF),
  };

  if (fill == null) {
    if (normalizedRank == 'S') {
      return const CardTheme(
        background: Color(0xFFC6FF00),
        text: Color(0xFF04060C),
        muted: Color.fromARGB(158, 4, 6, 12),
        accent: Color(0xFF04060C),
        title: Color(0xFF04060C),
      );
    }
    return CardTheme(
      background: const Color(0xFF04060C),
      text: const Color(0xFFF5F5F0),
      muted: const Color(0xFF8B90A3),
      accent: base,
      title: isRankE ? const Color(0xFFFFE08A) : const Color(0xFFF5F5F0),
    );
  }

  final luma = 0.299 * fill.red + 0.587 * fill.green + 0.114 * fill.blue;
  if (luma > 150) {
    return CardTheme(
      background: fill,
      text: const Color(0xFF04060C),
      muted: const Color.fromARGB(158, 4, 6, 12),
      accent: const Color(0xFF04060C),
      title: const Color(0xFF04060C),
    );
  }

  return CardTheme(
    background: fill,
    text: const Color(0xFFF5F5F0),
    muted: const Color(0xFFA9AEC0),
    accent: fill.value == base.value
        ? const Color(0xFFF5F5F0)
        : base,
    title: isRankE ? const Color(0xFFFFE08A) : const Color(0xFFF5F5F0),
  );
}

Future<Uint8List> exportCardPng(GlobalKey key) async {
  if (key.currentContext == null) {
    throw StateError('The achievement card is not mounted.');
  }
  await WidgetsBinding.instance.endOfFrame;
  final renderObject = key.currentContext?.findRenderObject();
  if (renderObject is! RenderRepaintBoundary) {
    throw StateError('The key must be attached to an AchievementCard.');
  }

  final image = await renderObject.toImage(pixelRatio: 2);
  try {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Could not encode the achievement card as PNG.');
    }
    return byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
  } finally {
    image.dispose();
  }
}

class AchievementCard extends StatelessWidget {
  final CardType type;
  final String title;
  final int aura;
  final String username;
  final String? result;
  final String? rank;
  final Color? fill;

  const AchievementCard({
    super.key,
    required this.type,
    required this.title,
    required this.aura,
    required this.username,
    this.result,
    this.rank,
    this.fill,
  });

  static const double _canvasWidth = 1080;
  static const double _canvasHeight = 1350;

  @override
  Widget build(BuildContext context) {
    final cardTheme = resolveTheme(
      rank: type == CardType.challenge ? rank : null,
      fill: fill,
    );
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: _canvasWidth,
            height: _canvasHeight,
            child: _buildCanvas(cardTheme),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas(CardTheme cardTheme) {
    final showResult = type == CardType.challenge && result != null;
    return ColoredBox(
      color: cardTheme.background,
      child: Stack(
        children: [
          Positioned(
            left: 88,
            right: 88,
            top: 88,
            height: 66,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF04060C),
                    border: Border.all(color: const Color(0x24FFFFFF), width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'NERD',
                            style: TextStyle(color: Color(0xFFFFFFFF)),
                          ),
                          const TextSpan(
                            text: 'MAXXING',
                            style: TextStyle(color: Color(0xFFC6FF00)),
                          ),
                        ],
                      ),
                      style: _inter(
                        size: 34,
                        weight: FontWeight.w900,
                        letterSpacing: -0.34,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
                Text(
                  'no small wins',
                  textAlign: TextAlign.right,
                  style: _inter(
                    size: 30,
                    weight: FontWeight.w800,
                    color: cardTheme.accent,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 92,
            right: 92,
            top: 220,
            bottom: 190,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type == CardType.challenge
                      ? 'you ate this challenge'
                      : 'quest cleared, no cap',
                  style: _inter(
                    size: 30,
                    weight: FontWeight.w800,
                    color: cardTheme.accent,
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final metricHeight = showResult ? 140.0 : 0.0;
                      final titleHeight = math
                          .max(0.0, constraints.maxHeight - metricHeight - 80)
                          .toDouble();
                      final fontSize = _fitTitleFontSize(
                        title.toLowerCase(),
                        maxWidth: constraints.maxWidth,
                        maxHeight: titleHeight,
                      );
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.toLowerCase(),
                              style: _inter(
                                size: fontSize,
                                weight: FontWeight.w900,
                                color: cardTheme.title,
                                height: 0.95,
                                letterSpacing: fontSize * -0.03,
                              ),
                              textScaler: TextScaler.noScaling,
                              softWrap: true,
                            ),
                            if (showResult) ...[
                              const SizedBox(height: 38),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.only(top: 20),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: cardTheme.muted,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        result!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: _inter(
                                          size: 64,
                                          weight: FontWeight.w900,
                                          color: cardTheme.accent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Text(
                                      'personal best fr',
                                      style: _inter(
                                        size: 26,
                                        weight: FontWeight.w800,
                                        color: cardTheme.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: SizedBox(
                    height: 86,
                    child: Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '+$aura',
                                    style: _inter(
                                      size: 72,
                                      weight: FontWeight.w900,
                                      color: cardTheme.accent,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '  AURA',
                                    style: _inter(
                                      size: 27,
                                      weight: FontWeight.w800,
                                      color: cardTheme.accent,
                                    ),
                                  ),
                                ],
                              ),
                              textScaler: TextScaler.noScaling,
                            ),
                          ),
                        ),
                        if (type == CardType.challenge && rank != null)
                          Text(
                            rank!.toUpperCase(),
                            style: _inter(
                              size: 80,
                              weight: FontWeight.w900,
                              color: cardTheme.accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (type == CardType.challenge)
            Positioned(
              right: 100,
              top: 378,
              width: 229,
              height: 229,
              child: Transform.rotate(
                angle: 12 * math.pi / 180,
                child: _AchievementStamp(
                  background: cardTheme.background,
                  accent: cardTheme.accent,
                ),
              ),
            ),
          Positioned(
            left: 88,
            right: 88,
            bottom: 82,
            height: 36,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '@$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _inter(
                      size: 28,
                      weight: FontWeight.w800,
                      color: cardTheme.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Text(
                  'nerdmaxxing.com',
                  style: _inter(
                    size: 28,
                    weight: FontWeight.w800,
                    color: cardTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _fitTitleFontSize(
    String title, {
    required double maxWidth,
    required double maxHeight,
  }) {
    for (var size = 150.0; size >= 66; size -= 6) {
      final painter = TextPainter(
        text: TextSpan(
          text: title,
          style: _inter(
            size: size,
            weight: FontWeight.w900,
            height: 0.95,
            letterSpacing: size * -0.03,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout(maxWidth: maxWidth);
      if (painter.height <= maxHeight) return size;
    }
    return 66;
  }
}

class _AchievementStamp extends StatelessWidget {
  final Color background;
  final Color accent;

  const _AchievementStamp({required this.background, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 12,
          width: 205,
          height: 205,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              border: Border.all(color: background, width: 7),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x47000000),
                  offset: Offset(10, 10),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _StampRingsPainter(background: background, accent: accent),
          ),
        ),
        Positioned(
          left: 12,
          top: 12,
          width: 205,
          height: 205,
          child: IgnorePointer(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '★  ★',
                  style: _inter(
                    size: 22,
                    weight: FontWeight.w800,
                    color: background,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'locked in',
                  textAlign: TextAlign.center,
                  style: _inter(
                    size: 37,
                    weight: FontWeight.w900,
                    color: background,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StampRingsPainter extends CustomPainter {
  final Color background;
  final Color accent;

  const _StampRingsPainter({required this.background, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final outerRing = Rect.fromCircle(center: center, radius: 111);
    for (var index = 0; index < 50; index++) {
      canvas.drawArc(outerRing, index * math.pi * 2 / 50, 0.075, false, outerPaint);
    }

    final dotPaint = Paint()..color = background;
    for (var index = 0; index < 48; index++) {
      final angle = index * math.pi * 2 / 48;
      final point = center + Offset(math.cos(angle) * 82, math.sin(angle) * 82);
      canvas.drawCircle(point, 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StampRingsPainter oldDelegate) {
    return oldDelegate.background != background || oldDelegate.accent != accent;
  }
}

TextStyle _inter({
  required double size,
  required FontWeight weight,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}