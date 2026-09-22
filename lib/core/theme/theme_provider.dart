import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

final themeSeedColorProvider = NotifierProvider<ThemeSeedColorNotifier, Color>(
  ThemeSeedColorNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    _loadTheme();
    return ThemeMode.light;
  }

  Future<void> _loadTheme() async {
    final prefs = SharedPreferencesAsync();
    final saved = await prefs.getString(_key);

    state = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;

    final prefs = SharedPreferencesAsync();

    await prefs.setString(_key, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> toggle() async {
    await setThemeMode(
      state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}

class ThemeSeedColorNotifier extends Notifier<Color> {
  static const _key = 'theme_seed_color';

  static const Color defaultColor = Color(0xFF334155);

  @override
  Color build() {
    _loadColor();
    return defaultColor;
  }

  Future<void> _loadColor() async {
    final prefs = SharedPreferencesAsync();
    final saved = await prefs.getInt(_key);

    if (saved != null) {
      state = Color(saved);
    }
  }

  Future<void> setColor(Color color) async {
    state = color;

    final prefs = SharedPreferencesAsync();

    await prefs.setInt(_key, color.toARGB32());
  }
}
