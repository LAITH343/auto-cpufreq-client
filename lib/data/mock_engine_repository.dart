import 'dart:async';
import 'dart:math';

import '../models/models.dart';
import 'engine_repository.dart';

/// In-memory engine used for development and demos. It reproduces the
/// reference design's simulated telemetry: cores and CPU jitter on a timer,
/// history scrolls, and mutations update the snapshot immediately. The real
/// D-Bus and HTTP transports will implement the same [EngineRepository]
/// surface.
class MockEngineRepository implements EngineRepository {
  @override
  final EngineCapabilities capabilities;

  final Random _rng = Random();
  final StreamController<EngineSnapshot> _controller =
      StreamController<EngineSnapshot>.broadcast();
  Timer? _tick;
  Timer? _updateCheckTimer;
  Timer? _downloadTimer;
  Timer? _installTimer;

  late EngineSnapshot _snapshot;

  MockEngineRepository({required this.capabilities}) {
    _snapshot = _initialSnapshot();
    _tick = Timer.periodic(const Duration(milliseconds: 2200), (_) => _jitter());
  }

  @override
  EngineSnapshot get snapshot => _snapshot;

  @override
  Stream<EngineSnapshot> get stream => _controller.stream;

  void _emit(EngineSnapshot next) {
    _snapshot = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  // ---- live telemetry ----

  void _jitter() {
    final s = _snapshot;
    final nu = (s.cpu.usage + (_rng.nextDouble() - 0.5) * 10).clamp(4, 99).roundToDouble();
    final nt = (s.cpu.avgTemp + (_rng.nextDouble() - 0.5) * 4).clamp(40, 86).round();
    final nw = (s.power.watts + (_rng.nextDouble() - 0.5) * 2.2).clamp(3, 30);
    final cores = s.cores
        .map((c) => c.copyWith(
              usage: (c.usage + (_rng.nextDouble() - 0.5) * 18).clamp(4, 99).roundToDouble(),
              temp: (c.temp + (_rng.nextDouble() - 0.5) * 4).clamp(38, 88).round(),
            ))
        .toList();
    final history = [
      ...s.history.skip(1),
      HistPoint(nu.round(), nt, double.parse(nw.toStringAsFixed(1))),
    ];
    _emit(s.copyWith(
      cpu: s.cpu.copyWith(usage: nu, avgTemp: nt),
      cores: cores,
      power: s.power.copyWith(watts: double.parse(nw.toStringAsFixed(1))),
      history: history,
    ));
  }

  // ---- mutations ----

  @override
  Future<void> setGovernorOverride(String value) async {
    _emit(_snapshot.copyWith(governorOverride: value));
  }

  @override
  Future<void> setTurboOverride(String value) async {
    _emit(_snapshot.copyWith(turboOverride: value));
  }

  @override
  Future<void> applyConfig(String profile, ProfileConfig cfg) async {
    if (cfg.minFreq >= cfg.maxFreq) {
      throw ConfigValidationError('Min frequency must be lower than max frequency.');
    }
    final config = {..._snapshot.config, profile: cfg};
    _emit(_snapshot.copyWith(config: config));
  }

  @override
  Future<void> setBatteryThreshold(int start, int stop) async {
    _emit(_snapshot.copyWith(batteryThreshold: BatteryThreshold(start, stop)));
  }

  @override
  Future<void> setConservationMode(bool enabled) async {
    _emit(_snapshot.copyWith(conservationMode: enabled));
  }

  @override
  Future<void> setBluetoothBoot(bool enabled) async {
    _emit(_snapshot.copyWith(bluetoothBoot: enabled));
  }

  @override
  Future<void> createUser(String username, String password) async {
    final user = AppUser(
      id: DateTime.now().millisecondsSinceEpoch,
      username: username,
      enabled: true,
      perms: const {
        'stats': 'r',
        'controls': 'none',
        'config': 'none',
        'battery': 'none',
        'bluetooth': 'none',
      },
    );
    _emit(_snapshot.copyWith(users: [..._snapshot.users, user]));
  }

  @override
  Future<void> deleteUser(int id) async {
    _emit(_snapshot.copyWith(
        users: _snapshot.users.where((u) => u.id != id).toList()));
  }

  @override
  Future<void> setUserEnabled(int id, bool enabled) async {
    _emit(_snapshot.copyWith(
      users: _snapshot.users
          .map((u) => u.id == id ? u.copyWith(enabled: enabled) : u)
          .toList(),
    ));
  }

  @override
  Future<void> setUserPermission(int id, String feature, String code) async {
    _emit(_snapshot.copyWith(
      users: _snapshot.users.map((u) {
        if (u.id != id) return u;
        return u.copyWith(perms: {...u.perms, feature: code});
      }).toList(),
    ));
  }

  @override
  Future<void> resetPassword(int id) async {
    // No-op in the mock; a real transport would issue a new password.
  }

  @override
  Future<void> revokeSession(String id) async {
    _emit(_snapshot.copyWith(
        sessions: _snapshot.sessions.where((x) => x.id != id).toList()));
  }

  @override
  Future<void> checkForUpdate() async {
    if (_snapshot.update.check == UpdateCheck.checking) return;
    _emit(_snapshot.copyWith(
        update: _snapshot.update.copyWith(check: UpdateCheck.checking)));
    _updateCheckTimer?.cancel();
    _updateCheckTimer = Timer(const Duration(milliseconds: 1500), () {
      _emit(_snapshot.copyWith(
          update: _snapshot.update.copyWith(check: UpdateCheck.available)));
    });
  }

  @override
  Future<void> startUpdateInstall() async {
    if (_snapshot.update.phase != UpdatePhase.idle) return;
    _emit(_snapshot.copyWith(
        update: _snapshot.update
            .copyWith(phase: UpdatePhase.downloading, progress: 0)));
    _downloadTimer?.cancel();
    _downloadTimer = Timer.periodic(const Duration(milliseconds: 220), (_) {
      final p = min(100, _snapshot.update.progress + 7);
      if (p >= 100) {
        _downloadTimer?.cancel();
        _emit(_snapshot.copyWith(
            update: _snapshot.update
                .copyWith(progress: 100, phase: UpdatePhase.installing)));
        _installTimer?.cancel();
        _installTimer = Timer(const Duration(milliseconds: 1300), () {
          _emit(_snapshot.copyWith(
              update: _snapshot.update.copyWith(phase: UpdatePhase.done)));
        });
      } else {
        _emit(_snapshot.copyWith(
            update: _snapshot.update.copyWith(progress: p)));
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _updateCheckTimer?.cancel();
    _downloadTimer?.cancel();
    _installTimer?.cancel();
    _controller.close();
  }

  // ---- seed data ----

  EngineSnapshot _initialSnapshot() {
    final cores = List.generate(
      8,
      (i) => CoreStat(
        id: i,
        usage: (20 + _rng.nextInt(50)).toDouble(),
        freq: double.parse((1.6 + _rng.nextDouble() * 2.4).toStringAsFixed(1)),
        temp: 48 + _rng.nextInt(20),
      ),
    );
    return EngineSnapshot(
      cpu: const CpuStat(usage: 34, load: '1.28, 1.41, 1.10', avgTemp: 58, fanRpm: 2450),
      cores: cores,
      history: _buildHistory(),
      power: const PowerStat(source: 'AC', batteryPct: 72, charging: true, watts: 12.4),
      governorOverride: 'auto',
      turboOverride: 'auto',
      config: {
        'charger': const ProfileConfig(
          governor: 'performance',
          epp: 'balance_performance',
          epb: '6',
          platformProfile: 'balanced',
          turboMode: 'auto',
          minFreq: 800,
          maxFreq: 4200,
          ignoreList: ['USB-C PD 65W'],
        ),
        'battery': const ProfileConfig(
          governor: 'powersave',
          epp: 'power',
          epb: '15',
          platformProfile: 'low-power',
          turboMode: 'never',
          minFreq: 800,
          maxFreq: 2600,
          ignoreList: [],
        ),
      },
      freqLimits: const FrequencyLimits(400, 4800),
      batteryThreshold: const BatteryThreshold(75, 80),
      conservationMode: false,
      bluetoothBoot: true,
      batteries: const [
        BatteryInfo(name: 'BAT0', level: 72, charging: true, health: 'Good · 96%'),
        BatteryInfo(name: 'BAT1', level: 100, charging: false, health: 'Good · 91%'),
      ],
      users: const [
        AppUser(id: 1, username: 'alice', enabled: true, perms: {
          'stats': 'rw', 'controls': 'rw', 'config': 'rw', 'battery': 'rw', 'bluetooth': 'rw',
        }),
        AppUser(id: 2, username: 'bob', enabled: true, perms: {
          'stats': 'rw', 'controls': 'r', 'config': 'none', 'battery': 'r', 'bluetooth': 'none',
        }),
        AppUser(id: 3, username: 'guest', enabled: false, perms: {
          'stats': 'r', 'controls': 'none', 'config': 'none', 'battery': 'none', 'bluetooth': 'none',
        }),
      ],
      sessions: const [
        SessionInfo(id: 's1', username: 'alice', device: 'iPad · Safari', ip: '192.168.1.42', since: '2h ago'),
        SessionInfo(id: 's2', username: 'bob', device: 'Pixel 8 · App', ip: '192.168.1.77', since: '5m ago'),
      ],
      update: const UpdateInfo(
          check: UpdateCheck.available, latest: '2.5.0', phase: UpdatePhase.idle, progress: 0),
      appVersion: '2.4.1',
      engineVersion: '2.3.0',
    );
  }

  List<HistPoint> _buildHistory() {
    final out = <HistPoint>[];
    double u = 30, t = 56, w = 12;
    for (var i = 0; i < 44; i++) {
      u = (u + (_rng.nextDouble() - 0.5) * 24).clamp(6, 96);
      t = (t + (_rng.nextDouble() - 0.5) * 8).clamp(44, 84);
      w = (w + (_rng.nextDouble() - 0.5) * 3).clamp(4, 24);
      out.add(HistPoint(u.round(), t.round(), double.parse(w.toStringAsFixed(1))));
    }
    return out;
  }
}
