import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'locale_provider.dart';
// Feature-scoped i18n modules
import '../../features/category/i18n/strings.dart' as category_i18n;
import '../../features/wallet/i18n/strings.dart' as wallet_i18n;
import '../../features/transfer/i18n/strings.dart' as transfer_i18n;
import '../../features/transaction/i18n/strings.dart' as transaction_i18n;
import '../../features/home/i18n/strings.dart' as home_i18n;
import '../../features/account/i18n/strings.dart' as account_i18n;
import '../../features/chart/i18n/strings.dart' as chart_i18n;
import '../i18n/strings.dart' as core_i18n;

typedef StrMap = Map<String, String>;

final Map<String, StrMap> _strings = {
  'en': {
    // Merge all feature strings (EN)
    ...core_i18n.coreStringsEn,
    ...category_i18n.categoryStringsEn,
    ...wallet_i18n.walletStringsEn,
    ...transfer_i18n.transferStringsEn,
    ...transaction_i18n.transactionStringsEn,
    ...home_i18n.homeStringsEn,
    ...account_i18n.accountStringsEn,
    ...chart_i18n.chartStringsEn,
  },
  'id': {
    // Merge all feature strings (ID)
    ...core_i18n.coreStringsId,
    ...category_i18n.categoryStringsId,
    ...wallet_i18n.walletStringsId,
    ...transfer_i18n.transferStringsId,
    ...transaction_i18n.transactionStringsId,
    ...home_i18n.homeStringsId,
    ...account_i18n.accountStringsId,
    ...chart_i18n.chartStringsId,
  },
};

String translate(BuildContext context, WidgetRef ref, String key) {
  final localeState = ref.watch(appLocaleProvider);
  final lang = localeState.contentLanguageCode;
  return _strings[lang]?[key] ?? key;
}

extension TranslateRef on WidgetRef {
  String tr(BuildContext context, String key) => translate(context, this, key);
}
