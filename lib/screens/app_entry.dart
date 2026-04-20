import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../providers/auth_provider.dart' as aura_auth;
import 'auth_screen.dart';
import 'main_tabs_screen.dart';

class AuraAppEntry extends StatelessWidget {
  const AuraAppEntry({super.key});

  static const _nativeSplashBackground = Color(0xFF0A0B0E);

  @override
  Widget build(BuildContext context) {
    final authProvider = aura_auth.AuraAuthProvider.of(context);

    if (!authProvider.initialized) {
      return const Scaffold(
        backgroundColor: _nativeSplashBackground,
        body: SizedBox.expand(),
      );
    }

    final hasSession =
        authProvider.isAuthenticated || FirebaseAuth.instance.currentUser != null;

    return hasSession
        ? const MainTabsScreen(initialIndex: 0)
        : const AuraAuthScreen();
  }
}

