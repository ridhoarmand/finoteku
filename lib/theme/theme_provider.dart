import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const String _prefsKey = 'theme_mode';

  @override
  ThemeMode build() {
    // Load saved theme preference asynchronously
    _loadThemePreference();
    return ThemeMode.light;
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThemeModeIndex = prefs.getInt(_prefsKey);
      if (savedThemeModeIndex != null &&
          savedThemeModeIndex >= 0 &&
          savedThemeModeIndex < ThemeMode.values.length) {
        state = ThemeMode.values[savedThemeModeIndex];
      }
    } catch (e) {
      // If error loading preferences, keep default (light)
      state = ThemeMode.light;
    }
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
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }
}
