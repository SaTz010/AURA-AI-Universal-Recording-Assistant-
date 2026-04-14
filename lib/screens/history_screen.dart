import 'package:flutter/material.dart';

import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'History',
          style: AuraTypography.titleLarge(colors.textPrimary),
        ),
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
              child: Icon(Icons.history_rounded, size: 48, color: colors.textTertiary),
            ),
            const SizedBox(height: AuraSpacing.xl),
            Text('History', style: AuraTypography.headlineMedium(colors.textPrimary)),
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
