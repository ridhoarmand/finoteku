import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finoteku/theme/ph_icons.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../models/wallet.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/wallet_icon_helper.dart';
import '../../../widgets/amount_text.dart';

/// Result of the wallet picker: [walletId] null means "all wallets".
class WalletPick {
  final String? walletId;
  const WalletPick(this.walletId);
}

/// Bottom sheet listing wallets with their balance. Returns null when dismissed.
Future<WalletPick?> showWalletPicker(
  BuildContext context, {
  required List<Wallet> wallets,
  required String? selectedId,
  bool allowAll = true,
}) {
  return showModalBottomSheet<WalletPick>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _WalletPickerSheet(wallets: wallets, selectedId: selectedId, allowAll: allowAll),
  );
}

class _WalletPickerSheet extends ConsumerWidget {
  final List<Wallet> wallets;
  final String? selectedId;
  final bool allowAll;

  const _WalletPickerSheet({required this.wallets, required this.selectedId, required this.allowAll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    Widget check(bool on) => on
        ? Icon(PhFill.checkCircle, color: theme.colorScheme.primary)
        : const SizedBox(width: 24);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(ref.tr(context, 'select_wallet_title'), style: theme.textTheme.titleLarge),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                children: [
                  if (allowAll)
                    ListTile(
                      leading: Icon(PhRegular.stack, color: theme.colorScheme.onSurface),
                      title: Text(ref.tr(context, 'all_wallets')),
                      trailing: check(selectedId == null),
                      onTap: () => Navigator.pop(context, const WalletPick(null)),
                    ),
                  for (final w in wallets)
                    ListTile(
                      leading: SizedBox(width: 32, height: 32, child: WalletIconHelper.buildIcon(w.icon, size: 32)),
                      title: Text(w.name),
                      subtitle: w.isHidden
                          ? Text(ref.tr(context, 'wallet_hidden'), style: TextStyle(color: context.colors.muted))
                          : AmountText(w.balance, style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted)),
                      trailing: check(selectedId == w.id),
                      onTap: () => Navigator.pop(context, WalletPick(w.id)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
