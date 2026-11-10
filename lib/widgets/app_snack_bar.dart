import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart' hide SnackBar;

import '../theme/app_theme.dart';

/// Drop-in replacement for Material's SnackBar so every alert shares one look.
/// Files import Material with `hide SnackBar` and use this instead.
class SnackBar extends m.SnackBar {
  const SnackBar({super.key, required Widget content, super.action})
    : super(
        content: _Toast(content),
        behavior: m.SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(26, 0, 26, 24),
        dismissDirection: DismissDirection.horizontal,
        duration: const Duration(seconds: 4),
      );
}

class _Toast extends StatelessWidget {
  const _Toast(this.content);

  final Widget content;

  static final _errorWords = RegExp(
    r"could not|couldn't|cannot|can't|unavailable|went wrong|offline|failed|error|try again",
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = content is Text ? (content as Text).data ?? '' : '';
    final isError = _errorWords.hasMatch(text);

    final bg = dark ? const Color(0xFF1C1C1C) : const Color(0xFF111111);
    final accent = isError ? AppColors.danger : AppColors.primary;
    final icon = isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle.merge(
              style: AppFonts.body(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              child: content,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
