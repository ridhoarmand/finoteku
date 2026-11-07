import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../theme/app_theme.dart';

class NotesSection extends ConsumerWidget {
  final TextEditingController controller;
  final VoidCallback? onTapOutside;

  const NotesSection({super.key, required this.controller, this.onTapOutside});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(ref.tr(context, 'notes_title'), style: theme.textTheme.labelLarge?.copyWith(color: context.colors.muted)),
        ),
        TextFormField(
          controller: controller,
          onTapOutside: (_) => onTapOutside?.call(),
          decoration: InputDecoration(hintText: ref.tr(context, 'notes_hint')),
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }
}
