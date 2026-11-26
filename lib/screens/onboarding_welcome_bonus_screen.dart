import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class WelcomeBonusScreen extends StatelessWidget {
  final Future<void> Function() onContinue;

  const WelcomeBonusScreen({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? HomePalette.darkBackground
        : HomePalette.lightBackground;
    final surface = isDark ? HomePalette.darkSurface : HomePalette.lightSurface;
    final ink = isDark
        ? HomePalette.darkTextPrimary
        : HomePalette.lightTextPrimary;
    final muted = isDark
        ? HomePalette.darkTextSecondary
        : HomePalette.lightTextSecondary;
    final border = isDark ? HomePalette.darkBorder : HomePalette.lightBorder;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'NERDMAXXING',
                      style: AppFonts.body(
                        color: ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 184,
                    height: 184,
                    decoration: BoxDecoration(
                      color: HomePalette.primary,
                      borderRadius: BorderRadius.circular(92),
                      boxShadow: [
                        BoxShadow(
                          color: HomePalette.primary.withValues(alpha: .18),
                          blurRadius: 54,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      size: 78,
                      color: HomePalette.ink,
                    ),
                  ),
                  const SizedBox(height: 34),
                  Text(
                    'A little Aura\nto get you started.',
                    textAlign: TextAlign.center,
                    style: AppFonts.body(
                      color: ink,
                      fontSize: 31,
                      fontWeight: FontWeight.w800,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: surface,
                      border: Border.all(color: border),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          color: HomePalette.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '+100',
                          style: AppFonts.body(
                            color: ink,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AURA',
                          style: AppFonts.body(
                            color: muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your account creation bonus. Your next adventure is waiting.',
                    textAlign: TextAlign.center,
                    style: AppFonts.body(
                      color: muted,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: onContinue,
                      style: FilledButton.styleFrom(
                        backgroundColor: HomePalette.primary,
                        foregroundColor: HomePalette.ink,
                        shape: const StadiumBorder(),
                        textStyle: AppFonts.body(
                          color: HomePalette.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text('Continue'),
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