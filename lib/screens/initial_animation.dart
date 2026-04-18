import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_screen.dart';
import '../providers/auth_provider.dart' as aura_auth;
import 'main_tabs_screen.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';

class AuraSplashScreen extends StatefulWidget {
  const AuraSplashScreen({super.key});

  @override
  State<AuraSplashScreen> createState() => _AuraSplashScreenState();
}

class _AuraSplashScreenState extends State<AuraSplashScreen> {
  bool _didNavigate = false;

  static const Duration _debugHoldDuration = Duration(seconds: 1);

  void _maybeNavigate(aura_auth.AuthProvider authProvider) {
    if (_didNavigate || !authProvider.initialized) return;

    _didNavigate = true;

    final hasSession =
        authProvider.isAuthenticated || FirebaseAuth.instance.currentUser != null;
    final destination = hasSession
        ? const MainTabsScreen(initialIndex: 0)
        : const AuraAuthScreen();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final hold = kDebugMode ? _debugHoldDuration : Duration.zero;
      Future.delayed(hold, () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (context, animation, secondaryAnimation) => destination,
          ),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = aura_auth.AuraAuthProvider.of(context);
    _maybeNavigate(authProvider);

    final colors = AuraThemeColors.of(context);
    final isDark = colors.isDark;

    final primaryLogoAsset =
        isDark ? 'assets/images/light.png' : 'assets/images/dark.png';
    final fallbackLogoAsset = isDark
        ? 'assets/images/light_theme_logo.png'
        : 'assets/images/Dark_theme_logo.png';

    final size = MediaQuery.sizeOf(context);
    final shortestSide = size.shortestSide;
    final logoSize = (shortestSide * 0.38).clamp(120.0, 210.0);

    return Scaffold(
      backgroundColor:
          isDark ? AuraSplashTokens.darkBackground : AuraSplashTokens.lightBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: logoSize,
                  height: logoSize,
                  child: Image.asset(
                    primaryLogoAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        fallbackLogoAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox.shrink();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: AuraSpacing.lg),
                Text(
                  'AURA',
                  textAlign: TextAlign.center,
                  style: AuraTypography.headlineLarge(colors.textPrimary),
                ),
                const SizedBox(height: AuraSpacing.sm),
                Text(
                  'AI Universal Recording Assistant',
                  textAlign: TextAlign.center,
                  style: AuraTypography.overline(colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
