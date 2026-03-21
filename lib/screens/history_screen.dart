import 'package:flutter/material.dart';

import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';
import 'widgets/main_bottom_nav.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _onBottomNavTapped(BuildContext context, int index) async {
    if (index == 2) return;

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/recordings');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/summary');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      bottomNavigationBar: MainBottomNav(
        selectedIndex: 2,
        onTap: (index) => _onBottomNavTapped(context, index),
      ),
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
