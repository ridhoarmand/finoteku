import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Square icon tile in a category/feature colour: a light tint behind a
/// darker glyph, so pale hues (yellow, aqua) still read on white.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double radius;

  const IconTile(this.icon, {super.key, required this.color, this.size = 40, this.radius = AppTheme.rControl});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        icon,
        size: size * 0.55,
        color: dark ? Color.lerp(color, Colors.white, 0.25) : Color.lerp(color, Colors.black, 0.3),
      ),
    );
  }
}
