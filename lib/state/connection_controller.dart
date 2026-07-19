import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cert_store.dart';
import '../data/dbus_engine_repository.dart';
import '../data/engine_repository.dart';
import '../data/http_engine_repository.dart';
import '../data/saved_devices.dart';
import '../models/models.dart';

/// Top-level app flow: pick a device, sign in to a remote gateway, or the
/// connected shell.
enum AppFlow { devices, login, shell }

/// Screens available inside the connected shell.
enum AppScreen { dashboard, controls, config, battery, users, settings, update }

/// State of the remote sign-in flow, including the trust-on-first-use step.
class LoginFlow {
  final Device device;

  /// Probing the server certificate before showing the form.
  final bool checking;

  /// The compare-and-trust (TOFU) block is shown.
  final bool showTofu;

  /// Certificate has been trusted (or wasn't needed) — show the credentials.
  final bool tofuDone;

  final String? fingerprint;

  /// The pinned certificate previously trusted has changed.
  final bool changed;

  /// Raw DER of the certificate awaiting the user's trust decision.
  final List<int>? der;

  /// App-owned path to the pinned certificate for this connection.
  final String? certPath;

  final bool submitting;
  final String? error;

  const LoginFlow({
    required this.device,
    this.checking = false,
    this.showTofu = false,
    this.tofuDone = false,
    this.fingerprint,
    this.changed = false,
    this.der,
    this.certPath,
    this.submitting = false,
    this.error,
  });

  String get hostLabel => device.hostLabel;

  LoginFlow copyWith({
    bool? checking,
    bool? showTofu,
    bool? tofuDone,
    Object? fingerprint = _s,
    bool? changed,
    Object? der = _s,
    Object? certPath = _s,
    bool? submitting,
    Object? error = _s,
  }) =>
      LoginFlow(
        device: device,
        checking: checking ?? this.checking,
        showTofu: showTofu ?? this.showTofu,
        tofuDone: tofuDone ?? this.tofuDone,
        fingerprint: fingerprint == _s ? this.fingerprint : fingerprint as String?,
        changed: changed ?? this.changed,
        der: der == _s ? this.der : der as List<int>?,
        certPath: certPath == _s ? this.certPath : certPath as String?,
        submitting: submitting ?? this.submitting,
        error: error == _s ? this.error : error as String?,
      );

  static const Object _s = Object();
}

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

  /// Active remote sign-in flow (null unless [flow] is [AppFlow.login]).
  final LoginFlow? login;

  /// Logged-in user over HTTP/S; null (owner) over D-Bus.
  final String? user;

  /// Host label shown in the shell (e.g. `host:port`); null over D-Bus.
  final String? host;
  final bool secure;

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
    this.login,
    this.user,
    this.host,
    this.secure = false,
  });

  String get connLabel {
    if (mode == Transport.dbus) return 'Owner · Full access';
    final scope = permissions.byFeature.values.every((c) => c == 'rw')
        ? 'Full access'
        : 'Scoped access';
    return '${user ?? 'user'} · $scope';
  }

  String get connMode => mode == Transport.dbus ? 'D-Bus' : (secure ? 'HTTPS' : 'HTTP');

  ConnectionState copyWith({
    AppFlow? flow,
    AppScreen? screen,
    Transport? mode,
    Permissions? permissions,
    bool? hasUserManagement,
    bool? connecting,
    Object? error = _sentinel,
    bool? reconnecting,
    Object? repository = _sentinel,
    Object? login = _sentinel,
    Object? user = _sentinel,
    Object? host = _sentinel,
    bool? secure,
  }) =>
      ConnectionState(
        flow: flow ?? this.flow,
        screen: screen ?? this.screen,
        mode: mode ?? this.mode,
        permissions: permissions ?? this.permissions,
        hasUserManagement: hasUserManagement ?? this.hasUserManagement,
        connecting: connecting ?? this.connecting,
        error: error == _sentinel ? this.error : error as String?,
        reconnecting: reconnecting ?? this.reconnecting,
        repository: repository == _sentinel ? this.repository : repository as EngineRepository?,
        login: login == _sentinel ? this.login : login as LoginFlow?,
        user: user == _sentinel ? this.user : user as String?,
        host: host == _sentinel ? this.host : host as String?,
        secure: secure ?? this.secure,
      );

  static const Object _sentinel = Object();
}

class ConnectionController extends StateNotifier<ConnectionState> {
  ConnectionController(this._ref) : super(const ConnectionState());

  final Ref _ref;

