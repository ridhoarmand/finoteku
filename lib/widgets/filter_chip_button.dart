import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';

import '../theme/app_theme.dart';

/// A filter as a chip: shows its current value, opens a picker on tap.
/// Active chips are tinted with the accent and get their own clear (×) button.
class FilterChipButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String? clearTooltip;
  final IconData? icon;

  const FilterChipButton({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.onClear,
    this.clearTooltip,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = active ? scheme.onPrimaryContainer : scheme.onSurface;
    final radius = BorderRadius.circular(AppTheme.rControl);

    return Material(
      color: active ? scheme.primaryContainer : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: active ? Colors.transparent : context.colors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: EdgeInsets.only(left: 12, right: active && onClear != null ? 4 : 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                    Text(label, style: theme.textTheme.labelLarge?.copyWith(color: fg)),
                    if (!(active && onClear != null)) ...[
                      const SizedBox(width: 4),
                      Icon(PhRegular.caretDown, size: 14, color: fg),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (active && onClear != null)
            IconButton(
              tooltip: clearTooltip,
              onPressed: onClear,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: Icon(PhBold.x, size: 14, color: fg),
            ),
        ],
      ),
    );
  }
}
