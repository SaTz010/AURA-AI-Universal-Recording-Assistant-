import 'package:flutter/material.dart';
import 'screens/history_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/initial_animation.dart';
import 'screens/home_screen.dart';
import 'screens/legal_screen.dart';
import 'screens/placeholder_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/recordings_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/summary_screen.dart';
import 'providers/auth_provider.dart';
import 'theme/aura_theme.dart';
import 'theme/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
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
              home: const AuraSplashScreen(),
              routes: {
                '/auth': (context) => const AuraAuthScreen(),
                '/home': (context) => const HomeScreen(),
                '/profile': (context) => const ProfileScreen(),
                '/summary': (context) => const SummaryScreen(),
                '/recordings': (context) => const RecordingsScreen(),
                '/settings': (context) => const SettingsScreen(),
                '/history': (context) => const HistoryScreen(),
                '/about': (context) => const AboutScreen(),
                '/logout': (context) => const LogoutScreen(),
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
