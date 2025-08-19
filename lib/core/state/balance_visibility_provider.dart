import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global provider to control whether balances are visible or hidden across screens.
final balanceVisibilityProvider = StateProvider<bool>((ref) => true);
