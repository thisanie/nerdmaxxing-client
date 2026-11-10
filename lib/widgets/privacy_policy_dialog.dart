import 'package:flutter/material.dart' hide SnackBar;
import 'app_snack_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

const _privacyPolicyUri = 'https://www.nerdmaxxing.com/privacy';
const _panelColor = Color(0xFFF0F0E6);
const _topicColor = Color(0xFFE6E6D9);
const _frameColor = Color(0xFF777871);

Future<bool?> showPrivacyPolicyDialog(
  BuildContext context, {
  bool requireAcceptance = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => Theme(
      data: AppTheme.neutralActionTheme(Theme.of(dialogContext)),
      child: Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 940,
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: SizedBox(
          width: double.infinity,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _frameColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: _panelColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6E6D9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: Text(
                            'BEFORE YOU CONTINUE',
                            style: AppFonts.label(
                              color: const Color(0xFF37382F),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.verified_user_outlined,
                        color: const Color(0xFF37382F),
                        size: 23,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Your privacy matters.',
                    style: AppFonts.display(
                      color: const Color(0xFF20211B),
                      fontSize: 29,
                      fontWeight: FontWeight.w600,
                      letterSpacingEm: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A quick look at how NerdMaxxing handles your information.',
                    style: AppFonts.body(
                      color: const Color(0xFF6D6D64),
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _topicColor,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Column(
                      children: [
                        _PrivacyTopic(
                          icon: Icons.storage_outlined,
                          label: 'What information we collect',
                        ),
                        _PrivacyTopic(
                          icon: Icons.visibility_outlined,
                          label: "What's visible to other users",
                        ),
                        _PrivacyTopic(
                          icon: Icons.delete_outline,
                          label: 'How to delete your data',
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final opened = await launchUrl(
                          Uri.parse(_privacyPolicyUri),
                          mode: LaunchMode.externalApplication,
                        );
                        if (!opened && dialogContext.mounted) {
                          ScaffoldMessenger.maybeOf(dialogContext)?.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not open the privacy policy.',
                              ),
                            ),
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF37382F),
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(
                        'Read the full Privacy Policy',
                        style: AppFonts.body(
                          color: const Color(0xFF37382F),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 14, bottom: 10),
                    child: Divider(color: Color(0xFFD8D8CD), height: 1),
                  ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (requireAcceptance)
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF37382F),
                            minimumSize: const Size(0, 52),
                          ),
                          child: Text(
                            'Not now',
                            style: AppFonts.body(
                              color: const Color(0xFF37382F),
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(
                          requireAcceptance ? true : null,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF37382F),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 52),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: const StadiumBorder(),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(requireAcceptance ? 'Continue' : 'Close'),
                            if (requireAcceptance) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, size: 18),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    ),
  );
}

class _PrivacyTopic extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PrivacyTopic({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF37382F), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppFonts.body(
                color: const Color(0xFF37382F),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
