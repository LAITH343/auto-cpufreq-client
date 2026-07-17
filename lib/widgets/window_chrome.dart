import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../state/settings_controller.dart';
import '../theme/typography.dart';

/// A custom, theme-aware window title bar for desktop. The native title bar is
/// hidden (see main.dart); this draws the drag region, app name, and the
/// minimize / maximize / close controls, recoloring with the app palette.
class DesktopTitleBar extends ConsumerStatefulWidget {
  const DesktopTitleBar({super.key});

  static const double height = 40;

  @override
  ConsumerState<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends ConsumerState<DesktopTitleBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _maximized = v);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(paletteProvider);
    final s = ref.watch(stringsProvider);
    final brightness = p.isDark ? Brightness.dark : Brightness.light;

    // Window chrome stays left-to-right so the controls keep their usual
    // position regardless of the app's language direction.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        height: DesktopTitleBar.height,
        color: p.surface,
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Image.asset('assets/icon.png', width: 18, height: 18),
                    const SizedBox(width: 10),
                    Text(
                      s.t('appName'),
                      style: AppFonts.sans(size: 12.5, weight: FontWeight.w700, color: p.text),
                    ),
                  ],
                ),
              ),
            ),
            WindowCaptionButton.minimize(
              brightness: brightness,
              onPressed: () => windowManager.minimize(),
            ),
            _maximized
                ? WindowCaptionButton.unmaximize(
                    brightness: brightness,
                    onPressed: () => windowManager.unmaximize(),
                  )
                : WindowCaptionButton.maximize(
                    brightness: brightness,
                    onPressed: () => windowManager.maximize(),
                  ),
            WindowCaptionButton.close(
              brightness: brightness,
              onPressed: () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }
}
