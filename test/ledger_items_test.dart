import 'package:finoteku/features/transaction/widgets/ledger_list.dart';
import 'package:finoteku/models/ledger_entry.dart';
import 'package:finoteku/models/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

LedgerEntry side(String kind, String wallet, String other) => LedgerEntry(
  entryId: 't1', userId: 'u', walletId: wallet, amount: 100, signedAmount: kind == 'transfer_out' ? -100 : 100,
  date: DateTime(2026, 11, 5), kind: kind, transferId: 't1', counterpartWalletId: other,
);

void main() {
  test('a transfer knows both wallets even when only one side is listed', () {
    final out = ledgerItems([side('transfer_out', 'bca', 'cash')]).single;
    expect((out.fromWalletId, out.toWalletId), ('bca', 'cash'));
    final inn = ledgerItems([side('transfer_in', 'cash', 'bca')]).single;
    expect((inn.fromWalletId, inn.toWalletId), ('bca', 'cash'));
  });

  test('both sides listed: the transfer shows once', () {
    final items = ledgerItems([side('transfer_out', 'bca', 'cash'), side('transfer_in', 'cash', 'bca')]);
    expect(items, hasLength(1));
  });

  test('day balances walk back from today, per wallet or visible total', () {
    final wallets = [w('bca', 1000), w('cash', 200), w('old', 50, hidden: true)];
    final entries = [tx('bca', -100, 14), tx('cash', 30, 14), tx('bca', 500, 12), tx('old', -10, 12)];
    // visible total now 1200; the 14th changed it by -70, the 12th by +500 (hidden wallet ignored)
    expect(dayBalances(entries, wallets, null), {DateTime(2026, 11, 14): 1200, DateTime(2026, 11, 12): 1270});
    expect(dayBalances(entries, wallets, 'bca'), {DateTime(2026, 11, 14): 1000, DateTime(2026, 11, 12): 1100});
  });
}

LedgerEntry tx(String wallet, double signed, int day) => LedgerEntry(
  entryId: '$wallet$day$signed', userId: 'u', walletId: wallet, amount: signed.abs(), signedAmount: signed,
  date: DateTime(2026, 11, day), kind: 'transaction',
);

Wallet w(String id, double balance, {bool hidden = false}) =>
    Wallet(id: id, userId: 'u', name: id, balance: balance, isHidden: hidden, createdAt: DateTime(2026), updatedAt: DateTime(2026));
