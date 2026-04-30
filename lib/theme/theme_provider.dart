import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════════════════════════════════════
//  Theme Provider — InheritedNotifier-based with persistence
//
//  Usage:
//    AuraThemeProvider.of(context).toggleTheme();
//    AuraThemeProvider.of(context).themeMode;
// ════════════════════════════════════════════════════════════════════════

class ThemeNotifier extends ChangeNotifier {
  static const String _prefsKey = 'aura_theme_mode';

  ThemeMode _themeMode;

  ThemeNotifier([this._themeMode = ThemeMode.dark]);

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved == null) return;
      final mode = switch (saved) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => null,
      };
      if (mode != null && mode != _themeMode) {
        _themeMode = mode;
        notifyListeners();
      }
    } catch (_) {
      // Best effort — fall back to the in-memory default if prefs fail.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {
      // Best effort — UI already updated.
    }
  }

  Future<void> toggleTheme() {
    return setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}

class AuraThemeProvider extends InheritedNotifier<ThemeNotifier> {
  const AuraThemeProvider({
    super.key,
    required ThemeNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ThemeNotifier of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<AuraThemeProvider>();
    assert(provider != null, 'AuraThemeProvider not found in widget tree');
    return provider!.notifier!;
  }
}
