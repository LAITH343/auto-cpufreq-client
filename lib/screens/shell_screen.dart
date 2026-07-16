import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/connection_controller.dart';
import '../state/settings_controller.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import 'battery_screen.dart';
import 'config_screen.dart';
import 'controls_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'update_screen.dart';
import 'users_screen.dart';

class _NavDef {
  final AppScreen screen;
  final IconData icon;
  final String? feature;
  final bool dbusOnly;
  final String labelKey;
  const _NavDef(this.screen, this.icon, this.feature, this.labelKey, {this.dbusOnly = false});
}

const List<_NavDef> _navDefs = [
  _NavDef(AppScreen.dashboard, Icons.space_dashboard_outlined, null, 'nav_dashboard'),
  _NavDef(AppScreen.controls, Icons.tune, 'controls', 'nav_controls'),
  _NavDef(AppScreen.config, Icons.memory, 'config', 'nav_config'),
  _NavDef(AppScreen.battery, Icons.battery_full, 'battery', 'nav_battery'),
  _NavDef(AppScreen.users, Icons.manage_accounts_outlined, null, 'nav_users', dbusOnly: true),
  _NavDef(AppScreen.settings, Icons.settings_outlined, null, 'nav_settings'),
];

const Map<AppScreen, String> _titleKeys = {
  AppScreen.dashboard: 'nav_dashboard',
  AppScreen.controls: 'nav_controls',
  AppScreen.config: 'nav_config',
  AppScreen.battery: 'nav_battery',
  AppScreen.users: 'nav_users',
  AppScreen.settings: 'nav_settings',
  AppScreen.update: 'nav_update',
};

class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key});

  List<_NavDef> _visibleNav(ConnectionState conn) {
    return _navDefs.where((n) {
      if (n.dbusOnly) return conn.mode == Transport.dbus;
      if (n.feature != null) return conn.permissions.codeFor(n.feature!) != 'none';
      return true;
    }).toList();
  }

  bool _screenReadOnly(ConnectionState conn) {
    switch (conn.screen) {
      case AppScreen.controls:
        return conn.permissions.codeFor('controls') == 'r';
      case AppScreen.config:
        return conn.permissions.codeFor('config') == 'r';
      case AppScreen.battery:
        return conn.permissions.codeFor('battery') == 'r';
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(paletteProvider);
    final s = ref.watch(stringsProvider);
    final conn = ref.watch(connectionProvider);
    final snap = ref.watch(engineControllerProvider);
    final nav = _visibleNav(conn);
    final isWide = MediaQuery.of(context).size.width >= 760;

    final updateAvailable =
        snap != null && snap.update.check == UpdateCheck.available && conn.screen != AppScreen.update;

    final content = Column(
      children: [
        _Header(
          p: p,
          s: s,
          title: s.t(_titleKeys[conn.screen] ?? 'nav_dashboard'),
          connMode: conn.connMode,
          readOnly: _screenReadOnly(conn),
          showUpdateChip: updateAvailable,
          onUpdate: () => ref.read(connectionProvider.notifier).goScreen(AppScreen.update),
        ),
        if (conn.reconnecting)
          Container(
            width: double.infinity,
            color: p.warningSoft,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
            child: Text(s.t('reconnecting'),
                style: AppFonts.sans(size: 12.5, weight: FontWeight.w700, color: p.warning)),
          ),
        Expanded(child: _ScreenBody(conn.screen)),
      ],
    );

    if (isWide) {
      return ColoredBox(
        color: p.bg,
        child: Row(
          children: [
            _Sidebar(p: p, s: s, conn: conn, nav: nav),
            Expanded(child: content),
          ],
        ),
      );
    }
    return ColoredBox(
      color: p.bg,
      child: Column(
        children: [
          Expanded(child: content),
          const ShellBottomNav(),
        ],
      ),
    );
  }
}

class _ScreenBody extends StatelessWidget {
  final AppScreen screen;
  const _ScreenBody(this.screen);

  @override
  Widget build(BuildContext context) {
    switch (screen) {
      case AppScreen.dashboard:
        return const DashboardScreen();
      case AppScreen.controls:
        return const ControlsScreen();
      case AppScreen.config:
        return const ConfigScreen();
      case AppScreen.battery:
        return const BatteryScreen();
      case AppScreen.users:
        return const UsersScreen();
      case AppScreen.settings:
        return const SettingsScreen();
      case AppScreen.update:
        return const UpdateScreen();
    }
  }
}

class _Header extends StatelessWidget {
  final Palette p;
  final AppStrings s;
  final String title;
  final String connMode;
  final bool readOnly;
  final bool showUpdateChip;
  final VoidCallback onUpdate;

