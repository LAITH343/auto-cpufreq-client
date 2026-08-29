import 'dart:async';
import 'dart:convert';

import 'package:dbus/dbus.dart';

import '../models/models.dart';
import 'engine_repository.dart';

const String _engineBus = 'org.autocpufreq';
const String _enginePath = '/org/autocpufreq/engine';
const String _engineIface = 'org.autocpufreq.Engine1';
const String _usersPath = '/org/autocpufreq/users';
const String _usersIface = 'org.autocpufreq.Users1';

const String _invalidConfigError = 'org.autocpufreq.Error.InvalidConfig';
const String _invalidArgError = 'org.autocpufreq.Error.InvalidArgument';

const int _historyLength = 60;
const String _appVersion = '1.0.0';

/// [EngineRepository] backed by the local engine over the system D-Bus.
/// Talks to `org.autocpufreq.Engine1` for control/stats and
/// `org.autocpufreq.Users1` for user management. The engine reports no rolling
/// history, so it is accumulated here from `StatsTick` frames.
class DbusEngineRepository implements EngineRepository {
  final DBusClient _client;
  final DBusRemoteObject _engine;
  final DBusRemoteObject _users;

  final StreamController<EngineSnapshot> _controller =
      StreamController<EngineSnapshot>.broadcast();
  final StreamController<ConnectionStatus> _status =
      StreamController<ConnectionStatus>.broadcast();
  final List<StreamSubscription> _subs = [];
  final List<HistPoint> _history = [];

  bool _disposed = false;
  bool _reconnecting = false;

  late EngineSnapshot _snapshot;

  @override
  final EngineCapabilities capabilities = EngineCapabilities(
    hasUserManagement: true,
    permissions: Permissions.all(),
  );

  DbusEngineRepository._(this._client, this._engine, this._users);

  /// Connects to the system bus and takes an initial snapshot. Throws
  /// [EngineUnavailableException] if the engine isn't reachable.
  static Future<DbusEngineRepository> connect() async {
    final client = DBusClient.system();
    final engine = DBusRemoteObject(client,
        name: _engineBus, path: DBusObjectPath(_enginePath));
    final users = DBusRemoteObject(client,
        name: _engineBus, path: DBusObjectPath(_usersPath));
    final repo = DbusEngineRepository._(client, engine, users);
    try {
      await repo._bootstrap();
    } catch (e) {
      await client.close();
      if (e is DBusMethodResponseException) {
        throw EngineUnavailableException(
            'auto-cpufreq engine is not reachable over D-Bus: ${e.errorName}');
      }
      rethrow;
    }
    return repo;
  }

  @override
  EngineSnapshot get snapshot => _snapshot;

  @override
  Stream<EngineSnapshot> get stream => _controller.stream;

  @override
  Stream<ConnectionStatus> get status => _status.stream;

  void _emit() {
    if (!_controller.isClosed) _controller.add(_snapshot);
  }

  void _pushStatus(ConnectionStatus s) {
    if (!_status.isClosed) _status.add(s);
  }

  // ---- bootstrap + subscriptions ----

  Future<void> _bootstrap() async {
    await _loadSnapshot();
    await _subscribe();
    _watchOwner();
    await _startStats();
    _emit();
  }

  /// Fetches a fresh full snapshot from the engine. Reused on first connect and
  /// after the engine reappears on the bus.
  Future<void> _loadSnapshot() async {
    final props = await _engine.getAllProperties(_engineIface);
    final report = await _callString(_engine, _engineIface, 'GetReport');
    final config = await _callString(_engine, _engineIface, 'GetConfig');
    final reportMap = jsonDecode(report) as Map<String, dynamic>;
    final users = await _fetchUsers();
    final sessions = await _fetchSessions();

    final limits = _readFreqLimits(props);
    final govs = _readStringArray(props['AvailableGovernors']);
    _seedHistory(reportMap);

    _snapshot = EngineSnapshot(
      cpu: _parseCpu(reportMap),
      cpuModel: (reportMap['processor_model'] as String?) ?? 'CPU',
      cores: _parseCores(reportMap),
      history: List.of(_history),
      power: _parsePower(reportMap),
      governorOverride: _fromEngineGovernor(_readString(props['GovernorOverride'])),
      turboOverride: _readString(props['TurboOverride']).isEmpty
          ? 'auto'
          : _readString(props['TurboOverride']),
      config: _parseConfig(config, limits, govs),
      freqLimits: limits,
      availableGovernors: govs.isEmpty ? EngineChoices.governors : govs,
      batteryThreshold: _parseThreshold(reportMap),
      conservationMode: false,
      bluetoothBoot: false,
      batteries: _parseBatteries(reportMap),
      users: users,
      sessions: sessions,
      update: const UpdateInfo(
          check: UpdateCheck.upToDate, latest: '', phase: UpdatePhase.idle, progress: 0),
      appVersion: _appVersion,
      engineVersion: _readString(props['Version']),
    );
  }

