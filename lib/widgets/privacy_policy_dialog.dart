import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _privacyPolicyUri = 'https://www.nerdmaxxing.com/privacy';

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Read the NerdMaxxing privacy policy online.'),
            TextButton.icon(
              onPressed: () async {
                final opened = await launchUrl(
                  Uri.parse(_privacyPolicyUri),
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && context.mounted) {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(
                      content: Text('Could not open the privacy policy.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('www.nerdmaxxing.com/privacy'),
            ),
          ],
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
