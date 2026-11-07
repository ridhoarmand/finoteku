import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'locale_provider.dart';
// Feature-scoped i18n modules
import '../../features/auth/i18n/strings.dart' as auth_i18n;
import '../../features/category/i18n/strings.dart' as category_i18n;
import '../../features/wallet/i18n/strings.dart' as wallet_i18n;
import '../../features/transfer/i18n/strings.dart' as transfer_i18n;
import '../../features/transaction/i18n/strings.dart' as transaction_i18n;
import '../../features/home/i18n/strings.dart' as home_i18n;
import '../../features/account/i18n/strings.dart' as account_i18n;
import '../../features/report/i18n/strings.dart' as reports_i18n;
import '../../features/onboarding/i18n/strings.dart' as onboarding_i18n;
import '../i18n/strings.dart' as core_i18n;
import '../../features/bot/i18n/strings.dart' as bot_i18n;
import '../../features/notification/i18n/strings.dart' as notification_i18n;

typedef StrMap = Map<String, String>;

final Map<String, StrMap> _strings = {
  'en': {
    // Merge all feature strings (EN)
    ...core_i18n.coreStringsEn,
    ...auth_i18n.authStringsEn,
    ...category_i18n.categoryStringsEn,
    ...wallet_i18n.walletStringsEn,
    ...transfer_i18n.transferStringsEn,
    ...transaction_i18n.transactionStringsEn,
    ...home_i18n.homeStringsEn,
    ...account_i18n.accountStringsEn,
    ...reports_i18n.reportStringsEn,
    ...onboarding_i18n.onboardingStringsEn,
    ...bot_i18n.botStringsEn,
    ...notification_i18n.notificationStringsEn,
  },
  'id': {
    // Merge all feature strings (ID)
    ...core_i18n.coreStringsId,
    ...auth_i18n.authStringsId,
    ...category_i18n.categoryStringsId,
    ...wallet_i18n.walletStringsId,
    ...transfer_i18n.transferStringsId,
    ...transaction_i18n.transactionStringsId,
    ...home_i18n.homeStringsId,
    ...account_i18n.accountStringsId,
    ...reports_i18n.reportStringsId,
    ...onboarding_i18n.onboardingStringsId,
    ...bot_i18n.botStringsId,
    ...notification_i18n.notificationStringsId,
  },
};

String _lookup(String lang, String key) {
  // Try exact match first
  final exact = _strings[lang]?[key];
  if (exact != null) return exact;

  // Fallback: try base language code (e.g., en-US -> en)
  final baseLang = lang.split('-').first;
  if (baseLang != lang) {
    final base = _strings[baseLang]?[key];
    if (base != null) return base;
  }

  // Final fallback to English to avoid showing raw keys
  return _strings['en']?[key] ?? key;
}

String translate(BuildContext context, WidgetRef ref, String key) {
  final localeState = ref.watch(appLocaleProvider);
  return _lookup(localeState.contentLanguageCode, key);
}

String translateRead(WidgetRef ref, String key) {
  final localeState = ref.read(appLocaleProvider);
  return _lookup(localeState.contentLanguageCode, key);
}

extension TranslateRef on WidgetRef {
  String tr(BuildContext context, String key) => translate(context, this, key);
  String trRead(String key) => translateRead(this, key);
}
