import 'package:flutter/material.dart';

import '../theme/aura_theme.dart';
import 'home_screen.dart';
import 'history_screen.dart';
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

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 3);

    _tabs = [
      HomeScreen(
        onSelectTab: _setIndex,
      ),
      const RecordingsScreen(),
      const HistoryScreen(),
      const SummaryScreen(),
    ];
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

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: IndexedStack(
        index: _index,
        children: _tabs,
      ),
      bottomNavigationBar: MainBottomNav(
        selectedIndex: _index,
        onTap: _setIndex,
      ),
    );
  }
}