  static const Device localDevice = Device(
    id: 'local',
    name: 'This computer',
    host: 'localhost',
    port: 0,
    transport: Transport.dbus,
    online: true,
    secure: false,
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
        mode: Transport.dbus,
        permissions: repo.capabilities.permissions,
        hasUserManagement: repo.capabilities.hasUserManagement,
        repository: repo,
        login: null,
        user: null,
        host: null,
        secure: false,
        connecting: false,
        error: null,
      );
    } on EngineUnavailableException catch (e) {
      state = state.copyWith(connecting: false, error: e.message);
    } catch (e) {
      state = state.copyWith(connecting: false, error: 'Failed to connect: $e');
    }
  }

  // ---- remote sign-in flow ----

  /// Opens the sign-in flow for a saved or discovered [device].
  void openLogin(Device device) {
    state = state.copyWith(
      flow: AppFlow.login,
      error: null,
      login: LoginFlow(
        device: device,
        checking: device.secure,
        certPath: device.certPath,
        tofuDone: !device.secure,
      ),
    );
    if (device.secure) _probe(device);
  }

  /// Opens the sign-in flow for a manually entered host/port (HTTPS).
  void openManual(String host, int port) {
    final device = Device(
      id: 'manual:$host:$port',
      name: host,
      host: host,
      port: port,
      transport: Transport.https,
      online: true,
      secure: true,
    );
    openLogin(device);
  }

  Future<void> _probe(Device device) async {
    final cfg = RemoteConfig(
      host: device.host,
      port: device.port,
      useHttps: device.secure,
      certPath: state.login?.certPath,
      username: '',
      password: '',
    );
    try {
      await HttpEngineRepository.probe(cfg);
      _patchLogin(device, (lf) => lf.copyWith(checking: false, showTofu: false, tofuDone: true));
    } on UntrustedCertException catch (e) {
      _patchLogin(
          device,
          (lf) => lf.copyWith(
              checking: false,
              showTofu: true,
              tofuDone: false,
              fingerprint: e.fingerprint,
              changed: e.changed,
              der: e.der));
    } on EngineUnavailableException catch (e) {
      _patchLogin(device, (lf) => lf.copyWith(checking: false, error: e.message));
    } catch (e) {
      _patchLogin(device, (lf) => lf.copyWith(checking: false, error: 'Failed to connect: $e'));
    }
  }

  /// Trusts the certificate shown in the TOFU step, pins it, and reveals the
  /// credential form.
  Future<void> confirmTofu() async {
    final lf = state.login;
    final der = lf?.der;
    if (lf == null || der == null) return;
    final path = await CertStore.saveDer(der);
    if (state.login?.device.id != lf.device.id) return;
    _patchLogin(lf.device,
        (l) => l.copyWith(certPath: path, showTofu: false, tofuDone: true, error: null));
  }

  /// Signs in with [user]/[password]; on success enters the shell and (when
  /// [remember]) persists the device with its pinned certificate.
  Future<void> doLogin(String user, String password, {required bool remember}) async {
    final lf = state.login;
    if (lf == null || lf.submitting) return;
    _patchLogin(lf.device, (l) => l.copyWith(submitting: true, error: null));

    final cfg = RemoteConfig(
      host: lf.device.host,
      port: lf.device.port,
      useHttps: lf.device.secure,
      certPath: lf.certPath,
      username: user,
      password: password,
    );
    try {
      final repo = await HttpEngineRepository.connect(cfg);
      if (remember) {
        _ref.read(savedDevicesProvider.notifier).remember(
              lf.device.copyWith(certPath: lf.certPath, user: user, online: true),
            );
      }
      state = state.copyWith(
        flow: AppFlow.shell,
        screen: AppScreen.dashboard,
        mode: Transport.https,
        permissions: repo.capabilities.permissions,
        hasUserManagement: repo.capabilities.hasUserManagement,
        repository: repo,
        login: null,
        user: user,
        host: lf.device.hostLabel,
        secure: lf.device.secure,
        connecting: false,
        error: null,
      );
    } on UntrustedCertException catch (e) {
      // Cert changed between probe and login — re-run the trust step.
      _patchLogin(
          lf.device,
          (l) => l.copyWith(
              submitting: false,
              showTofu: true,
              tofuDone: false,
              fingerprint: e.fingerprint,
              changed: e.changed,
              der: e.der));
    } on AuthException catch (e) {
      _patchLogin(lf.device, (l) => l.copyWith(submitting: false, error: e.message));
    } on EngineUnavailableException catch (e) {
      _patchLogin(lf.device, (l) => l.copyWith(submitting: false, error: e.message));
    } catch (e) {
      _patchLogin(lf.device, (l) => l.copyWith(submitting: false, error: 'Failed to connect: $e'));
    }
  }

  /// Pins a manually imported certificate [path] and reveals the credential
  /// form (an alternative to the live TOFU fingerprint compare).
  void applyImportedCert(String path) {
    final lf = state.login;
    if (lf == null) return;
    _patchLogin(lf.device,
        (l) => l.copyWith(certPath: path, showTofu: false, tofuDone: true, error: null));
  }

  void backToDevices() =>
      state = state.copyWith(flow: AppFlow.devices, login: null, error: null);

  void forgetSaved(String id) => _ref.read(savedDevicesProvider.notifier).forget(id);

  /// Applies [update] to the active login flow, ignoring the result if the user
  /// has since navigated away or switched devices.
  void _patchLogin(Device device, LoginFlow Function(LoginFlow) update) {
    final lf = state.login;
    if (lf == null || lf.device.id != device.id) return;
    state = state.copyWith(login: update(lf));
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
        (ref) => ConnectionController(ref));

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
