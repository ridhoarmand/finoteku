import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/user_service.dart';

// Provider to check if user has selected a language preference
final hasLanguagePreferenceProvider = FutureProvider<bool>((ref) async {
  final userService = ref.read(userServiceProvider);
  final preference = await userService.getLanguagePreference();
  return preference != null;
});

// Provider to get the current language preference
final languagePreferenceProvider = FutureProvider<String?>((ref) async {
  final userService = ref.read(userServiceProvider);
  return await userService.getLanguagePreference();
});