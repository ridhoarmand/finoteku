import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WalletIconHelper {
  // Available bank icons
  static const List<String> bankIcons = [
    'assets/banks/bca.svg',
    'assets/banks/blu.svg',
    'assets/banks/bni.svg',
    'assets/banks/bri.svg',
    'assets/banks/bsi.svg',
    'assets/banks/btn.svg',
    'assets/banks/cimb.svg',
    'assets/banks/jago.svg',
    'assets/banks/mandiri.svg',
    'assets/banks/maybank.svg',
    'assets/banks/neo.svg',
    'assets/banks/seabank.svg',
    'assets/banks/superbank.svg',
  ];

  // Available e-wallet icons
  static const List<String> ewalletIcons = [
    'assets/ewallets/dana.svg',
    'assets/ewallets/doku.svg',
    'assets/ewallets/gopay.svg',
    'assets/ewallets/linkaja.svg',
    'assets/ewallets/ovo.svg',
    'assets/ewallets/sopay.svg',
  ];

  // Available wallet icons
  static const List<String> walletIcons = ['assets/wallets/cash.svg'];

  // All available icons combined
  static List<String> get allIcons => [
    ...bankIcons,
    ...ewalletIcons,
    ...walletIcons,
  ];

  // Get display name from icon path
  static String getIconDisplayName(String iconPath) {
    final fileName = iconPath.split('/').last.split('.').first;
    return fileName.toUpperCase();
  }

  // Get category from icon path
  static String getIconCategory(String iconPath) {
    if (iconPath.contains('banks/')) {
      return 'Bank';
    } else if (iconPath.contains('ewallets/')) {
      return 'E-Wallet';
    }
    return 'Other';
  }

  // Build icon widget from path
  static Widget buildIcon(
    String? iconPath, {
    double size = 24.0,
    Color? color,
  }) {
    if (iconPath == null || iconPath.isEmpty) {
      return Icon(Icons.account_balance_wallet, size: size, color: color);
    }

    // Convert short name to full path if needed
    String fullPath = iconPath;
    if (!iconPath.contains('/') && !iconPath.contains('.svg')) {
      // Check if it's a known wallet icon
      if (iconPath == 'cash') {
        fullPath = 'assets/wallets/cash.svg';
      } else {
        // Check if it exists in banks or ewallets
        final bankPath = 'assets/banks/$iconPath.svg';
        final ewalletPath = 'assets/ewallets/$iconPath.svg';

        if (bankIcons.contains(bankPath)) {
          fullPath = bankPath;
        } else if (ewalletIcons.contains(ewalletPath)) {
          fullPath = ewalletPath;
        }
      }
    }

    try {
      return SvgPicture.asset(
        fullPath,
        width: size,
        height: size,
        // Temporarily remove colorFilter to test if it's causing issues
        // colorFilter: color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
        fit: BoxFit.contain,
        placeholderBuilder: (BuildContext context) {
          return Icon(_getIconDataFromPath(fullPath), size: size, color: color);
        },
      );
    } catch (e) {
      // If asset loading fails, return default icon
      return Icon(_getIconDataFromPath(fullPath), size: size, color: color);
    }
  }

  // Get appropriate Material Icon based on asset path as fallback
  static IconData _getIconDataFromPath(String path) {
    if (path.contains('banks/')) {
      return Icons.account_balance;
    } else if (path.contains('ewallets/')) {
      if (path.contains('dana') ||
          path.contains('gopay') ||
          path.contains('ovo')) {
        return Icons.phone_android;
      }
      return Icons.account_balance_wallet;
    } else if (path.contains('cash')) {
      return Icons.payments;
    }
    return Icons.account_balance_wallet;
  }

  // Build icon selection grid
  static Widget buildIconSelectionGrid({
    required String? selectedIcon,
    required Function(String) onIconSelected,
    double iconSize = 40.0,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bank Icons Section
          const Text(
            'Bank Icons',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 0.85, // Slightly taller for text
            ),
            itemCount: bankIcons.length,
            itemBuilder: (context, index) {
              final iconPath = bankIcons[index];
              final isSelected = selectedIcon == iconPath;

              return GestureDetector(
                onTap: () => onIconSelected(iconPath),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1)
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: buildIcon(iconPath, size: iconSize * 0.55),
                        ),
                        const SizedBox(height: 2),
                        Flexible(
                          child: Text(
                            getIconDisplayName(iconPath),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // E-Wallet Icons Section
          const Text(
            'E-Wallet Icons',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 0.85, // Slightly taller for text
            ),
            itemCount: ewalletIcons.length,
            itemBuilder: (context, index) {
              final iconPath = ewalletIcons[index];
              final isSelected = selectedIcon == iconPath;

              return GestureDetector(
                onTap: () => onIconSelected(iconPath),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1)
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: buildIcon(iconPath, size: iconSize * 0.55),
                        ),
                        const SizedBox(height: 2),
                        Flexible(
                          child: Text(
                            getIconDisplayName(iconPath),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
