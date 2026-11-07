import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/app_localizations.dart';

/// Compact "something went wrong + Retry" row for sections inside a screen,
/// so a failed load is visible instead of the section silently disappearing.
class InlineError extends ConsumerWidget {
  final VoidCallback onRetry;

  const InlineError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ref.tr(context, 'something_went_wrong'),
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(ref.tr(context, 'retry'))),
        ],
      ),
    );
  }
}
