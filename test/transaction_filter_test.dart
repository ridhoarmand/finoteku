import 'package:finoteku/features/transaction/providers/transaction_filter.dart';
import 'package:finoteku/models/category.dart';
import 'package:finoteku/models/ledger_entry.dart';
import 'package:finoteku/models/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime(2026, 1, 1);
Category cat(String id, String name, CategoryType type, [String? parent]) => Category(
  id: id, userId: 'u', name: name, type: type, parentId: parent, createdAt: t0, updatedAt: t0,
);
LedgerEntry e(String id, double signed, {String? cat, String wallet = 'cash', String? notes, String? transfer}) => LedgerEntry(
  entryId: id, userId: 'u', walletId: wallet, categoryId: cat, amount: signed.abs(), signedAmount: signed,
  date: DateTime(2026, 11, 5), notes: notes, kind: transfer == null ? 'transaction' : (signed < 0 ? 'transfer_out' : 'transfer_in'),
  transferId: transfer,
);

void main() {
  final cats = [
    cat('trans', 'Transportasi', CategoryType.expense),
    cat('bensin', 'Bensin', CategoryType.expense, 'trans'),
    cat('makan', 'Makanan', CategoryType.expense),
    cat('gaji', 'Gaji', CategoryType.income),
  ];
  final wallets = [
    Wallet(id: 'cash', userId: 'u', name: 'Cash', balance: 0, createdAt: t0, updatedAt: t0),
    Wallet(id: 'gopay', userId: 'u', name: 'Gopay', balance: 0, createdAt: t0, updatedAt: t0),
  ];
  final entries = [
    e('1', -30000, cat: 'bensin', notes: 'Pertalite'),
    e('2', -25000, cat: 'makan', notes: 'Kopi susu', wallet: 'gopay'),
    e('3', 8500000, cat: 'gaji'),
    e('4', -100000, transfer: 't1'),
    e('5', 100000, transfer: 't1', wallet: 'gopay'),
    e('6', -5000, cat: 'trans', notes: 'Parkir'),
  ];
  List<String> ids(TxFilter f) => applyTxFilter(entries, f, cats, wallets).map((x) => x.entryId).toList();

  test('kind', () {
    expect(ids(const TxFilter(kind: TxKind.expense)), ['1', '2', '6']);
    expect(ids(const TxFilter(kind: TxKind.income)), ['3']);
    expect(ids(const TxFilter(kind: TxKind.transfer)), ['4', '5']);
  });

  test('category includes subcategories unless switched off', () {
    expect(ids(const TxFilter(categoryId: 'trans')), ['1', '6']);
    expect(ids(const TxFilter(categoryId: 'trans', includeSubcategories: false)), ['6']);
  });

  test('search: every word must match notes, category, parent or wallet', () {
    expect(ids(const TxFilter(query: 'kopi gopay')), ['2']);
    expect(ids(const TxFilter(query: 'transportasi')), ['1', '6']); // parent name finds the child
    expect(ids(const TxFilter(query: '8500000')), ['3']);
  });

  test('period ranges', () {
    final now = DateTime(2026, 1, 10, 15);
    expect(const TxFilter().range(now), (start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 10)));
    expect(const TxFilter(period: TxPeriod.lastMonth).range(now), (start: DateTime(2025, 12, 1), end: DateTime(2025, 12, 31)));
    expect(const TxFilter(period: TxPeriod.last7Days).range(now).start, DateTime(2026, 1, 4));
    expect(const TxFilter(period: TxPeriod.all).range(now), (start: null, end: null));
  });

  test('active count ignores the default period and the search text', () {
    expect(const TxFilter(query: 'x').activeCount, 0);
    expect(const TxFilter(kind: TxKind.income, walletId: 'cash').activeCount, 2);
    expect(const TxFilter().copyWith(categoryId: 'makan').copyWith(categoryId: null).categoryId, isNull);
  });
}
