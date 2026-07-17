import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/connection_controller.dart';
import '../state/settings_controller.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../util/platform.dart';
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

    Widget content({VoidCallback? onMenu}) => Column(
          children: [
            _Header(
              p: p,
              s: s,
              title: s.t(_titleKeys[conn.screen] ?? 'nav_dashboard'),
              connMode: conn.connMode,
              readOnly: _screenReadOnly(conn),
              showUpdateChip: updateAvailable,
              onUpdate: () => ref.read(connectionProvider.notifier).goScreen(AppScreen.update),
              onMenu: onMenu,
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
            Expanded(child: content()),
          ],
        ),
      );
    }

    // Narrow: navigation collapses into a slide-in drawer opened from the
    // header. The drawer only repeats the app identity when there is no desktop
    // title bar already showing it.
    return Scaffold(
      backgroundColor: p.bg,
      drawerEdgeDragWidth: 24,
      drawer: Drawer(
        width: 260,
        backgroundColor: p.bg,
        shape: const RoundedRectangleBorder(),
        child: _Sidebar(
          p: p,
          s: s,
          conn: conn,
          nav: nav,
          inDrawer: true,
          showIdentity: !isDesktop,
        ),
      ),
      body: Builder(
        builder: (context) => content(onMenu: () => Scaffold.of(context).openDrawer()),
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
  final VoidCallback? onMenu;

  const _Header({
    required this.p,
    required this.s,
    required this.title,
    required this.connMode,
    required this.readOnly,
    required this.showUpdateChip,
    required this.onUpdate,
    this.onMenu,
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
          if (onMenu != null) ...[
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onMenu,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.menu, size: 20, color: p.text),
              ),
            ),
            const SizedBox(width: 10),
          ],
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
  final bool inDrawer;
  final bool showIdentity;
  const _Sidebar({
    required this.p,
    required this.s,
    required this.conn,
    required this.nav,
    this.inDrawer = false,
    this.showIdentity = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = Container(
      width: inDrawer ? null : 212,
      decoration: BoxDecoration(
        color: p.surface,
        border: inDrawer ? null : Border(right: BorderSide(color: p.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showIdentity) _identity(),
          for (final n in nav) _navTile(context, ref, n),
          const Spacer(),
          _signOutTile(context, ref),
        ],
      ),
    );
    return inDrawer ? SafeArea(child: body) : body;
  }

  Widget _identity() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(7)),
            child: const Icon(Icons.speed, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(s.t('appName'),
                style: AppFonts.sans(size: 15, weight: FontWeight.w800, color: p.text)),
          ),
        ],
      ),
    );
  }

  Widget _navTile(BuildContext context, WidgetRef ref, _NavDef n) {
    final active = conn.screen == n.screen;
    final locked = n.feature != null && conn.permissions.codeFor(n.feature!) == 'r';
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: active ? p.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            if (inDrawer) Navigator.of(context).pop();
            ref.read(connectionProvider.notifier).goScreen(n.screen);
          },
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

  Widget _signOutTile(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: p.surface2,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (inDrawer) Navigator.of(context).pop();
            ref.read(connectionProvider.notifier).signOut();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(color: p.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, size: 15, color: p.text),
                const SizedBox(width: 8),
                Text(s.t('signOutLabel'),
                    style: AppFonts.sans(size: 12.5, weight: FontWeight.w700, color: p.text)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
