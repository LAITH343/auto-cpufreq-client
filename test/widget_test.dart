import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_cpufreq_client/app.dart';

void main() {
  // The connected shell talks to the live engine over the system D-Bus, so it
  // can't be exercised in a unit test — this covers the entry screen only.
  testWidgets('launches to the devices screen with the local engine', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AutoCpufreqApp()));
    await tester.pump();

    expect(find.text('This computer'), findsWidgets);
    expect(find.text('D-Bus'), findsOneWidget);
  });
}
