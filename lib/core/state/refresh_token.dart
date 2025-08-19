import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Generic refresh token (integer counter) to force rebuild of dependent providers.
class RefreshToken extends StateNotifier<int> {
  RefreshToken() : super(0);
  void bump() => state = state + 1;
}

typedef RefreshTokenProvider = StateNotifierProvider<RefreshToken, int>;

RefreshTokenProvider createRefreshTokenProvider() =>
    StateNotifierProvider<RefreshToken, int>((ref) => RefreshToken());
