import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'l10n/strings.dart';
import 'state/connection_controller.dart';
import 'state/settings_controller.dart';
import 'theme/palette.dart';
import 'screens/devices_screen.dart';
import 'screens/gateway_disabled_screen.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';

class AutoCpufreqApp extends ConsumerWidget {
  const AutoCpufreqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final palette = ref.watch(paletteProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'auto cpufreq',
      theme: _theme(palette, settings.dark),
      builder: (context, child) => Directionality(
        textDirection: AppStrings.directionOf(settings.lang),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const _Root(),
    );
  }

  ThemeData _theme(Palette p, bool dark) {
    final brightness = dark ? Brightness.dark : Brightness.light;
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: p.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: brightness,
        surface: p.surface,
      ),
      textTheme: GoogleFonts.firaSansTextTheme(base.textTheme).apply(
        bodyColor: p.text,
        displayColor: p.text,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.hover,
        thumbColor: p.accent,
        overlayColor: p.accentSoft,
        valueIndicatorColor: p.accent,
        rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 8),
        trackHeight: 4,
      ),
    );
  }
}

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final flow = ref.watch(connectionProvider.select((c) => c.flow));

    final Widget body;
    switch (flow) {
      case AppFlow.devices:
        body = const DevicesScreen();
        break;
      case AppFlow.login:
        body = const LoginScreen();
        break;
      case AppFlow.gatewayDisabled:
        body = const GatewayDisabledScreen();
        break;
      case AppFlow.shell:
        body = const ShellScreen();
        break;
    }

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(child: body),
    );
  }
}
