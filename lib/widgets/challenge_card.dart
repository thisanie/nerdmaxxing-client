import 'package:flutter/material.dart';

import '../models/challenge.dart';
import '../theme/app_theme.dart';
import 'difficulty_badge.dart';

class ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback onTap;
  final bool legendary;

  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.onTap,
    this.legendary = false,
  });

  @override
  Widget build(BuildContext context) {
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
