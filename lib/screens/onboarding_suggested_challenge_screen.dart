import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:provider/provider.dart';

import '../models/challenge.dart';
import '../providers/app_state_providers.dart';
import 'challenge/challenge_detail_screen.dart';
import '../services/challenges_service.dart';
import '../theme/app_theme.dart';

class SuggestedChallengeScreen extends ConsumerStatefulWidget {
  final Future<void> Function() onDiscover;
  final Future<void> Function(String slug) onJoined;
  final Future<void> Function(String slug) onAcceptedFromJourney;

  const SuggestedChallengeScreen({
    super.key,
    required this.onDiscover,
    required this.onJoined,
    required this.onAcceptedFromJourney,
  });

  @override
  ConsumerState<SuggestedChallengeScreen> createState() =>
      _SuggestedChallengeScreenState();
}

class _SuggestedChallengeScreenState
    extends ConsumerState<SuggestedChallengeScreen> {
  Challenge? _challenge;
  bool _loading = true;
  bool _joining = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadChallenge();
  }

  Future<void> _loadChallenge() async {
    try {
      final challenge = await context
          .read<ChallengesService>()
          .getSuggestedOrigamiChallenge();
      if (mounted) setState(() => _challenge = challenge);
    } catch (_) {
      if (mounted) {
        _loadError = 'Could not load the suggested challenge.';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinChallenge() async {
    final challenge = _challenge;
    if (challenge == null || _joining) return;
    setState(() => _joining = true);
    try {
      await ref
          .read(participationControllerProvider.notifier)
          .accept(challenge.slug);
      await widget.onJoined(challenge.slug);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join this challenge. Try Discover.'),
        ),
      );
      setState(() => _joining = false);
    }
  }

  Future<void> _openChallenge() async {
    final challenge = _challenge;
    if (challenge == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChallengeDetailScreen(
          slug: challenge.slug,
          initialChallenge: challenge,
          onAccepted: () => widget.onAcceptedFromJourney(challenge.slug),
        ),
      ),
    );
  }

  Widget _buildChallengeImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const Center(
        child: Icon(
          Icons.change_history_rounded,
          size: 88,
          color: HomePalette.ink,
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(
          Icons.change_history_rounded,
          size: 88,
          color: HomePalette.ink,
        ),
      ),
    );
  }

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
    final available = _challenge != null;
    final imageUrl = _challenge?.imageUrl;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR FIRST CHALLENGE',
                    style: AppFonts.body(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: surface,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      onTap: available ? _openChallenge : null,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          border: Border.all(color: border),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 178,
                              width: double.infinity,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: HomePalette.peach,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: _buildChallengeImage(imageUrl),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Fold an origami crane',
                              style: AppFonts.body(
                                color: ink,
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'A small, satisfying first adventure. Learn a few folds and turn a single sheet of paper into a crane.',
                              style: AppFonts.body(
                                color: muted,
                                fontSize: 15,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                _DetailPill(
                                  label: 'BEGINNER',
                                  ink: ink,
                                  border: border,
                                ),
                                const SizedBox(width: 8),
                                _DetailPill(
                                  label: '10-15 MIN',
                                  ink: ink,
                                  border: border,
                                ),
                              ],
                            ),
                            if (!_loading && !available)
                              Text(
                                _loadError ?? 'This challenge is not available yet. You can still explore Discover.',
                                style: AppFonts.body(
                                  color: muted,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: available && !_joining ? _joinChallenge : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: HomePalette.primary,
                        foregroundColor: HomePalette.ink,
                        disabledBackgroundColor: border,
                        disabledForegroundColor: muted,
                        shape: const StadiumBorder(),
                        textStyle: AppFonts.body(
                          color: HomePalette.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: _loading
                          ? const SizedBox.square(
                              dimension: 21,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _joining ? 'Joining...' : 'Join this challenge',
                            ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onDiscover,
                    icon: const Icon(Icons.explore_outlined, size: 19),
                    label: const Text('Head to Discover'),
                    style: TextButton.styleFrom(
                      foregroundColor: muted,
                      minimumSize: const Size.fromHeight(48),
                      textStyle: AppFonts.body(
                        color: muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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
}

class _DetailPill extends StatelessWidget {
  final String label;
  final Color ink;
  final Color border;

  const _DetailPill({
    required this.label,
    required this.ink,
    required this.border,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: AppFonts.body(
        color: ink,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
