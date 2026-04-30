import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/screens/widgets/main_bottom_nav.dart';

Widget _wrapNav({required double textScale}) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(360, 640),
      padding: const EdgeInsets.only(bottom: 24),
      textScaler: TextScaler.linear(textScale),
    ),
    child: MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: Scaffold(
        bottomNavigationBar: MainBottomNav(
          selectedIndex: 0,
          onTap: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Bottom nav shows labels at normal text scale', (tester) async {
    await tester.pumpWidget(_wrapNav(textScale: 1.0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.labelBehavior, NavigationDestinationLabelBehavior.alwaysShow);
  });

  testWidgets('Bottom nav hides labels at large text scale', (tester) async {
    await tester.pumpWidget(_wrapNav(textScale: 2.0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.labelBehavior, NavigationDestinationLabelBehavior.alwaysHide);
  });
}
