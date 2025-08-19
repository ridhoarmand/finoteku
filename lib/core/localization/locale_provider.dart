import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const supportedLanguageCodes = ['en', 'id'];

class AppLocaleState {
  final Locale effectiveLocale;      // Locale used by MaterialApp
  final String contentLanguageCode;  // Language code for strings (may differ when fallback)
  const AppLocaleState({
    required this.effectiveLocale,
    required this.contentLanguageCode,
  });
}

class LocaleNotifier extends StateNotifier<AppLocaleState> {
  LocaleNotifier() : super(_detectInitial());

  static AppLocaleState _detectInitial() {
    final device = WidgetsBinding.instance.platformDispatcher.locale;
    final code = device.languageCode.toLowerCase();
    if (code == 'en') {
      return const AppLocaleState(
        effectiveLocale: Locale('en'),
        contentLanguageCode: 'en',
      );
    }
    if (code == 'id') {
      return const AppLocaleState(
        effectiveLocale: Locale('id'),
        contentLanguageCode: 'id',
      );
    }
    // Unsupported -> use Indonesian locale for formatting but English strings
    return const AppLocaleState(
      effectiveLocale: Locale('id'),
      contentLanguageCode: 'en',
    );
  }

  void setLanguage(String code) {
    if (!supportedLanguageCodes.contains(code)) return;
    state = AppLocaleState(
      effectiveLocale: Locale(code),
      contentLanguageCode: code,
    );
  }
}

final appLocaleProvider = StateNotifierProvider<LocaleNotifier, AppLocaleState>(
  (ref) => LocaleNotifier(),
);
