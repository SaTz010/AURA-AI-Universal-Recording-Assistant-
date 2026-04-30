import 'package:flutter/material.dart';

import '../../theme/aura_theme.dart';
import '../../theme/aura_tokens.dart';

/// Shows a bottom sheet informing the guest user that summarization requires
/// a signed-in account. The "Sign in" button navigates to the /auth route.
Future<void> showSummarizeGuestBlock(BuildContext context) {
  final colors = AuraThemeColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) {
      final sheetColors = AuraThemeColors.of(ctx);
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AuraSpacing.xl,
            AuraSpacing.lg,
            AuraSpacing.xl,
            AuraSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: sheetColors.border,
                    borderRadius: BorderRadius.circular(AuraRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: AuraSpacing.xl),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sheetColors.surfaceElevated,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: sheetColors.accent,
                  size: 28,
                ),
              ),
              const SizedBox(height: AuraSpacing.lg),
              Text(
                'Sign in to summarize',
                style: AuraTypography.titleMedium(sheetColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AuraSpacing.sm),
              Text(
                'Audio summarization is available to signed-in users. Create a free account to unlock this feature.',
                style: AuraTypography.bodyMedium(sheetColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AuraSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Not now'),
                    ),
                  ),
                  const SizedBox(width: AuraSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/auth',
                          (route) => false,
                        );
                      },
                      child: const Text('Sign in'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