  /// Begins the StatsTick stream. Must be re-issued after an engine restart
  /// since the fresh process starts with no stats consumers.
  Future<void> _startStats() async {
    await _engine.callMethod(_engineIface, 'StartStats', [],
        replySignature: DBusSignature(''));
  }

  Future<void> _subscribe() async {
    void add(String path, String iface, String name, void Function(DBusSignal) fn) {
      final obj = path == _usersPath ? _users : _engine;
      final stream = DBusRemoteObjectSignalStream(object: obj, interface: iface, name: name);
      _subs.add(stream.listen(fn));
    }

    add(_enginePath, _engineIface, 'StatsTick', (sig) {
      final json = (sig.values.first).asString();
      _onStatsTick(json);
    });
    _subs.add(_engine.propertiesChanged.listen(_onPropertiesChanged));
    add(_enginePath, _engineIface, 'ConfigChanged', (_) => _refreshConfig());
    add(_usersPath, _usersIface, 'UsersChanged', (_) => _refreshUsers());
    add(_usersPath, _usersIface, 'SessionRevoked', (_) => _refreshSessions());
  }

  /// Tracks ownership of the engine bus name. When the engine process exits its
  /// name is released (reconnecting); when a new instance claims it we reload a
  /// fresh snapshot and resume the stats stream. The signal subscriptions above
  /// are bus-wide match rules and survive the restart, so they are not redone.
  void _watchOwner() {
    _subs.add(_client.nameOwnerChanged.listen((e) {
      if (e.name != _engineBus) return;
      if (e.newOwner == null) {
        _pushStatus(ConnectionStatus.reconnecting);
      } else {
        _onEngineReappeared();
      }
    }));
  }

  Future<void> _onEngineReappeared() async {
    if (_disposed || _reconnecting) return;
    _reconnecting = true;
    _pushStatus(ConnectionStatus.reconnecting);
    var delay = const Duration(milliseconds: 250);
    while (!_disposed) {
      try {
        await _loadSnapshot();
        await _startStats();
        _pushStatus(ConnectionStatus.connected);
        _emit();
        break;
      } catch (_) {
        // Engine name is claimed but the objects may not be ready yet; retry.
        await Future<void>.delayed(delay);
        if (delay < const Duration(seconds: 5)) delay *= 2;
      }
    }
    _reconnecting = false;
  }

