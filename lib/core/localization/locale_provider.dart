import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  LocaleNotifier() : super(_detectInitial()) {
    _loadSaved();
  }

  static const _prefsKey = 'app_locale_code';

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && supportedLanguageCodes.contains(saved)) {
        state = AppLocaleState(
          effectiveLocale: Locale(saved),
          contentLanguageCode: saved,
        );
      }
    } catch (_) {
      // ignore storage errors, keep detected initial
    }
  }

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

  Future<void> setLanguage(String code) async {
    if (!supportedLanguageCodes.contains(code)) return;
    state = AppLocaleState(
      effectiveLocale: Locale(code),
      contentLanguageCode: code,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, code);
    } catch (_) {
      // ignore storage errors
    }
  }
}

final appLocaleProvider = StateNotifierProvider<LocaleNotifier, AppLocaleState>(
  (ref) => LocaleNotifier(),
);
