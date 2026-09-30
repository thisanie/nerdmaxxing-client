import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DifficultyBadge extends StatelessWidget {
  final String level;
  const DifficultyBadge({super.key, required this.level});

  String get _label {
    switch (level) {
      case 'BEGINNER':
        return 'Beginner';
      case 'INTERMEDIATE':
        return 'Intermediate';
      case 'ADVANCED':
        return 'Advanced';
      default:
        return level;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (fg, bg) = isDark
        ? (
            AppTheme.difficultyColor(level),
            AppTheme.difficultyColor(level).withValues(alpha: 0.15),
          )
        : switch (level) {
            'BEGINNER' => (const Color(0xFF2E6B3A), const Color(0xFFE3EFE0)),
            'INTERMEDIATE' => (const Color(0xFF8A5A00), const Color(0xFFFFEBC2)),
            'ADVANCED' => (const Color(0xFFB3321E), const Color(0xFFFFE0D9)),
            _ => (AppColors.lightTextSecondary, AppColors.lightSurfaceAlt),
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(_label, style: TextStyle(color: fg, fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }
}