  void _onStatsTick(String json) {
    final Map<String, dynamic> m;
    try {
      m = jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final cpu = _parseCpu(m);
    _pushHistory(m);
    _snapshot = _snapshot.copyWith(
      cpu: cpu,
      cores: _parseCores(m),
      power: _parsePower(m),
      history: List.of(_history),
      batteryThreshold: _parseThreshold(m),
      batteries: _parseBatteries(m),
    );
    _emit();
  }

  void _onPropertiesChanged(DBusPropertiesChangedSignal sig) {
    if (sig.propertiesInterface != _engineIface) return;
    final changed = sig.changedProperties;
    var next = _snapshot;
    if (changed.containsKey('GovernorOverride')) {
      next = next.copyWith(
          governorOverride: _fromEngineGovernor(_readString(changed['GovernorOverride'])));
    }
    if (changed.containsKey('TurboOverride')) {
      final v = _readString(changed['TurboOverride']);
      next = next.copyWith(turboOverride: v.isEmpty ? 'auto' : v);
    }
    _snapshot = next;
    _emit();
  }

  Future<void> _refreshConfig() async {
    final config = await _callString(_engine, _engineIface, 'GetConfig');
    _snapshot = _snapshot.copyWith(
        config: _parseConfig(config, _snapshot.freqLimits, _snapshot.availableGovernors));
    _emit();
  }

  Future<void> _refreshUsers() async {
    _snapshot = _snapshot.copyWith(users: await _fetchUsers());
    _emit();
  }

  Future<void> _refreshSessions() async {
    _snapshot = _snapshot.copyWith(sessions: await _fetchSessions());
    _emit();
  }

  // ---- mutations ----

  @override
  Future<void> setGovernorOverride(String value) async {
    await _engine.callMethod(_engineIface, 'SetGovernorOverride',
        [DBusString(_toEngineGovernor(value))], replySignature: DBusSignature(''));
  }

  @override
  Future<void> setTurboOverride(String value) async {
    await _engine.callMethod(_engineIface, 'SetTurboOverride', [DBusString(value)],
        replySignature: DBusSignature(''));
  }

  @override
  Future<void> applyConfig(String profile, ProfileConfig cfg) async {
    // SetConfig replaces the whole file, so send both profiles + ignore list.
    final merged = {..._snapshot.config, profile: cfg};
    final payload = <String, dynamic>{
      for (final p in ['charger', 'battery'])
        if (merged[p] != null) p: _profileToJson(merged[p]!),
      'power_supply_ignore_list': {for (final n in cfg.ignoreList) n: 'true'},
    };
    try {
      await _engine.callMethod(_engineIface, 'SetConfig', [DBusString(jsonEncode(payload))],
          replySignature: DBusSignature(''));
      _snapshot = _snapshot.copyWith(config: merged);
      _emit();
    } on DBusMethodResponseException catch (e) {
      if (e.errorName == _invalidConfigError || e.errorName == _invalidArgError) {
        throw ConfigValidationError(_errorText(e));
      }
      rethrow;
    }
  }

  @override
  Future<void> setBatteryThreshold(int start, int stop) async {
    if (start >= stop) start = stop - 1;
    if (start < 0) start = 0;
    try {
      await _engine.callMethod(_engineIface, 'SetBatteryThresholds',
          [DBusUint32(start), DBusUint32(stop)], replySignature: DBusSignature(''));
      _snapshot = _snapshot.copyWith(batteryThreshold: BatteryThreshold(start, stop));
      _emit();
    } on DBusMethodResponseException {
      // Unsupported device / invalid range — leave state unchanged.
    }
  }

  @override
  Future<void> setConservationMode(bool enabled) async {
    try {
      await _engine.callMethod(_engineIface, 'SetConservationMode', [DBusBoolean(enabled)],
          replySignature: DBusSignature(''));
      _snapshot = _snapshot.copyWith(conservationMode: enabled);
      _emit();
    } on DBusMethodResponseException {
      // Not supported on this device.
    }
  }

  @override
  Future<void> setBluetoothBoot(bool enabled) async {
    await _engine.callMethod(_engineIface, 'SetBluetoothBoot', [DBusBoolean(enabled)],
        replySignature: DBusSignature(''));
    _snapshot = _snapshot.copyWith(bluetoothBoot: enabled);
    _emit();
  }

  @override
  Future<void> createUser(String username, String password) async {
    await _users.callMethod(_usersIface, 'CreateUser',
        [DBusString(username), DBusString(password)], replySignature: DBusSignature(''));
  }

  @override
  Future<void> deleteUser(String username) async {
    await _users.callMethod(_usersIface, 'DeleteUser', [DBusString(username)],
        replySignature: DBusSignature(''));
  }

  @override
  Future<void> setUserEnabled(String username, bool enabled) async {
    await _users.callMethod(_usersIface, 'SetEnabled',
        [DBusString(username), DBusBoolean(enabled)], replySignature: DBusSignature(''));
  }

  @override
  Future<void> setUserPermission(String username, String feature, String code) async {
    final user = _snapshot.users.firstWhere((u) => u.name == username,
        orElse: () => AppUser(name: username, enabled: true, perms: const {}));
    final perms = {...user.perms, feature: code};
    final wire = {
      for (final f in kFeatures)
        f: _codeToGrant(perms[f] ?? 'none'),
    };
    await _users.callMethod(_usersIface, 'SetPermissions',
        [DBusString(username), DBusString(jsonEncode(wire))], replySignature: DBusSignature(''));
  }

  @override
  Future<void> resetPassword(String username) async {
    // The Users1 interface only exposes SetPassword(name, newPassword); a
    // password-less reset isn't meaningful, so this is a no-op for now.
  }

  @override
  Future<void> revokeSession(String id) async {
    await _users.callMethod(_usersIface, 'RevokeSession', [DBusString(id)],
        replySignature: DBusSignature(''));
  }

  @override
  Future<void> checkForUpdate() async {
    // The engine has no update channel; report up-to-date.
    _snapshot = _snapshot.copyWith(
        update: _snapshot.update.copyWith(check: UpdateCheck.upToDate));
    _emit();
  }

  @override
  Future<void> startUpdateInstall() async {}

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _controller.close();
    _status.close();
    _client.close();
  }

