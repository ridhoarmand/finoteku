import 'package:flutter_riverpod/flutter_riverpod.dart';

// A simple notifier that bumps an integer to trigger refreshes
class RefreshToken extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

typedef RefreshTokenProvider = NotifierProvider<RefreshToken, int>;

RefreshTokenProvider refreshTokenProvider() =>
    NotifierProvider<RefreshToken, int>(RefreshToken.new);
