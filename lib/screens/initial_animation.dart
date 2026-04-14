import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_screen.dart';
import '../providers/auth_provider.dart';
import 'main_tabs_screen.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';

class AuraSplashScreen extends StatefulWidget {
  const AuraSplashScreen({super.key});

  @override
  State<AuraSplashScreen> createState() => _AuraSplashScreenState();
}

class _AuraSplashScreenState extends State<AuraSplashScreen>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;

  late final Animation<double> scaleAnim;
  late final Animation<double> baseOpacity;
  late final Animation<double> micOpacity;
  late final Animation<double> textOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    scaleAnim = Tween<double>(begin: 0.9, end: 1.06).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    baseOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    micOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
      ),
    );

    textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _preloadImages();
  }

  Future<void> _preloadImages() async {
    try {
      await Future.wait([
        precacheImage(
          const AssetImage('assets/images/aura_a.png'),
          context,
        ),
        precacheImage(
          const AssetImage('assets/images/aura_mic.png'),
          context,
        ),
      ]);

      if (mounted) {
        _controller.forward();
        // Navigate to auth screen after animation completes
        Future.delayed(const Duration(milliseconds: 2600), () {
          if (mounted) {
            final authProvider = AuraAuthProvider.of(context);
            final hasSession = authProvider.isAuthenticated || FirebaseAuth.instance.currentUser != null;
            final destination = hasSession
                ? const MainTabsScreen(initialIndex: 0)
                : const AuraAuthScreen();
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                transitionDuration: AuraMotion.slow,
                pageBuilder: (context, animation, secondaryAnimation) => destination,
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: AuraMotion.decelerate,
                    ),
                    child: child,
                  );
                },
              ),
            );
          }
        });
      }
    } catch (_) {
      if (mounted) {
        _controller.forward();
        // Navigate to auth screen after animation completes
        Future.delayed(const Duration(milliseconds: 2600), () {
          if (mounted) {
            final authProvider = AuraAuthProvider.of(context);
            final hasSession = authProvider.isAuthenticated || FirebaseAuth.instance.currentUser != null;
            final destination = hasSession
                ? const MainTabsScreen(initialIndex: 0)
                : const AuraAuthScreen();
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                transitionDuration: AuraMotion.slow,
                pageBuilder: (context, animation, secondaryAnimation) => destination,
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: AuraMotion.decelerate,
                    ),
                    child: child,
                  );
                },
              ),
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // CENTER LOGO
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: scaleAnim.value,
                  child: Opacity(
                    opacity: baseOpacity.value,
                    child: SizedBox(
                      width: 300,
                      height: 300,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/only_a.png',
                            fit: BoxFit.contain,
                          ),
                          Opacity(
                            opacity: micOpacity.value,
                            child: Image.asset(
                              'assets/images/only_mic.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // BOTTOM BRAND TEXT
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: FadeTransition(
              opacity: textOpacity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AURA',
                    textAlign: TextAlign.center,
                    style: AuraTypography.displayLarge(colors.textPrimary),
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
        ],
      ),
    );
  }
}
