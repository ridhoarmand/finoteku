import 'package:flutter/material.dart';
import 'package:finoteku/theme/ph_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const String _prefsKey = 'theme_mode';

  /// Saved choice, read by [preload] in main() before runApp: the first frame already
  /// has the right theme instead of flashing light and then switching.
  static int? _saved;

  static Future<void> preload() async {
    try {
      _saved = (await SharedPreferences.getInstance()).getInt(_prefsKey);
    } catch (_) {
      // unreadable preferences: keep the default (light)
    }
  }

  @override
  ThemeMode build() {
    final i = _saved;
    return i != null && i >= 0 && i < ThemeMode.values.length ? ThemeMode.values[i] : ThemeMode.light;
  }

  Future<void> _saveThemePreference(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey, mode.index);
    } catch (e) {
      // Handle save error silently
    }
  }

  void toggleTheme() {
    switch (state) {
      case ThemeMode.light:
        setDarkMode();
        break;
      case ThemeMode.dark:
        setSystemMode();
        break;
      case ThemeMode.system:
        setLightMode();
        break;
    }
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    _saveThemePreference(mode);
  }

  void setLightMode() {
    state = ThemeMode.light;
    _saveThemePreference(state);
  }

  void setDarkMode() {
    state = ThemeMode.dark;
    _saveThemePreference(state);
  }

  void setSystemMode() {
    state = ThemeMode.system;
    _saveThemePreference(state);
  }

  String get themeText {
    switch (state) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  IconData get themeIcon {
    switch (state) {
      case ThemeMode.light:
        return PhRegular.sun;
      case ThemeMode.dark:
        return PhRegular.moon;
      case ThemeMode.system:
        return PhRegular.circleHalf;
    }
  }
}
