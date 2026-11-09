import 'dart:io';

import 'package:finoteku/utils/finlogos.g.dart';
import 'package:finoteku/utils/wallet_icon_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('values stored by older versions resolve to idn-finlogos assets', () {
    expect(WalletIconHelper.resolve('assets/banks/bca.svg'), 'assets/finlogos/bca.svg');
    expect(WalletIconHelper.resolve('assets/banks/blu.svg'), 'assets/finlogos/blu-bca.svg');
    expect(WalletIconHelper.resolve('assets/banks/neo.svg'), 'assets/finlogos/bnc.svg');
    expect(WalletIconHelper.resolve('assets/ewallets/sopay.svg'), 'assets/finlogos/shopee-pay.svg');
    expect(WalletIconHelper.resolve('gopay'), 'assets/finlogos/gopay.svg');
    expect(WalletIconHelper.resolve('cash'), WalletIconHelper.cashIcon);
    expect(WalletIconHelper.resolve('assets/banks/unknown.svg'), isNull);
    expect(WalletIconHelper.resolve(null), isNull);
  });

  test('every catalog entry has its svg bundled', () {
    final missing = finLogos.where((l) => !File(l.asset).existsSync()).map((l) => l.slug);
    expect(missing, isEmpty);
  });
}
