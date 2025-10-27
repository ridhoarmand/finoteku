import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final onboardingProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);

class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Keep provider alive to prevent multiple loads
    ref.keepAlive();
    // Defer async operation to avoid blocking constructor
    Future.microtask(() => _loadOnboardingStatus());
    return false;
  }

  Future<void> _loadOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool('hasSeenOnboarding') ?? false;
    } catch (e) {
      // If error loading preferences, assume first time user
      state = false;
    }
  }

  Future<void> setOnboardingComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasSeenOnboarding', true);
      state = true;
    } catch (e) {
      // Handle error but still set state to true locally
      state = true;
    }
  }

  Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasSeenOnboarding', false);
      state = false;
    } catch (e) {
      // Handle error but still set state to false locally
      state = false;
    }
  }
}
