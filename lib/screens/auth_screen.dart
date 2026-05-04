import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/gestures.dart';

import '../providers/auth_provider.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';
import '../widgets/aura_snack_bar.dart';

class AuraAuthScreen extends StatefulWidget {
  const AuraAuthScreen({super.key});

  @override
  State<AuraAuthScreen> createState() => _AuraAuthScreenState();
}

class _AuraAuthScreenState extends State<AuraAuthScreen> {
  late final TapGestureRecognizer _termsTapRecognizer;
  late final TapGestureRecognizer _privacyTapRecognizer;

  @override
  void initState() {
    super.initState();
    _termsTapRecognizer = TapGestureRecognizer()
      ..onTap = () => Navigator.of(context).pushNamed('/terms');
    _privacyTapRecognizer = TapGestureRecognizer()
      ..onTap = () => Navigator.of(context).pushNamed('/privacy');
  }

  @override
  void dispose() {
    _termsTapRecognizer.dispose();
    _privacyTapRecognizer.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    final authProvider = AuraAuthProvider.of(context);
    final success = await authProvider.signInWithGoogle();
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      return;
    }

    final message = authProvider.errorMessage;
    if (message != null && message.isNotEmpty) {
      showAuraSnackBar(context, message: message);
      authProvider.clearError();
    }
  }

  Future<void> _signInAsGuest() async {
    final authProvider = AuraAuthProvider.of(context);
    final success = await authProvider.signInAsGuest();
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      return;
    }

    final message = authProvider.errorMessage;
    if (message != null && message.isNotEmpty) {
      showAuraSnackBar(context, message: message);
      authProvider.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    final authProvider = AuraAuthProvider.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AuraSpacing.xl,
            AuraSpacing.base,
            AuraSpacing.xl,
            AuraSpacing.xl,
          ),
          child: Column(
            children: [
              Expanded(
                child: Align(
                  alignment: const Alignment(0, -0.14),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -14),
                          child: const _AuthBrandHeader(),
                        ),
                        const SizedBox(height: AuraSpacing.massive),
                        _AuthActionButton(
                          label: 'Continue with Google',
                          onPressed: authProvider.isLoading
                              ? null
                              : _signInWithGoogle,
                          icon: SvgPicture.asset(
                            'assets/images/google_g_logo.svg',
                            width: 20,
                            height: 20,
                          ),
                          isLoading: authProvider.isLoading,
                          textColor: colors.textPrimary,
                          backgroundColor: colors.surfaceElevated,
                          borderColor: colors.border,
                        ),
                        const SizedBox(height: AuraSpacing.md),
                        _AuthActionButton(
                          label: 'Continue as Guest',
                          onPressed: authProvider.isLoading
                              ? null
                              : _signInAsGuest,
                          icon: Icon(
                            Icons.person_outline_rounded,
                            size: 22,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          isLoading: authProvider.isLoading,
                          textColor: Theme.of(context).colorScheme.onPrimary,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          borderColor: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AuraTypography.caption(colors.textSecondary),
                    children: [
                      const TextSpan(text: 'By continuing, you agree to AURA '),
                      TextSpan(
                        text: 'Terms & Conditions',
                        style: AuraTypography.caption(colors.accent).copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: _termsTapRecognizer,
                      ),
                      const TextSpan(text: ' and acknowledge our '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: AuraTypography.caption(colors.accent).copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: _privacyTapRecognizer,
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthActionButton extends StatelessWidget {
  const _AuthActionButton({
    required this.label,
    required this.onPressed,
    required this.icon,
    required this.isLoading,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget icon;
  final bool isLoading;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AuraRadius.fullBr),
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.base),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: textColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: AuraSpacing.sm),
                  Text(label, style: AuraTypography.button(textColor)),
                ],
              ),
      ),
    );
  }
}

class _AuthBrandHeader extends StatelessWidget {
  const _AuthBrandHeader();

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    final isDark = colors.isDark;

    final primaryLogoAsset = isDark
        ? 'assets/images/light.png'
        : 'assets/images/dark.png';
    final fallbackLogoAsset = isDark
        ? 'assets/images/light_theme_logo.png'
        : 'assets/images/Dark_theme_logo.png';

    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final logoSize = (shortestSide * 0.18).clamp(60.0, 96.0);

    return Column(
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
        const SizedBox(height: AuraSpacing.base),
        Text(
          'AURA',
          style: AuraTypography.displayLarge(
            colors.textPrimary,
          ).copyWith(letterSpacing: 3),
        ),
        const SizedBox(height: AuraSpacing.xs),
        Text(
          'AI Universal Recording Assistant',
          textAlign: TextAlign.center,
          style: AuraTypography.bodySmall(colors.textSecondary),
        ),
        const SizedBox(height: AuraSpacing.base),
        Center(child: Container(width: 64, height: 1, color: colors.divider)),
      ],
    );
  }
}
