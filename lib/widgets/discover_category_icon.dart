import 'package:flutter/material.dart';

import '../models/discover.dart';
import '../theme/app_theme.dart';

class DiscoverCategoryIcon extends StatelessWidget {
  final DiscoverCategory category;
  final double size;

  const DiscoverCategoryIcon({
    super.key,
    required this.category,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final (iconColor, _) = DiscoverPalette.topicColors(
      category.name,
      brightness,
    );

    return Icon(
      _iconForCategory(category),
      color: iconColor,
      size: size,
    );
  }

  static IconData _iconForCategory(DiscoverCategory category) {
    final value = '${category.name} ${category.slug}'.toLowerCase();
    if (value.contains('brain') ||
        value.contains('memory') ||
        value.contains('mind')) {
      return Icons.psychology_rounded;
    }
    if (value.contains('game') ||
        value.contains('chess') ||
        value.contains('puzzle')) {
      return Icons.sports_esports_rounded;
    }
    if (value.contains('fitness') ||
        value.contains('sport') ||
        value.contains('strength') ||
        value.contains('workout')) {
      return Icons.fitness_center_rounded;
    }
    if (value.contains('cook') ||
        value.contains('food') ||
        value.contains('kitchen')) {
      return Icons.restaurant_rounded;
    }
    if (value.contains('code') ||
        value.contains('tech') ||
        value.contains('program')) {
      return Icons.code_rounded;
    }
    if (value.contains('art') || value.contains('design')) {
      return Icons.palette_rounded;
    }
    if (value.contains('music')) return Icons.music_note_rounded;
    if (value.contains('science')) return Icons.science_rounded;
    if (value.contains('read') ||
        value.contains('write') ||
        value.contains('language')) {
      return Icons.menu_book_rounded;
    }
    return Icons.auto_awesome_rounded;
  }
}
