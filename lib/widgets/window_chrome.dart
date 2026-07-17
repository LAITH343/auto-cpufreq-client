import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../state/connection_controller.dart';
import '../state/settings_controller.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';

const String kAppVersionShort = 'v2.4.1';

/// A custom, theme-aware window title bar for desktop. The native title bar is
/// hidden (see main.dart); this draws the drag region, app name, and the
/// minimize / maximize / close controls, recoloring with the app palette.
class DesktopTitleBar extends ConsumerStatefulWidget {
  const DesktopTitleBar({super.key});

  static const double height = 44;

  @override
  ConsumerState<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends ConsumerState<DesktopTitleBar>
    with WindowListener {
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
    final conn = ref.watch(connectionProvider);
    final brightness = p.isDark ? Brightness.dark : Brightness.light;

    // Window chrome stays left-to-right so the controls keep their usual
    // position regardless of the app's language direction.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: p.bg,
        child: Container(
          height: DesktopTitleBar.height,
          decoration: BoxDecoration(
            color: p.bg,
            border: Border(bottom: BorderSide(color: p.border)),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/icon.png',
                        width: 22,
                        height: 22,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.t('appName'),
                          style: AppFonts.sans(
                            size: 12.5,
                            weight: FontWeight.w800,
                            color: p.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          kAppVersionShort.toUpperCase(),
                          style: AppFonts.mono(
                            size: 9,
                            weight: FontWeight.w700,
                            color: p.textFaint,
                          ).copyWith(letterSpacing: 0.9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: DragToMoveArea(
                  child: Center(
                    child: conn.flow == AppFlow.shell
                        ? _ConnectionPill(
                            p: p,
                            label: conn.connLabel,
                            mode: conn.connMode,
                          )
                        : const SizedBox.expand(),
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
      ),
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  final Palette p;
  final String label;
  final String mode;
  const _ConnectionPill({
    required this.p,
    required this.label,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 4, 12, 4),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 13,
            height: 13,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.successSoft,
              shape: BoxShape.circle,
            ),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: p.success,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppFonts.sans(
              size: 11.5,
              weight: FontWeight.w700,
              color: p.text,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: p.accentSoft,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              mode,
              style: AppFonts.mono(
                size: 10,
                weight: FontWeight.w700,
                color: p.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
