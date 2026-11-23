import 'package:finoteku/models/ledger_entry.dart';
import 'package:finoteku/models/wallet.dart';
import 'package:finoteku/services/home_widget_service.dart';
import 'package:flutter_test/flutter_test.dart';

LedgerEntry e(String wallet, double signed, DateTime date, {String? transfer}) => LedgerEntry(
  entryId: '$wallet$signed$date', userId: 'u', walletId: wallet, amount: signed.abs(), signedAmount: signed,
  date: date, kind: transfer == null ? 'transaction' : 'transfer_out', transferId: transfer,
);

Wallet w(String id, double balance, {bool hidden = false}) =>
    Wallet(id: id, userId: 'u', name: id, balance: balance, isHidden: hidden, createdAt: DateTime(2026), updatedAt: DateTime(2026));

void main() {
  final now = DateTime(2026, 11, 23, 20);
  final today = DateTime(2026, 11, 23);
  final wallets = [w('bca', 1000), w('cash', 200), w('old', 50, hidden: true)];

  test('today spending: expenses on visible wallets today only', () {
    final s = widgetSnapshot([
      e('bca', -100, today),
      e('cash', -30, today),
      e('cash', 500, today), // income
      e('bca', -40, today, transfer: 't1'), // transfer
      e('old', -10, today), // hidden wallet
      e('bca', -70, DateTime(2026, 11, 22)), // yesterday
    ], wallets, now);
    expect(s.todayExpense, 130);
    expect(s.balance, 1200);
    expect(s.lastEntry, today);
  });

  test('no entries: nothing recorded yet', () {
    final s = widgetSnapshot([], wallets, now);
    expect((s.todayExpense, s.lastEntry), (0.0, null));
  });
}
