import 'package:flutter/material.dart';

Future<bool?> showPrivacyPolicyDialog(
  BuildContext context, {
  bool requireAcceptance = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Privacy policy'),
      content: SizedBox(
        width: 480,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 440),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'PLACEHOLDER POLICY - replace with an accurate, reviewed policy before release.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 16),
                _PolicySection(
                  title: 'Information we collect',
                  body:
                      'NerdMaxxing may process account and profile details, challenge activity, messages, and evidence you submit, such as text, links, images, or videos. Google sign-in and optional connected services may provide account information.',
                ),
                _PolicySection(
                  title: 'How information is used',
                  body:
                      'Information may be used to provide the app, show your progress and profile, review challenge evidence, support groups and discussions, protect accounts, and deliver notifications you enable.',
                ),
                _PolicySection(
                  title: 'Sharing and service providers',
                  body:
                      'Information may be processed by providers that support sign-in, hosting, storage, or notifications. Public profile details and content you post in shared areas may be visible to other users.',
                ),
                _PolicySection(
                  title: 'Your choices and deletion',
                  body:
                      'You can update profile details, manage notification permissions, and request account deletion in the app. Some information may remain for a limited period where needed for security, legal, or operational reasons.',
                ),
                _PolicySection(
                  title: 'Contact',
                  body:
                      'For privacy questions, contact privacy@example.com. Replace this placeholder with the team\'s real contact address.',
                ),
                Text(
                  'This sample is illustrative only. Confirm actual data collection, retention, sharing, user rights, and contact details before publishing.',
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(requireAcceptance ? 'Not now' : 'Close'),
        ),
        if (requireAcceptance)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Agree'),
          ),
      ],
    ),
  );
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String body;

  const _PolicySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );
  }
}