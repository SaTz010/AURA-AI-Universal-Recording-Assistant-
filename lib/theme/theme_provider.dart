import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════════════════
//  Theme Provider — InheritedNotifier-based, zero dependencies
//
//  Usage:
//    AuraThemeProvider.of(context).toggleTheme();
//    AuraThemeProvider.of(context).themeMode;
// ════════════════════════════════════════════════════════════════════════

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode;

  ThemeNotifier([this._themeMode = ThemeMode.dark]);

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  void toggleTheme() {
    setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
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
