import 'package:flutter/material.dart';

import '../../theme/aura_theme.dart';
import '../../theme/aura_tokens.dart';
import '../../services/wake_backend.dart';

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
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final navHeight = AuraSpacing.massive + AuraSpacing.base; // 80px
    final bottomInset = MediaQuery.of(context).padding.bottom;

    const radius = BorderRadius.only(
      topLeft: Radius.circular(26),
      topRight: Radius.circular(26),
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius,
        boxShadow: isDarkTheme
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, -6),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: navHeight,
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: colors.surface,
                indicatorColor: colors.accent.withValues(alpha: 0.2),
                height: navHeight,
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final isSelected = states.contains(WidgetState.selected);
                  return AuraTypography.labelSmall(
                    isSelected ? colors.accent : colors.textSecondary,
                  ).copyWith(
                    height: 1.2,
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
                height: navHeight,
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) {
                  wakeBackend();
                  onTap(index);
                },
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
                    icon: Icon(Icons.auto_awesome_rounded),
                    label: 'Summarize',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_rounded),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}