import 'package:flutter/material.dart';

import '../../theme/aura_theme.dart';
import '../../theme/aura_tokens.dart';

class MainBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const MainBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(26),
        topRight: Radius.circular(26),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: colors.surface,
          indicatorColor: colors.accent.withValues(alpha: 0.2),
          height: 72,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return AuraTypography.labelSmall(
              isSelected ? colors.accent : colors.textSecondary,
            ).copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: isSelected ? colors.accent : colors.textSecondary,
              size: 22,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onTap,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.library_music_rounded),
              label: 'Recordings',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.summarize_rounded),
              label: 'Summary',
            ),
          ],
        ),
      ),
    );
  }
}
