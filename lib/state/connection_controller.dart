import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dbus_engine_repository.dart';
import '../data/engine_repository.dart';
import '../models/models.dart';

/// Top-level app flow. Only the local D-Bus transport is wired today; the
/// remote HTTP/S gateway path lands in a later pass.
enum AppFlow { devices, shell }

/// Screens available inside the connected shell.
enum AppScreen { dashboard, controls, config, battery, users, settings, update }

class ConnectionState {
  final AppFlow flow;
  final AppScreen screen;
  final Transport mode;
  final Permissions permissions;
  final bool hasUserManagement;
  final bool connecting;
  final String? error;
  final bool reconnecting;
  final EngineRepository? repository;

  const ConnectionState({
    this.flow = AppFlow.devices,
    this.screen = AppScreen.dashboard,
    this.mode = Transport.dbus,
    this.permissions = const Permissions({
      'stats': 'rw', 'controls': 'rw', 'config': 'rw', 'battery': 'rw', 'bluetooth': 'rw',
    }),
    this.hasUserManagement = true,
    this.connecting = false,
    this.error,
    this.reconnecting = false,
    this.repository,
  });

  // Over D-Bus the app is the local owner with full access.
  String get connLabel => 'Owner · Full access';
  String get connMode => mode == Transport.dbus ? 'D-Bus' : 'HTTPS';

  ConnectionState copyWith({
    AppFlow? flow,
    AppScreen? screen,
    bool? connecting,
    Object? error = _sentinel,
    bool? reconnecting,
    Object? repository = _sentinel,
  }) =>
      ConnectionState(
        flow: flow ?? this.flow,
        screen: screen ?? this.screen,
        mode: mode,
        permissions: permissions,
        hasUserManagement: hasUserManagement,
        connecting: connecting ?? this.connecting,
        error: error == _sentinel ? this.error : error as String?,
        reconnecting: reconnecting ?? this.reconnecting,
        repository: repository == _sentinel ? this.repository : repository as EngineRepository?,
      );

  static const Object _sentinel = Object();
}

class ConnectionController extends StateNotifier<ConnectionState> {
  ConnectionController() : super(const ConnectionState());

  static const Device localDevice = Device(
    id: 'local',
    name: 'This computer',
    host: 'localhost',
    port: 0,
    transport: Transport.dbus,
    online: true,
  );

  void goScreen(AppScreen screen) => state = state.copyWith(screen: screen);

  /// Connects to the local engine over the system D-Bus.
  Future<void> connectLocal() async {
    if (state.connecting) return;
    state = state.copyWith(connecting: true, error: null);
    try {
      final repo = await DbusEngineRepository.connect();
      state = state.copyWith(
        flow: AppFlow.shell,
        screen: AppScreen.dashboard,
        repository: repo,
        connecting: false,
        error: null,
      );
    } on EngineUnavailableException catch (e) {
      state = state.copyWith(connecting: false, error: e.message);
    } catch (e) {
      state = state.copyWith(connecting: false, error: 'Failed to connect: $e');
    }
  }

  void signOut() => _disconnect();
  void forgetDevice() => _disconnect();

  void _disconnect() {
    state.repository?.dispose();
    state = const ConnectionState();
  }

  @override
  void dispose() {
    state.repository?.dispose();
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
