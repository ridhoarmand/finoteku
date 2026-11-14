import 'package:finoteku/features/transaction/utils/transaction_screen_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final overdraws = TransactionScreenHelpers.overdraws;

  test('edit that leaves the balance as is never overdraws', () {
    expect(overdraws(50000, 50000), isFalse); // notes-only edit
    expect(overdraws(-20000, -20000), isFalse); // wallet already negative
  });

  test('an edit may not push a wallet below zero or make it worse', () {
    expect(overdraws(50000, -10000), isTrue);
    expect(overdraws(-20000, -30000), isTrue);
    expect(overdraws(-20000, -5000), isFalse); // gets better
    expect(overdraws(50000, 0), isFalse);
  });
}
