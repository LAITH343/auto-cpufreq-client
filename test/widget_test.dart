import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_cpufreq_client/app.dart';

void main() {
  testWidgets('launches to the devices screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AutoCpufreqApp()));
    await tester.pump();

    // The entry screen lists the local engine as a connectable device.
    expect(find.text('This computer'), findsWidgets);
    expect(find.text('Saved devices'.toUpperCase()), findsOneWidget);
  });

  testWidgets('connecting to the local engine renders the dashboard', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: AutoCpufreqApp()));
    await tester.pump();

    // Tapping the local-engine card opens the shell over a D-Bus connection.
    await tester.tap(find.text('Local engine detected'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Per-core'), findsOneWidget);
    // Users management is available on D-Bus connections.
    expect(find.text('Users & Permissions'), findsWidgets);
  });
}
