import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'l10n/strings.dart';
import 'state/connection_controller.dart';
import 'state/settings_controller.dart';
import 'theme/palette.dart';
import 'screens/devices_screen.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';
import 'util/platform.dart';
import 'widgets/window_chrome.dart';

class AutoCpufreqApp extends ConsumerWidget {
  const AutoCpufreqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final dark = ref.watch(isDarkProvider);
    final lang = ref.watch(effectiveLangProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'auto cpufreq',
      theme: _theme(palette, dark),
      builder: (context, child) {
        Widget content = child ?? const SizedBox.shrink();
        content = Directionality(
          textDirection: AppStrings.directionOf(lang),
          child: content,
        );
        if (isDesktop) {
          content = Column(
            children: [
              const DesktopTitleBar(),
              Expanded(child: content),
            ],
          );
        }
        return content;
      },
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
    final restoring = ref.watch(connectionProvider.select((c) => c.restoring));

    final Widget body;
    if (restoring) {
      body = Center(child: CircularProgressIndicator(color: palette.accent));
    } else {
      switch (flow) {
        case AppFlow.devices:
          body = const DevicesScreen();
          break;
        case AppFlow.login:
          body = const LoginScreen();
          break;
        case AppFlow.shell:
          body = const ShellScreen();
          break;
      }
    }

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(child: body),
    );
  }
}
