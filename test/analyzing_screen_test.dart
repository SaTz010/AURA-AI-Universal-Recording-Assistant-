import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/screens/widgets/analyzing_screen.dart';
import 'package:aura/theme/aura_theme.dart';

Widget _wrap(Widget child) {
  return MaterialApp(theme: buildAuraDarkTheme(), home: child);
}

void main() {
  testWidgets('renders processing title, subtitle, and a phase', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const AnalyzingScreen(
          title: 'Processing preview',
          subtitle: 'No audio upload or API request is running.',
          autoPopAfter: null,
        ),
      ),
    );

    expect(find.text('Processing preview'), findsOneWidget);
    expect(
      find.text('No audio upload or API request is running.'),
      findsOneWidget,
    );
    expect(find.text('Launching engine'), findsOneWidget);
  });

  testWidgets('rotates to another phase after simulated time', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AnalyzingScreen(
          title: 'Processing',
          subtitle: 'Lecture / class',
          autoPopAfter: null,
          phases: ['Phase A', 'Phase B'],
          tips: ['Tip A'],
        ),
      ),
    );

    expect(find.text('Phase A'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2300));

    expect(find.text('Phase B'), findsOneWidget);
  });

  testWidgets('preview mode shows close button and does not auto-pop', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const AnalyzingScreen(
          title: 'Processing preview',
          subtitle: 'No backend request is running.',
          autoPopAfter: null,
          showCloseButton: true,
        ),
      ),
    );

    expect(find.byTooltip('Close preview'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));

    expect(find.byType(AnalyzingScreen), findsOneWidget);
    expect(find.text('Processing preview'), findsOneWidget);
  });

  testWidgets('renders without overflow on a small mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _wrap(
        const AnalyzingScreen(
          title: 'Processing preview',
          subtitle: 'No audio upload or API request is running.',
          autoPopAfter: null,
          showCloseButton: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
  });
}
