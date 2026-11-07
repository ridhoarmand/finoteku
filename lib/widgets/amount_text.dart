import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

enum AmountTone { neutral, income, expense, transfer }

final _digits = NumberFormat('#,##0', 'id_ID');

/// The identity motif (DESIGN.md): the number leads, "Rp" sits smaller and muted
/// in front of it, figures are tabular so amounts line up in lists.
class AmountText extends StatelessWidget {
  final double amount;
  final AmountTone tone;
  final TextStyle? style;

  /// Prefix "+" / "−" by tone (income +, expense −).
  final bool signed;

  /// Replace digits with dots (balance hidden).
  final bool hidden;

  const AmountText(
    this.amount, {
    super.key,
    this.tone = AmountTone.neutral,
    this.style,
    this.signed = false,
    this.hidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final base = (style ?? theme.textTheme.titleMedium!).copyWith(fontFeatures: tabularFigures);
    final color = switch (tone) {
      AmountTone.income => colors.income,
      AmountTone.expense => colors.expense,
      AmountTone.transfer => theme.colorScheme.primary,
      AmountTone.neutral => base.color ?? theme.colorScheme.onSurface,
    };
    final sign = !signed
        ? (amount < 0 ? '−' : '')
        : switch (tone) {
            AmountTone.income => '+',
            AmountTone.expense => '−',
            _ => amount < 0 ? '−' : '',
          };
    final number = hidden ? '••••••' : _digits.format(amount.abs());
    final size = base.fontSize ?? 16;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: sign, style: base.copyWith(color: color)),
          TextSpan(
            text: 'Rp ',
            style: base.copyWith(
              // a small "Rp" only reads well next to big numbers; in rows keep it legible
              fontSize: size * (size >= 24 ? 0.6 : 0.82),
              fontWeight: FontWeight.w600,
              color: tone == AmountTone.neutral ? colors.muted : color,
            ),
          ),
          TextSpan(text: number, style: base.copyWith(color: color)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      semanticsLabel: hidden ? 'Saldo disembunyikan' : '$sign Rp $number',
    );
  }
}
