import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global provider to control whether balances are visible or hidden across screens.
class BalanceVisibility extends Notifier<bool> {
  @override
  bool build() => true;
  
  void toggle() => state = !state;
  void show() => state = true;
  void hide() => state = false;
}

final balanceVisibilityProvider = NotifierProvider<BalanceVisibility, bool>(
  BalanceVisibility.new,
);
