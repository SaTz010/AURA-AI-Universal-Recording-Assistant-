import 'package:flutter/material.dart';
import 'screens/history_screen.dart';
import 'screens/initial_animation.dart';
import 'screens/home_screen.dart';
import 'screens/placeholder_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/recordings_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/summary_screen.dart';
import 'theme/aura_theme.dart';
import 'theme/theme_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _themeNotifier = ThemeNotifier(ThemeMode.dark);

  @override
  void dispose() {
    _themeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuraThemeProvider(
      notifier: _themeNotifier,
      child: AnimatedBuilder(
        animation: _themeNotifier,
        builder: (context, _) {
          return MaterialApp(
            title: 'AURA',
            debugShowCheckedModeBanner: false,
            theme: buildAuraLightTheme(),
            darkTheme: buildAuraDarkTheme(),
            themeMode: _themeNotifier.themeMode,
            home: const AuraSplashScreen(),
            routes: {
              '/home': (context) => const HomeScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/summary': (context) => const SummaryScreen(),
              '/recordings': (context) => const RecordingsScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/history': (context) => const HistoryScreen(),
              '/about': (context) => const AboutScreen(),
              '/logout': (context) => const LogoutScreen(),
            },
          );
        },
      ),
    );
  }
}
