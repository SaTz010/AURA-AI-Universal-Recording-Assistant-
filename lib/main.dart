import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'screens/auth_screen.dart';
import 'screens/app_entry.dart';
import 'screens/legal_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/storage_settings_screen.dart';
import 'screens/main_tabs_screen.dart';
import 'providers/auth_provider.dart';
import 'services/notification_preferences.dart';
import 'theme/aura_theme.dart';
import 'theme/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  await _ensureFirebaseInitialized();
  runApp(const MyApp());
}

Future<FirebaseApp> _ensureFirebaseInitialized() async {
  try {
    return await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (error) {
    if (error.code == 'duplicate-app') {
      return Firebase.app();
    }
    rethrow;
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _themeNotifier = ThemeNotifier(ThemeMode.dark);
  final _authNotifier = AuthProvider();

  @override
  void initState() {
    super.initState();
    _authNotifier.initialize();
    _themeNotifier.loadSavedTheme();
    NotificationPreferences.instance.load();
  }

  @override
  void dispose() {
    _authNotifier.dispose();
    _themeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuraAuthProvider(
      notifier: _authNotifier,
      child: AuraThemeProvider(
        notifier: _themeNotifier,
        child: AnimatedBuilder(
          animation: Listenable.merge([_themeNotifier, _authNotifier]),
          builder: (context, _) {
            return MaterialApp(
              title: 'AURA',
              debugShowCheckedModeBanner: false,
              theme: buildAuraLightTheme(),
              darkTheme: buildAuraDarkTheme(),
              themeMode: _themeNotifier.themeMode,
              home: const AuraAppEntry(),
              routes: {
                '/auth': (context) => const AuraAuthScreen(),
                '/home': (context) => const MainTabsScreen(initialIndex: 0),
                '/profile': (context) => const MainTabsScreen(initialIndex: 3),
                '/summary': (context) => const MainTabsScreen(initialIndex: 2),
                '/recordings': (context) => const MainTabsScreen(initialIndex: 1),
                '/settings': (context) => const SettingsScreen(),
                '/settings/notifications': (context) =>
                    const NotificationSettingsScreen(),
                '/settings/storage': (context) => const StorageSettingsScreen(),
                '/terms': (context) => const TermsConditionsScreen(),
                '/privacy': (context) => const PrivacyPolicyScreen(),
              },
            );
          },
        ),
      ),
    );
  }
}
