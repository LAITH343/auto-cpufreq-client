import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/engine_repository.dart';
import '../data/mock_engine_repository.dart';
import '../models/models.dart';

/// Top-level app flow before/after connecting to a device.
enum AppFlow { devices, login, gatewayDisabled, shell }

/// Screens available inside the connected shell.
enum AppScreen { dashboard, controls, config, battery, users, settings, update }

/// The demo roles the prototype offers (owner over D-Bus, admin/limited over
/// HTTPS). A real build derives permissions from the engine, not a picker.
enum ConnRole { owner, admin, limited }

const Map<ConnRole, Map<String, String>> _rolePerms = {
  ConnRole.owner: {'stats': 'rw', 'controls': 'rw', 'config': 'rw', 'battery': 'rw', 'bluetooth': 'rw'},
  ConnRole.admin: {'stats': 'rw', 'controls': 'rw', 'config': 'rw', 'battery': 'rw', 'bluetooth': 'rw'},
  ConnRole.limited: {'stats': 'rw', 'controls': 'r', 'config': 'none', 'battery': 'r', 'bluetooth': 'none'},
};

const Map<ConnRole, String> _roleLabels = {
  ConnRole.owner: 'Owner · Full access',
  ConnRole.admin: 'alice · Admin',
  ConnRole.limited: 'bob · Limited',
};

class ConnectionState {
  final AppFlow flow;
  final AppScreen screen;
  final Transport? mode;
  final ConnRole role;
  final Permissions permissions;
  final bool hasUserManagement;
  final Device? pendingDevice;
  final bool showTofu;
  final bool reconnecting;
  final EngineRepository? repository;

  const ConnectionState({
    this.flow = AppFlow.devices,
    this.screen = AppScreen.dashboard,
    this.mode,
    this.role = ConnRole.owner,
    this.permissions = const Permissions({
      'stats': 'rw', 'controls': 'rw', 'config': 'rw', 'battery': 'rw', 'bluetooth': 'rw',
    }),
    this.hasUserManagement = true,
    this.pendingDevice,
    this.showTofu = true,
    this.reconnecting = false,
    this.repository,
  });

  String get connLabel => _roleLabels[role]!;
  String get connMode => mode == Transport.dbus ? 'D-Bus' : 'HTTPS';

  ConnectionState copyWith({
    AppFlow? flow,
    AppScreen? screen,
    Object? mode = _sentinel,
    ConnRole? role,
    Permissions? permissions,
    bool? hasUserManagement,
    Object? pendingDevice = _sentinel,
    bool? showTofu,
    bool? reconnecting,
    Object? repository = _sentinel,
  }) =>
      ConnectionState(
        flow: flow ?? this.flow,
        screen: screen ?? this.screen,
        mode: mode == _sentinel ? this.mode : mode as Transport?,
        role: role ?? this.role,
        permissions: permissions ?? this.permissions,
        hasUserManagement: hasUserManagement ?? this.hasUserManagement,
        pendingDevice:
            pendingDevice == _sentinel ? this.pendingDevice : pendingDevice as Device?,
        showTofu: showTofu ?? this.showTofu,
        reconnecting: reconnecting ?? this.reconnecting,
        repository: repository == _sentinel ? this.repository : repository as EngineRepository?,
      );

  static const Object _sentinel = Object();
}

class ConnectionController extends StateNotifier<ConnectionState> {
  ConnectionController() : super(const ConnectionState());

  Timer? _reconnectTimer;

  static const String tofuFingerprint =
      'SHA256: 4F:9A:2C:1D:7E:88:B3:60:12:AE:5D:9F:C4:37:20:6B';

  static const Device localDevice = Device(
    id: 'local',
    name: 'This computer',
    host: 'localhost',
    port: 0,
    transport: Transport.dbus,
    online: true,
  );

  static const List<Device> savedDevices = [
    Device(id: 'office', name: 'office-workstation', host: 'office-workstation.local', port: 8443, transport: Transport.https, online: true),
    Device(id: 'bedroom', name: 'bedroom-laptop', host: 'bedroom-laptop.local', port: 8443, transport: Transport.https, online: false),
  ];

  static const List<Device> discoveredDevices = [
    Device(id: 'mediapc', name: 'media-pc', host: 'media-pc.local', port: 8443, transport: Transport.https, online: true),
    Device(id: 'nas', name: 'home-nas', host: 'home-nas.local', port: 8443, transport: Transport.https, online: true, gatewayDisabled: true),
  ];

  void setRole(ConnRole role) => state = state.copyWith(role: role);

  void goScreen(AppScreen screen) => state = state.copyWith(screen: screen);

  void selectDevice(Device device) {
    if (device.gatewayDisabled) {
      state = state.copyWith(flow: AppFlow.gatewayDisabled);
      return;
    }
    if (device.transport == Transport.dbus) {
      _connect(Transport.dbus, ConnRole.owner);
      return;
    }
    state = state.copyWith(
      flow: AppFlow.login,
      mode: Transport.https,
      pendingDevice: device,
      showTofu: true,
    );
  }

  void connectManual(String host, String port) {
    if (host.isEmpty) return;
    final device = Device(
      id: 'manual',
      name: host,
      host: host,
      port: int.tryParse(port) ?? 8443,
      transport: Transport.https,
      online: true,
    );
    state = state.copyWith(
      flow: AppFlow.login,
      mode: Transport.https,
      pendingDevice: device,
      showTofu: true,
    );
  }

  void confirmTofu() => state = state.copyWith(showTofu: false);

  void backToDevices() {
    _disposeRepo();
    state = const ConnectionState();
  }

  /// Completes an HTTPS login. In the prototype any credentials work; the
  /// active demo role determines the permission set.
  void login() {
    _connect(state.mode ?? Transport.https, state.role);
  }

  void signOut() => backToDevices();

  void forgetDevice() => backToDevices();

  void simulateReconnect() {
    state = state.copyWith(reconnecting: true);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) state = state.copyWith(reconnecting: false);
    });
  }

  void _connect(Transport mode, ConnRole role) {
    _disposeRepo();
    final dbus = mode == Transport.dbus;
    final perms = dbus ? Permissions.all() : Permissions(_rolePerms[role]!);
    final repo = MockEngineRepository(
      capabilities: EngineCapabilities(
        hasUserManagement: dbus,
        permissions: perms,
      ),
    );
    state = state.copyWith(
      flow: AppFlow.shell,
      screen: AppScreen.dashboard,
      mode: mode,
      role: dbus ? ConnRole.owner : role,
      permissions: perms,
      hasUserManagement: dbus,
      repository: repo,
      showTofu: true,
      pendingDevice: null,
      reconnecting: false,
    );
  }

  void _disposeRepo() {
    state.repository?.dispose();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _disposeRepo();
    super.dispose();
  }
}

final connectionProvider =
    StateNotifierProvider<ConnectionController, ConnectionState>(
        (ref) => ConnectionController());

final engineRepositoryProvider = Provider<EngineRepository?>(
    (ref) => ref.watch(connectionProvider.select((s) => s.repository)));

/// Live engine snapshot for the connected device (null when disconnected).
class EngineController extends StateNotifier<EngineSnapshot?> {
  final EngineRepository? _repo;
  StreamSubscription<EngineSnapshot>? _sub;

  EngineController(this._repo) : super(_repo?.snapshot) {
    _sub = _repo?.stream.listen((s) => state = s);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final engineControllerProvider =
    StateNotifierProvider<EngineController, EngineSnapshot?>((ref) {
  final repo = ref.watch(engineRepositoryProvider);
  return EngineController(repo);
});
