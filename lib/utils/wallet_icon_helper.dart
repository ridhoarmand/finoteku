import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import 'finlogos.g.dart';

/// Wallet icons: bank / e-wallet logos from idn-finlogos (assets/finlogos), plus cash.
/// `wallets.icon` stores an asset path; values written by older versions
/// (assets/banks/x.svg, assets/ewallets/x.svg, or a bare name) still resolve.
class WalletIconHelper {
  static const cashIcon = 'assets/wallets/cash.svg';

  static final Map<String, FinLogo> _bySlug = {for (final l in finLogos) l.slug: l};

  // old file names that differ from the idn-finlogos slug
  static const _legacy = {'blu': 'blu-bca', 'cimb': 'cimb-niaga', 'neo': 'bnc', 'sopay': 'shopee-pay'};

  /// Asset path for any stored value, or null when it is not a known icon.
  static String? resolve(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    if (stored == 'cash' || stored == cashIcon) return cashIcon;
    if (stored.startsWith('assets/finlogos/')) return stored;
    final name = stored.split('/').last.replaceAll('.svg', '');
    final slug = _legacy[name] ?? name;
    return _bySlug[slug]?.asset;
  }

  static FinLogo? logoFor(String? stored) {
    final path = resolve(stored);
    if (path == null || !path.startsWith('assets/finlogos/')) return null;
    return _bySlug[path.split('/').last.replaceAll('.svg', '')];
  }

  /// Logos (cash included) sit on a light plate in both themes: brand marks are drawn for white,
  /// and many (BCA blue, Mandiri navy) vanish on a dark surface. In dark mode the
  /// plate is a dimmed off-white so it does not glare.
  static Widget buildIcon(String? stored, {double size = 24.0, Color? color}) {
    final path = resolve(stored);
    if (path == null) return Icon(PhRegular.wallet, size: size, color: color);
    return Builder(
      builder: (context) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * 0.12),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFFECEAE5) : Colors.white,
            borderRadius: BorderRadius.circular(size * 0.24),
            border: dark ? null : Border.all(color: context.colors.hairline),
          ),
          child: SvgPicture.asset(
            path,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => Icon(PhRegular.bank, size: size * 0.6, color: Colors.black54),
          ),
        );
      },
    );
  }

  /// Searchable logo picker (name, alias, bank code); [onIconSelected] gets the asset path.
  static Widget buildIconSelectionGrid({
    required String? selectedIcon,
    required void Function(String) onIconSelected,
    double iconSize = 40.0,
  }) => _WalletLogoPicker(selected: resolve(selectedIcon), onPick: onIconSelected);
}

class _WalletLogoPicker extends StatefulWidget {
  final String? selected;
  final void Function(String) onPick;
  const _WalletLogoPicker({required this.selected, required this.onPick});

  @override
  State<_WalletLogoPicker> createState() => _WalletLogoPickerState();
}

class _WalletLogoPickerState extends State<_WalletLogoPicker> {
  String _query = '';
  String? _category; // null = all

  static const _categories = {'bank-logo': 'Bank', 'e-wallet': 'E-Wallet', 'prepaid-card': 'Uang Elektronik'};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final logos = finLogos.where((l) {
      if (_category != null && l.category != _category) return false;
      if (q.isEmpty) return true;
      return l.name.toLowerCase().contains(q) || l.slug.contains(q) || l.aliases.any((a) => a.contains(q));
    }).toList();
    final showCash = _category == null && (q.isEmpty || 'cash tunai uang'.contains(q));

    Widget cell(String path, String label) {
      final on = widget.selected == path;
      return Material(
        color: on ? theme.colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.rControl),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.rControl),
          onTap: () => widget.onPick(path),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                WalletIconHelper.buildIcon(path, size: 44),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: on ? theme.colorScheme.onPrimaryContainer : null,
                    fontWeight: on ? FontWeight.w700 : null,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(PhRegular.magnifyingGlass),
            hintText: 'Cari bank atau e-wallet',
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final e in [const MapEntry<String?, String>(null, 'Semua'), ..._categories.entries])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _category == e.key,
                    onSelected: (_) => setState(() => _category = e.key),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Flexible(
          child: logos.isEmpty && !showCash
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Tidak ada logo untuk "$_query"',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: context.colors.muted),
                  ),
                )
              : GridView(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 96,
                    mainAxisExtent: 108,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  children: [
                    if (showCash) cell(WalletIconHelper.cashIcon, 'Tunai'),
                    for (final l in logos) cell(l.asset, l.name),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        Text(
          'Logo: idn-finlogos (CC BY-NC 4.0). Merek milik pemiliknya masing-masing.',
          style: theme.textTheme.labelSmall?.copyWith(color: context.colors.muted),
        ),
      ],
    );
  }
}