  // ---- helpers ----

  Future<String> _callString(DBusRemoteObject obj, String iface, String member) async {
    final r = await obj.callMethod(iface, member, [], replySignature: DBusSignature('s'));
    return r.returnValues.first.asString();
  }

  Future<List<AppUser>> _fetchUsers() async {
    final json = await _callString(_users, _usersIface, 'ListUsers');
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      final permsJson = (m['permissions'] as Map<String, dynamic>?) ?? {};
      final perms = <String, String>{};
      for (final f in kFeatures) {
        final lvl = permsJson[f] as Map<String, dynamic>?;
        perms[f] = _grantToCode(lvl);
      }
      return AppUser(
        name: m['name'] as String,
        enabled: (m['enabled'] as bool?) ?? false,
        perms: perms,
      );
    }).toList();
  }

  Future<List<SessionInfo>> _fetchSessions() async {
    final json = await _callString(_users, _usersIface, 'ListSessions');
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      final remote = (m['remote'] as String?) ?? '';
      return SessionInfo(
        id: (m['id'] as String?) ?? '',
        username: (m['user'] as String?) ?? '',
        device: remote,
        ip: remote,
        since: _relativeSince(m['created']),
      );
    }).toList();
  }

  static String _grantToCode(Map<String, dynamic>? level) {
    if (level == null) return 'none';
    final read = level['read'] == true;
    final write = level['write'] == true;
    if (write) return 'rw';
    if (read) return 'r';
    return 'none';
  }

  static Map<String, bool> _codeToGrant(String code) {
    switch (code) {
      case 'rw':
        return {'read': true, 'write': true};
      case 'r':
        return {'read': true, 'write': false};
      default:
        return {'read': false, 'write': false};
    }
  }

  static String _relativeSince(dynamic created) {
    if (created is! num) return '';
    final ts = DateTime.fromMillisecondsSinceEpoch((created * 1000).round());
    final d = DateTime.now().difference(ts);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  CpuStat _parseCpu(Map<String, dynamic> m) {
    final cores = (m['cores_info'] as List<dynamic>?) ?? const [];
    final temps = cores
        .map((c) => ((c as Map<String, dynamic>)['temperature'] as num?)?.toDouble() ?? 0)
        .where((t) => t > 0)
        .toList();
    final avgTemp = temps.isEmpty ? 0 : (temps.reduce((a, b) => a + b) / temps.length).round();
    final load = (m['avg_load'] as List<dynamic>?)
            ?.map((v) => (v as num).toDouble().toStringAsFixed(2))
            .join(', ') ??
        ((m['load'] as num?)?.toStringAsFixed(2) ?? '—');
    return CpuStat(
      usage: (m['cpu_usage'] as num?)?.toDouble() ?? 0,
      load: load,
      avgTemp: avgTemp,
      fanRpm: (m['cpu_fan_speed'] as num?)?.round() ?? 0,
    );
  }

  List<CoreStat> _parseCores(Map<String, dynamic> m) {
    final cores = (m['cores_info'] as List<dynamic>?) ?? const [];
    return cores.map((c) {
      final cm = c as Map<String, dynamic>;
      final mhz = (cm['frequency'] as num?)?.toDouble() ?? 0;
      return CoreStat(
        id: (cm['id'] as num?)?.toInt() ?? 0,
        usage: (cm['usage'] as num?)?.toDouble() ?? 0,
        freq: double.parse((mhz / 1000).toStringAsFixed(2)),
        temp: (cm['temperature'] as num?)?.round() ?? 0,
      );
    }).toList();
  }

  PowerStat _parsePower(Map<String, dynamic> m) {
    final b = (m['battery_info'] as Map<String, dynamic>?) ?? const {};
    final acPlugged = b['is_ac_plugged'] == true;
    return PowerStat(
      source: acPlugged ? 'AC' : 'Battery',
      batteryPct: (b['battery_level'] as num?)?.round() ?? 0,
      charging: b['is_charging'] == true,
      watts: (b['power_consumption'] as num?)?.toDouble() ?? 0,
    );
  }

  BatteryThreshold _parseThreshold(Map<String, dynamic> m) {
    final b = (m['battery_info'] as Map<String, dynamic>?) ?? const {};
    return BatteryThreshold(
      (b['charging_start_threshold'] as num?)?.round() ?? _snapshot.batteryThreshold.start,
      (b['charging_stop_threshold'] as num?)?.round() ?? _snapshot.batteryThreshold.stop,
    );
  }

  List<BatteryInfo> _parseBatteries(Map<String, dynamic> m) {
    final b = (m['battery_info'] as Map<String, dynamic>?);
    if (b == null) return const [];
    final level = (b['battery_level'] as num?)?.round() ?? 0;
    if (level == 0 && b['is_ac_plugged'] == true && b['power_consumption'] == null) {
      // No real battery reported.
      return const [];
    }
    return [
      BatteryInfo(
        name: 'Battery',
        level: level,
        charging: b['is_charging'] == true,
        health: '',
      ),
    ];
  }

  FrequencyLimits _readFreqLimits(Map<String, DBusValue> props) {
    final v = props['FrequencyLimits'];
    if (v == null) return const FrequencyLimits(400, 4800);
    final s = v.asStruct();
    final min = (s[0].asUint32() / 1000).round();
    final max = (s[1].asUint32() / 1000).round();
    return FrequencyLimits(min, max);
  }

  Map<String, ProfileConfig> _parseConfig(
      String json, FrequencyLimits limits, List<String> govs) {
    final data = (jsonDecode(json) as Map<String, dynamic>?) ?? {};
    final ignore = (data['power_supply_ignore_list'] as Map<String, dynamic>?)?.keys.toList() ?? [];
    ProfileConfig build(String section) {
      final s = (data[section] as Map<String, dynamic>?) ?? {};
      int freq(String key, int fallback) {
        final raw = s[key];
        if (raw == null) return fallback;
        final khz = raw is num ? raw.toInt() : int.tryParse('$raw') ?? (fallback * 1000);
        return (khz / 1000).round();
      }

      return ProfileConfig(
        governor: (s['governor'] as String?) ?? (govs.isNotEmpty ? govs.first : 'performance'),
        epp: (s['energy_performance_preference'] as String?) ?? '',
        epb: (s['energy_perf_bias'] as String?) ?? '',
        platformProfile: (s['platform_profile'] as String?) ?? '',
        turboMode: (s['turbo'] as String?) ?? 'auto',
        minFreq: freq('scaling_min_freq', limits.min),
        maxFreq: freq('scaling_max_freq', limits.max),
        ignoreList: List<String>.from(ignore),
      );
    }

    return {'charger': build('charger'), 'battery': build('battery')};
  }

  Map<String, dynamic> _profileToJson(ProfileConfig c) {
    final out = <String, dynamic>{
      'turbo': c.turboMode,
      'scaling_min_freq': c.minFreq * 1000,
      'scaling_max_freq': c.maxFreq * 1000,
    };
    if (c.governor.isNotEmpty) out['governor'] = c.governor;
    if (c.epp.isNotEmpty) out['energy_performance_preference'] = c.epp;
    if (c.epb.isNotEmpty) out['energy_perf_bias'] = c.epb;
    if (c.platformProfile.isNotEmpty) out['platform_profile'] = c.platformProfile;
    return out;
  }

  void _seedHistory(Map<String, dynamic> m) {
    _history.clear();
    _pushHistory(m);
  }

  void _pushHistory(Map<String, dynamic> m) {
    final cpu = _parseCpu(m);
    final power = _parsePower(m);
    _history.add(HistPoint(cpu.usage.round(), cpu.avgTemp, power.watts));
    if (_history.length > _historyLength) {
      _history.removeRange(0, _history.length - _historyLength);
    }
  }

  static String _errorText(DBusMethodResponseException e) {
    final vals = e.response.values;
    if (vals.isNotEmpty) return vals.first.toNative().toString();
    return e.errorName;
  }

  static String _fromEngineGovernor(String v) => v == 'default' ? 'auto' : v;
  static String _toEngineGovernor(String v) => v == 'auto' ? 'default' : v;

  static String _readString(DBusValue? v) => v == null ? '' : v.asString();
  static List<String> _readStringArray(DBusValue? v) =>
      v == null ? const [] : v.asStringArray().toList();
}
