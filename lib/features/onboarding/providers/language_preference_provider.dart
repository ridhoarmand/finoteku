import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/user_service.dart';

// Provider to check if user has selected a language preference
final hasLanguagePreferenceProvider = FutureProvider<bool>((ref) async {
  // Keep provider alive to prevent multiple loads
  ref.keepAlive();

  try {
    final userService = ref.read(userServiceProvider);
    final preference = await userService.getLanguagePreference();
    return preference != null;
  } catch (e) {
    // On error, assume no language preference set
    return false;
  }
});

// Provider to get the current language preference
final languagePreferenceProvider = FutureProvider<String?>((ref) async {
  // Keep provider alive to prevent multiple loads
  ref.keepAlive();

  try {
    final userService = ref.read(userServiceProvider);
    return await userService.getLanguagePreference();
  } catch (e) {
    // On error, return null
    return null;
  }
});