  const _Header({
    required this.p,
    required this.s,
    required this.title,
    required this.connMode,
    required this.readOnly,
    required this.showUpdateChip,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: AppFonts.sans(size: 16, weight: FontWeight.w800, color: p.text)),
          ),
          if (showUpdateChip) ...[
            _Chip(
              p: p,
              onTap: onUpdate,
              bg: p.accentSoft,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.system_update_alt, size: 13, color: p.accent),
                const SizedBox(width: 5),
                Text(s.t('updateShort'),
                    style: AppFonts.sans(size: 11.5, weight: FontWeight.w700, color: p.accent)),
              ]),
            ),
            const SizedBox(width: 8),
          ],
          if (readOnly) ...[
            _Chip(
              p: p,
              bg: p.surface2,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_outline, size: 11, color: p.textFaint),
                const SizedBox(width: 6),
                Text(s.t('readOnly'),
                    style: AppFonts.sans(size: 11.5, weight: FontWeight.w700, color: p.textDim)),
              ]),
            ),
            const SizedBox(width: 8),
          ],
          _Chip(
            p: p,
            bg: p.accentSoft,
            child: Text(connMode,
                style: AppFonts.mono(size: 11, weight: FontWeight.w700, color: p.accent)),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final Palette p;
  final Widget child;
  final Color bg;
  final VoidCallback? onTap;
  const _Chip({required this.p, required this.child, required this.bg, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
        child: child,
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final Palette p;
  final AppStrings s;
  final ConnectionState conn;
  final List<_NavDef> nav;
  const _Sidebar({required this.p, required this.s, required this.conn, required this.nav});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 212,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(right: BorderSide(color: p.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('appName'),
                    style: AppFonts.sans(size: 15, weight: FontWeight.w800, color: p.text)),
                const SizedBox(height: 2),
                Text('v2.4.1 · ${conn.mode == Transport.dbus ? 'linux' : 'remote'}',
                    style: AppFonts.mono(size: 10.5, color: p.textFaint)),
              ],
            ),
          ),
          for (final n in nav) _navTile(ref, n),
          const Spacer(),
          _signOutTile(ref),
        ],
      ),
    );
  }

  Widget _navTile(WidgetRef ref, _NavDef n) {
    final active = conn.screen == n.screen;
    final locked = n.feature != null && conn.permissions.codeFor(n.feature!) == 'r';
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: active ? p.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => ref.read(connectionProvider.notifier).goScreen(n.screen),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(n.icon, size: 18, color: active ? p.accent : p.textFaint),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(s.t(n.labelKey),
                      style: AppFonts.sans(
                          size: 13.5,
                          weight: FontWeight.w600,
                          color: active ? p.accent : p.textDim)),
                ),
                if (locked) Icon(Icons.lock_outline, size: 12, color: p.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _signOutTile(WidgetRef ref) {
    return InkWell(
      onTap: () => ref.read(connectionProvider.notifier).signOut(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
        child: Row(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: p.success, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conn.connLabel,
                      style: AppFonts.sans(size: 12.5, weight: FontWeight.w700, color: p.text)),
                  Text(s.t('signOutLabel'),
                      style: AppFonts.sans(size: 11, color: p.textDim)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom navigation shown on narrow (mobile) layouts.
class ShellBottomNav extends ConsumerWidget {
  const ShellBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(paletteProvider);
    final s = ref.watch(stringsProvider);
    final conn = ref.watch(connectionProvider);
    final nav = _navDefs.where((n) {
      if (n.dbusOnly) return conn.mode == Transport.dbus;
      if (n.feature != null) return conn.permissions.codeFor(n.feature!) != 'none';
      return true;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final n in nav)
              _bottomItem(ref, p, s, conn, n),
          ],
        ),
      ),
    );
  }

  Widget _bottomItem(
      WidgetRef ref, Palette p, AppStrings s, ConnectionState conn, _NavDef n) {
    final active = conn.screen == n.screen;
    final locked = n.feature != null && conn.permissions.codeFor(n.feature!) == 'r';
    return GestureDetector(
      onTap: () => ref.read(connectionProvider.notifier).goScreen(n.screen),
      child: Container(
        constraints: const BoxConstraints(minWidth: 74),
        padding: const EdgeInsets.fromLTRB(6, 9, 6, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(n.icon, size: 18, color: active ? p.accent : p.textFaint),
                if (locked)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Icon(Icons.lock_outline, size: 9, color: p.textFaint),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(s.t(n.labelKey),
                style: AppFonts.sans(
                    size: 10, weight: FontWeight.w700, color: active ? p.accent : p.textDim)),
          ],
        ),
      ),
    );
  }
}
