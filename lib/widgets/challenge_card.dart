import 'package:flutter/material.dart';

import '../models/challenge.dart';
import '../theme/app_theme.dart';
import 'difficulty_badge.dart';

class ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback onTap;
  final bool legendary;
  final bool compact;

  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.onTap,
    this.legendary = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompactCard(context);

    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = challenge.imageUrl?.trim();
    return Card(
      clipBehavior: Clip.antiAlias,
      color: legendary
          ? Color.alphaBlend(
              AppColors.puzzle.withValues(alpha: 0.10),
              colorScheme.surface,
            )
          : null,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 8,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      frameBuilder:
                          (context, child, frame, wasSynchronouslyLoaded) {
                            if (wasSynchronouslyLoaded || frame != null) {
                              return child;
                            }
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                _fallbackImage(),
                                const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ],
                            );
                          },
                      errorBuilder: (_, _, _) => _fallbackImage(),
                    )
                  : _fallbackImage(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (legendary) ...[
                        const Icon(
                          Icons.workspace_premium_rounded,
                          size: 14,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Legendary',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else
                        DifficultyBadge(level: challenge.difficultyLevel),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    challenge.title,
                    style: AppFonts.body(
                      color: colorScheme.onSurface,
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    challenge.shortDescription,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        challenge.effortLabel,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.bolt_rounded,
                        size: 16,
                        color: colorScheme.onSurface,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${challenge.auraPoints}',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildCompactCard(BuildContext context) {
    final imageUrl = challenge.imageUrl?.trim();
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      _fallbackImage(),
                      const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  );
                },
                errorBuilder: (_, _, _) => _fallbackImage(),
              )
            else
              _fallbackImage(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, HomePalette.imageOverlay],
                  stops: [0.35, 1],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (legendary)
                    const _CompactLegendaryBadge()
                  else
                    _CompactDifficultyBadge(level: challenge.difficultyLevel),
                  const SizedBox(height: 8),
                  Text(
                    challenge.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.home(
                      color: HomePalette.imageText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: HomePalette.imageText.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          challenge.effortLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.home(
                            color: HomePalette.imageText.withValues(alpha: 0.8),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.bolt_rounded,
                        size: 12,
                        color: HomePalette.imageText.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${challenge.auraPoints}',
                        style: AppFonts.home(
                          color: HomePalette.imageText.withValues(alpha: 0.8),
                          fontSize: 10,
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
    );
  }

  Widget _fallbackImage() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.45, -0.5),
          colors: HomePalette.challengeGradient(challenge.title),
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome_rounded,
          size: 34,
          color: HomePalette.imageText,
        ),
      ),
    );
  }
}

class _CompactDifficultyBadge extends StatelessWidget {
  final String level;

  const _CompactDifficultyBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (level) {
      'BEGINNER' => ('Beginner', HomePalette.primary),
      'ADVANCED' => ('Advanced', AppColors.difficultyAdvanced),
      _ => ('Intermediate', AppColors.difficultyIntermediate),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppFonts.home(
          color: HomePalette.ink,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CompactLegendaryBadge extends StatelessWidget {
  const _CompactLegendaryBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.warning,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      'Legendary',
      style: AppFonts.home(
        color: HomePalette.ink,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
