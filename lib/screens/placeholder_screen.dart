import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';

// ════════════════════════════════════════════════════════════════════════
//  Shared placeholder screen
// ════════════════════════════════════════════════════════════════════════

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: _BackButton(),
        title: Text(title, style: AuraTypography.titleLarge(colors.textPrimary)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceElevated,
              ),
              child: Icon(icon, size: 48, color: colors.textTertiary),
            ),
            const SizedBox(height: AuraSpacing.xl),
            Text(title, style: AuraTypography.headlineMedium(colors.textPrimary)),
            const SizedBox(height: AuraSpacing.sm),
            Text(
              'Coming Soon',
              style: AuraTypography.bodyMedium(colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared styled back button used across screens
class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AuraRadius.smBr,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(AuraSpacing.sm),
          child: Icon(Icons.arrow_back_rounded, color: colors.iconDefault),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  About Screen
// ════════════════════════════════════════════════════════════════════════

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(title: 'About', icon: Icons.info_rounded);
  }
}

// ════════════════════════════════════════════════════════════════════════
//  Logout Screen
// ════════════════════════════════════════════════════════════════════════

class LogoutScreen extends StatelessWidget {
  const LogoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceElevated,
              ),
              child: Icon(Icons.logout_rounded, size: 48, color: colors.textTertiary),
            ),
            const SizedBox(height: AuraSpacing.xl),
            Text('Logout', style: AuraTypography.headlineMedium(colors.textPrimary)),
            const SizedBox(height: AuraSpacing.sm),
            Text(
              'You have been logged out',
              style: AuraTypography.bodyMedium(colors.textSecondary),
            ),
            const SizedBox(height: AuraSpacing.xxl),
            ElevatedButton(
              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
