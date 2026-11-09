import 'package:flutter/material.dart';
import '../../../widgets/amount_text.dart';
import '../../../theme/app_theme.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/wallet.dart';
import '../../../utils/wallet_icon_helper.dart';
import '../../../core/localization/app_localizations.dart';

class WalletCard extends ConsumerWidget {
  final Wallet wallet;
  final VoidCallback onTap;
  final void Function(String action) onAction;

  const WalletCard({
    super.key,
    required this.wallet,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Material (not a decorated Container) so the ListTile's tap ripple stays visible.
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: ListTile(
          leading: SizedBox(
            width: 40,
            height: 40,
            child: WalletIconHelper.buildIcon(wallet.icon, size: 40),
          ),
          title: Text(
            wallet.name,
            style: theme.textTheme.titleSmall?.copyWith(
              color: !wallet.isHidden
                  ? null
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AmountText(
                  wallet.balance,
                  tone: wallet.balance < 0 ? AmountTone.expense : AmountTone.neutral,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                // currency only when it is not the default rupiah
                if (wallet.currency != 'IDR')
                  Text(wallet.currency, style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted)),
                if (wallet.isHidden)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhRegular.eyeSlash, size: 14, color: context.colors.muted),
                      const SizedBox(width: 4),
                      Text(
                        ref.tr(context, 'wallet_hidden'),
                        style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: onAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(PhRegular.pencilSimple),
                    const SizedBox(width: 8),
                    Text(ref.tr(context, 'edit')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: !wallet.isHidden ? 'deactivate' : 'activate',
                child: Row(
                  children: [
                    Icon(
                      !wallet.isHidden
                          ? PhRegular.eyeSlash
                          : PhRegular.eye,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      !wallet.isHidden
                          ? ref.tr(context, 'wallet_hide')
                          : ref.tr(context, 'wallet_unhide'),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(PhRegular.trash, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Text(
                      ref.tr(context, 'delete'),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
