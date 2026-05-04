import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'recordings_screen.dart';
import 'summary_screen.dart';
import 'widgets/main_bottom_nav.dart';

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 3);
  }

  @override
  void didUpdateWidget(covariant MainTabsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _index = widget.initialIndex.clamp(0, 3);
    }
  }

  void _setIndex(int index) {
    final next = index.clamp(0, 3);
    if (next == _index) return;
    setState(() => _index = next);
  }

  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogColors = AuraThemeColors.of(ctx);
        final destructiveColor = AuraSemanticColors.subtleDestructive(ctx);
        return AlertDialog(
          backgroundColor: dialogColors.surface,
          title: Text(
            'Exit AURA?',
            style: AuraTypography.titleMedium(dialogColors.textPrimary),
          ),
          content: Text(
            'Are you sure you want to exit the app?',
            style: AuraTypography.bodyMedium(dialogColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: AuraTypography.bodyMedium(dialogColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Exit',
                style: AuraTypography.bodyMedium(
                  destructiveColor,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    final tabs = <Widget>[
      HomeScreen(onSelectTab: _setIndex),
      const RecordingsScreen(),
      const SummaryScreen(),
      ProfileScreen(onSelectTab: _setIndex),
    ];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_index != 0) {
          setState(() => _index = 0);
          return;
        }
        final shouldExit = await _confirmExit();
        if (shouldExit) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: IndexedStack(index: _index, children: tabs),
        bottomNavigationBar: MainBottomNav(
          selectedIndex: _index,
          onTap: _setIndex,
        ),
      ),
    );
  }
}
