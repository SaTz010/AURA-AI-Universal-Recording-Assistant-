import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';

class AuraAuthScreen extends StatefulWidget {
  const AuraAuthScreen({super.key});

  @override
  State<AuraAuthScreen> createState() => _AuraAuthScreenState();
}

class _AuraAuthScreenState extends State<AuraAuthScreen> {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpacing.xxl,
                    AuraSpacing.md,
                    AuraSpacing.xxl,
                    AuraSpacing.xxl,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _AuthBrandHeader(),
                        const SizedBox(height: AuraSpacing.massive),
                        Text(
                          'Continue with Google to access AURA',
                          textAlign: TextAlign.center,
                          style: AuraTypography.bodyMedium(colors.textSecondary),
                        ),
                        const SizedBox(height: AuraSpacing.xxl),
                        ElevatedButton(
                          onPressed: authProvider.isLoading ? null : _signInWithGoogle,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: AuraSpacing.md),
                            shape: RoundedRectangleBorder(borderRadius: AuraRadius.fullBr),
                          ),
                          child: SizedBox(
                            height: 28,
                            child: Center(
                              child: authProvider.isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.g_mobiledata_rounded, size: 26),
                                        const SizedBox(width: AuraSpacing.sm),
                                        Text(
                                          'CONTINUE WITH GOOGLE',
                                          style: AuraTypography.button(
                                            Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AuraSpacing.sm),
                        Text(
                          'Fast, secure sign-in with your Google account.',
                          textAlign: TextAlign.center,
                          style: AuraTypography.caption(colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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

    return Column(
      children: [
        Text('AURA', style: AuraTypography.headlineLarge(colors.textPrimary)),
        const SizedBox(height: AuraSpacing.xs),
        Text(
          'AI Universal Recording Assistant',
          textAlign: TextAlign.center,
          style: AuraTypography.overline(colors.textSecondary),
        ),
        const SizedBox(height: AuraSpacing.base),
        Center(child: Container(width: 64, height: 1, color: colors.divider)),
      ],
    );
  }
}
