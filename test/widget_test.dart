import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auto_cpufreq_client/app.dart';
import 'package:auto_cpufreq_client/state/settings_controller.dart';

void main() {
  // The connected shell talks to the live engine over the system D-Bus, so it
  // can't be exercised in a unit test — this covers the entry screen only.
  testWidgets('launches to the devices screen with the local engine', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const AutoCpufreqApp(),
    ));
    await tester.pump();

    expect(find.text('This computer'), findsWidgets);
    expect(find.text('D-Bus'), findsOneWidget);
  });
}
