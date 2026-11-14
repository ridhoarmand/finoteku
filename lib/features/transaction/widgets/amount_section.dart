import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/thousand_separator_formatter.dart';

/// The amount as the screen's focal number: large tabular digits, "Rp" small and muted.
class AmountSection extends ConsumerWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final VoidCallback onTapOutside;
  final String labelKey;
  final String prefix;
  final bool allowZero; // e.g. a wallet's opening balance; empty means 0
  const AmountSection({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onTapOutside,
    this.labelKey = 'amount_title',
    this.prefix = 'Rp',
    this.allowZero = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = context.colors.muted;
    final big = theme.textTheme.displaySmall!.copyWith(fontFeatures: tabularFigures);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ref.tr(context, labelKey), style: theme.textTheme.labelLarge?.copyWith(color: muted)),
        TextFormField(
          focusNode: focusNode,
          controller: controller,
          style: big,
          cursorColor: theme.colorScheme.primary,
          decoration: InputDecoration(
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            hintText: '0',
            hintStyle: big.copyWith(color: muted.withValues(alpha: 0.6)),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(right: 8, top: 10),
              child: Text(prefix, style: theme.textTheme.titleLarge?.copyWith(color: muted)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => onSubmitted(),
          onTapOutside: (_) => onTapOutside(),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            ThousandSeparatorFormatter(),
          ],
          validator: (value) {
            if (allowZero) return null; // digits only, so any value parses
            if (value?.isEmpty ?? true) {
              return ref.tr(context, 'amount_validation_empty');
            }
            final amount = double.tryParse(value!.trim().replaceAll('.', ''));
            if (amount == null || amount <= 0) {
              return ref.tr(context, 'amount_validation_invalid');
            }
            return null;
          },
        ),
        Divider(color: theme.colorScheme.outlineVariant),
      ],
    );
  }
}
