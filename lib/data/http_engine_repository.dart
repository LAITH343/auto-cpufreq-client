import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/models.dart';
import 'cert_store.dart';
import 'engine_repository.dart';

const int _historyLength = 60;
const String _appVersion = '1.0.0';

/// Everything needed to reach a remote gateway. [certPath] optionally pins a
/// PEM certificate for this connection only (for a self-signed HTTPS server);
/// when set, that certificate is both added to the trust store and pinned, so a
/// hostname or CA mismatch is accepted only for that exact certificate.
class RemoteConfig {
  final String host;
  final int port;
  final bool useHttps;
  final String? certPath;
  final String username;
  final String password;

  const RemoteConfig({
    required this.host,
    required this.port,
    required this.useHttps,
    required this.username,
    required this.password,
    this.certPath,
  });

  String get scheme => useHttps ? 'https' : 'http';
  String get origin => '$scheme://$host:$port';
  String get wsScheme => useHttps ? 'wss' : 'ws';
}

/// Raised when the gateway rejects the supplied credentials, or the session
/// token has expired / been revoked.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Raised on the first HTTPS connection to a server whose certificate isn't
/// trusted by the system, or when a previously pinned certificate has changed.
/// Carries the certificate the server actually presented so the UI can run the
/// compare-and-trust (TOFU) step and pin it. [changed] is true when a pin was
/// supplied but did not match (the server's cert rotated).
class UntrustedCertException implements Exception {
  final List<int> der;
  final String fingerprint;
  final bool changed;
  UntrustedCertException({
    required this.der,
    required this.fingerprint,
    required this.changed,
  });
  @override
  String toString() => 'Untrusted server certificate ($fingerprint).';
}

/// Captures the leaf certificate a server presents during a rejected TLS
/// handshake so it can be shown to the user.
class _CertCapture {
  List<int>? der;
}

/// [EngineRepository] backed by the remote `auto-cpufreq-gateway` over HTTP/S
/// and a WebSocket event stream. Access is scoped to the logged-in user's
/// permission matrix and there is no user management over this transport.
class HttpEngineRepository implements EngineRepository {
  final RemoteConfig _cfg;
  final HttpClient _http;
  final String _token;

  final StreamController<EngineSnapshot> _controller =
      StreamController<EngineSnapshot>.broadcast();
  final List<HistPoint> _history = [];

  WebSocket? _ws;
  StreamSubscription? _wsSub;
  bool _disposed = false;

  late EngineSnapshot _snapshot;

  @override
  final EngineCapabilities capabilities;

  HttpEngineRepository._(this._cfg, this._http, this._token, this.capabilities);

  /// Logs in, takes an initial snapshot scoped to the granted permissions, and
  /// opens the live event stream. Throws [AuthException] on bad credentials,
  /// [UntrustedCertException] when the server's HTTPS certificate needs the
  /// TOFU trust step, [EngineUnavailableException] if the gateway/engine is
  /// unreachable.
  static Future<HttpEngineRepository> connect(RemoteConfig cfg) async {
    final capture = _CertCapture();
    final pinned = cfg.useHttps && (cfg.certPath?.isNotEmpty ?? false);
    final http = _makeHttpClient(cfg, capture);
    final String token;
    final Permissions perms;
    try {
      final login = await _login(http, cfg);
      token = login.$1;
      perms = login.$2;
    } on HandshakeException {
      http.close(force: true);
      final der = capture.der;
      if (der != null) {
        // The certificate was rejected by our callback: untrusted on first use,
        // or a pinned cert that no longer matches.
        throw UntrustedCertException(
          der: der,
          fingerprint: CertStore.fingerprintOf(der),
          changed: pinned,
        );
      }
      throw EngineUnavailableException('TLS handshake failed.');
    } catch (e) {
      http.close(force: true);
      rethrow;
    }

    final caps = EngineCapabilities(hasUserManagement: false, permissions: perms);
    final repo = HttpEngineRepository._(cfg, http, token, caps);
    try {
      await repo._bootstrap();
    } catch (e) {
      repo.dispose();
      if (e is AuthException || e is EngineUnavailableException) rethrow;
      throw EngineUnavailableException('Gateway is not reachable: $e');
    }
    return repo;
  }

  /// Checks whether the server's HTTPS certificate is already trusted (system
  /// CA or the pin in [cfg.certPath]). Returns normally when trusted or when the
  /// connection is plain HTTP. Throws [UntrustedCertException] carrying the live
  /// certificate for the TOFU step, or [EngineUnavailableException] if the
  /// gateway can't be reached. Run this before showing the login form.
  static Future<void> probe(RemoteConfig cfg) async {
    if (!cfg.useHttps) return;
    final capture = _CertCapture();
    final pinned = cfg.certPath?.isNotEmpty ?? false;
    final http = _makeHttpClient(cfg, capture);
    try {
      final req = await http.getUrl(Uri.parse('${cfg.origin}/v1/meta'));
      final res = await req.close();
      await res.drain<void>();
    } on HandshakeException {
      final der = capture.der;
      if (der != null) {
        throw UntrustedCertException(
          der: der,
          fingerprint: CertStore.fingerprintOf(der),
          changed: pinned,
        );
      }
      throw EngineUnavailableException('TLS handshake failed.');
    } on SocketException catch (e) {
      throw EngineUnavailableException('Cannot reach ${cfg.origin}: ${e.message}');
    } finally {
      http.close(force: true);
    }
  }

  @override
  EngineSnapshot get snapshot => _snapshot;

  @override
  Stream<EngineSnapshot> get stream => _controller.stream;

  Permissions get _perms => capabilities.permissions;

  void _emit() {
    if (!_controller.isClosed) _controller.add(_snapshot);
  }

  // ---- transport ----

  static HttpClient _makeHttpClient(RemoteConfig cfg, _CertCapture capture) {
    SecurityContext? ctx;
    List<int>? pinnedDer;
    if (cfg.useHttps && (cfg.certPath?.isNotEmpty ?? false)) {
      ctx = SecurityContext(withTrustedRoots: true);
      try {
        ctx.setTrustedCertificates(cfg.certPath!);
      } catch (_) {
        // Not a valid trust anchor on its own; pinning below still applies.
      }
      pinnedDer = _derFromPemFile(cfg.certPath!);
    }
    final client = HttpClient(context: ctx);
    // Fires only when the system trust store rejects the cert. Capture what the
    // server presented (for the TOFU prompt) and accept only an exact pin match.
    client.badCertificateCallback = (cert, host, port) {
      capture.der = cert.der;
      return pinnedDer != null && _bytesEqual(cert.der, pinnedDer);
    };
    return client;
  }

  static Future<(String, Permissions)> _login(HttpClient http, RemoteConfig cfg) async {
    final HttpClientResponse res;
    try {
      final req = await http.postUrl(Uri.parse('${cfg.origin}/v1/auth/login'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'user': cfg.username, 'password': cfg.password}));
      res = await req.close();
    } on SocketException catch (e) {
      throw EngineUnavailableException('Cannot reach ${cfg.origin}: ${e.message}');
    }
    // HandshakeException is handled by connect() for the TOFU trust flow.
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode == 401) throw AuthException('Invalid username or password.');
    if (res.statusCode == 429) {
      throw AuthException('Too many attempts. Try again later.');
    }
    if (res.statusCode != 200) {
      throw EngineUnavailableException('Login failed (${res.statusCode}).');
    }
    final m = jsonDecode(body) as Map<String, dynamic>;
    return (m['token'] as String, _permsFromMatrix(m['permissions']));
  }

  Future<Map<String, dynamic>?> _getJson(String path) async {
    final res = await _send('GET', path);
    if (res == null) return null;
    final decoded = jsonDecode(res);
    return decoded is Map<String, dynamic> ? decoded : {'_': decoded};
  }

  /// Sends an authorized request. Returns the body on 2xx (empty string for
  /// 204), or null when the caller is missing the permission (403) so bootstrap
  /// can skip that section. Maps the documented status codes to exceptions.
  Future<String?> _send(String method, String path, {Object? body}) async {
    final HttpClientRequest req;
    try {
      req = await _http.openUrl(method, Uri.parse('${_cfg.origin}$path'));
    } on SocketException catch (e) {
      throw EngineUnavailableException('Cannot reach ${_cfg.origin}: ${e.message}');
    }
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
    }
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    switch (res.statusCode) {
      case 200:
      case 204:
        return text;
      case 400:
        throw ConfigValidationError(text.isEmpty ? 'Invalid request.' : text);
      case 401:
        throw AuthException('Session expired. Sign in again.');
      case 403:
        return null;
      case 503:
        throw EngineUnavailableException('Engine unavailable.');
      default:
        throw EngineUnavailableException('Request failed (${res.statusCode}).');
    }
  }

  /// Like [_send] but treats a 403 as a hard permission error (for mutations
  /// the UI shouldn't have offered).
  Future<void> _write(String method, String path, {Object? body}) async {
    final res = await _send(method, path, body: body);
    if (res == null) throw PermissionDeniedError();
  }

  // ---- bootstrap + live stream ----

  Future<void> _bootstrap() async {
    final meta = await _getJson('/v1/meta') ?? const {};
    final report = _perms.canRead('stats') ? await _getJson('/v1/status') : null;
    final configMap = _perms.canRead('config') ? await _getJson('/v1/config') : null;
    final overrides = _perms.canRead('controls') ? await _getJson('/v1/overrides') : null;

    final limits = _limitsFrom(configMap);
    final govs = EngineChoices.governors;
    final reportMap = report ?? const {};
    _seedHistory(reportMap);

    _snapshot = EngineSnapshot(
      cpu: _parseCpu(reportMap),
      cpuModel: (reportMap['processor_model'] as String?) ?? 'CPU',
      cores: _parseCores(reportMap),
      history: List.of(_history),
      power: _parsePower(reportMap),
      governorOverride: _fromEngineGovernor((overrides?['governor'] as String?) ?? 'default'),
      turboOverride: (overrides?['turbo'] as String?) ?? 'auto',
      config: _parseConfig(configMap, limits, govs),
      freqLimits: limits,
      availableGovernors: govs,
      batteryThreshold: _parseThreshold(reportMap, const BatteryThreshold(0, 100)),
      conservationMode: false,
      bluetoothBoot: false,
      batteries: _parseBatteries(reportMap),
      users: const [],
      sessions: const [],
      update: const UpdateInfo(
          check: UpdateCheck.upToDate, latest: '', phase: UpdatePhase.idle, progress: 0),
      appVersion: _appVersion,
      engineVersion: (meta['version'] as String?) ?? '',
    );

    if (_perms.canRead('stats')) await _openEvents();
    _emit();
  }

  Future<void> _openEvents() async {
    final url = '${_cfg.wsScheme}://${_cfg.host}:${_cfg.port}/v1/events?token=$_token';
    try {
      _ws = await WebSocket.connect(url, customClient: _http);
    } catch (_) {
      // Live stream is best-effort; the snapshot already holds a first reading.
      return;
    }
    _wsSub = _ws!.listen(
      _onFrame,
      onDone: () {},
      onError: (_) {},
      cancelOnError: true,
    );
  }

  void _onFrame(dynamic data) {
    if (data is! String) return;
    final Map<String, dynamic> m;
    try {
      m = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (m['type']) {
      case 'stats':
        final report = (m['report'] as Map<String, dynamic>?) ?? const {};
        _pushHistory(report);
        _snapshot = _snapshot.copyWith(
          cpu: _parseCpu(report),
          cores: _parseCores(report),
          power: _parsePower(report),
          history: List.of(_history),
          batteryThreshold: _parseThreshold(report, _snapshot.batteryThreshold),
          batteries: _parseBatteries(report),
        );
        _emit();
        break;
      case 'power_source':
        break;
      case 'profile':
        final gov = m['governor'] as String?;
        if (gov != null) {
          _snapshot = _snapshot.copyWith(governorOverride: _fromEngineGovernor(gov));
          _emit();
        }
        break;
      case 'config':
        _refreshConfig();
        break;
    }
  }

  Future<void> _refreshConfig() async {
    if (!_perms.canRead('config')) return;
    final cfg = await _getJson('/v1/config');
    _snapshot = _snapshot.copyWith(
        config: _parseConfig(cfg, _snapshot.freqLimits, _snapshot.availableGovernors));
    _emit();
  }

  // ---- mutations ----

  @override
  Future<void> setGovernorOverride(String value) async {
    await _write('POST', '/v1/overrides', body: {'governor': _toEngineGovernor(value)});
    _snapshot = _snapshot.copyWith(governorOverride: value);
    _emit();
  }

  @override
  Future<void> setTurboOverride(String value) async {
    await _write('POST', '/v1/overrides', body: {'turbo': value});
    _snapshot = _snapshot.copyWith(turboOverride: value);
    _emit();
  }

  @override
  Future<void> applyConfig(String profile, ProfileConfig cfg) async {
    final merged = {..._snapshot.config, profile: cfg};
    final payload = <String, dynamic>{
      for (final p in ['charger', 'battery'])
        if (merged[p] != null) p: _profileToJson(merged[p]!),
      'power_supply_ignore_list': {for (final n in cfg.ignoreList) n: 'true'},
    };
    await _write('PUT', '/v1/config', body: payload);
    _snapshot = _snapshot.copyWith(config: merged);
    _emit();
  }

  @override
  Future<void> setBatteryThreshold(int start, int stop) async {
    if (start >= stop) start = stop - 1;
    if (start < 0) start = 0;
    try {
      await _write('PUT', '/v1/battery/thresholds', body: {'start': start, 'stop': stop});
      _snapshot = _snapshot.copyWith(batteryThreshold: BatteryThreshold(start, stop));
      _emit();
    } on ConfigValidationError {
      // Unsupported device / invalid range — leave state unchanged.
    }
  }

  @override
  Future<void> setConservationMode(bool enabled) async {
    try {
      await _write('PUT', '/v1/battery/conservation', body: {'enabled': enabled});
      _snapshot = _snapshot.copyWith(conservationMode: enabled);
      _emit();
    } on ConfigValidationError {
      // Not supported on this device.
    }
  }

  @override
  Future<void> setBluetoothBoot(bool enabled) async {
    await _write('PUT', '/v1/bluetooth/boot', body: {'enabled': enabled});
    _snapshot = _snapshot.copyWith(bluetoothBoot: enabled);
    _emit();
  }

  // User management is D-Bus-only; the gateway returns 404 for these routes.
  @override
  Future<void> createUser(String username, String password) async =>
      throw StateError('User management is not available over HTTP.');

  @override
  Future<void> deleteUser(String username) async =>
      throw StateError('User management is not available over HTTP.');

  @override
  Future<void> setUserEnabled(String username, bool enabled) async =>
      throw StateError('User management is not available over HTTP.');

  @override
  Future<void> setUserPermission(String username, String feature, String code) async =>
      throw StateError('User management is not available over HTTP.');

  @override
  Future<void> resetPassword(String username) async =>
      throw StateError('User management is not available over HTTP.');

  @override
  Future<void> revokeSession(String id) async =>
      throw StateError('User management is not available over HTTP.');

  @override
  Future<void> checkForUpdate() async {
    _snapshot = _snapshot.copyWith(
        update: _snapshot.update.copyWith(check: UpdateCheck.upToDate));
    _emit();
  }

  @override
  Future<void> startUpdateInstall() async {}

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _wsSub?.cancel();
    _ws?.close();
    _controller.close();
    // Best-effort logout so the gateway can drop the session, then close the
    // client once the request has been sent.
    _logout().whenComplete(() => _http.close(force: true));
  }

  Future<void> _logout() async {
    try {
      final req = await _http.openUrl('POST', Uri.parse('${_cfg.origin}/v1/auth/logout'));
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      final res = await req.close();
      await res.drain<void>();
    } catch (_) {}
  }

  // ---- parsing (report + config payloads mirror the D-Bus JSON) ----

  static Permissions _permsFromMatrix(dynamic matrix) {
    final m = (matrix as Map<String, dynamic>?) ?? const {};
    final out = <String, String>{};
    for (final f in kFeatures) {
      final lvl = m[f] as Map<String, dynamic>?;
      final read = lvl?['read'] == true;
      final write = lvl?['write'] == true;
      out[f] = write ? 'rw' : (read ? 'r' : 'none');
    }
    return Permissions(out);
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

  BatteryThreshold _parseThreshold(Map<String, dynamic> m, BatteryThreshold fallback) {
    final b = (m['battery_info'] as Map<String, dynamic>?) ?? const {};
    return BatteryThreshold(
      (b['charging_start_threshold'] as num?)?.round() ?? fallback.start,
      (b['charging_stop_threshold'] as num?)?.round() ?? fallback.stop,
    );
  }

  List<BatteryInfo> _parseBatteries(Map<String, dynamic> m) {
    final b = (m['battery_info'] as Map<String, dynamic>?);
    if (b == null) return const [];
    final level = (b['battery_level'] as num?)?.round() ?? 0;
    if (level == 0 && b['is_ac_plugged'] == true && b['power_consumption'] == null) {
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

  static FrequencyLimits _limitsFrom(Map<String, dynamic>? config) {
    var min = 400, max = 4800;
    if (config != null) {
      for (final section in ['charger', 'battery']) {
        final s = config[section] as Map<String, dynamic>?;
        if (s == null) continue;
        final lo = _khz(s['scaling_min_freq']);
        final hi = _khz(s['scaling_max_freq']);
        if (lo != null) min = lo < min ? lo : min;
        if (hi != null) max = hi > max ? hi : max;
      }
    }
    return FrequencyLimits(min, max);
  }

  static int? _khz(dynamic raw) {
    if (raw == null) return null;
    final khz = raw is num ? raw.toInt() : int.tryParse('$raw');
    return khz == null ? null : (khz / 1000).round();
  }

  Map<String, ProfileConfig> _parseConfig(
      Map<String, dynamic>? config, FrequencyLimits limits, List<String> govs) {
    final data = config ?? const {};
    final ignore =
        (data['power_supply_ignore_list'] as Map<String, dynamic>?)?.keys.toList() ?? [];
    ProfileConfig build(String section) {
      final s = (data[section] as Map<String, dynamic>?) ?? {};
      int freq(String key, int fallback) => _khz(s[key]) ?? fallback;
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

  static String _fromEngineGovernor(String v) => v == 'default' ? 'auto' : v;
  static String _toEngineGovernor(String v) => v == 'auto' ? 'default' : v;

  // ---- certificate pinning helpers ----

  static List<int>? _derFromPemFile(String path) {
    try {
      final pem = File(path).readAsStringSync();
      final match = RegExp(
              r'-----BEGIN CERTIFICATE-----([\s\S]*?)-----END CERTIFICATE-----')
          .firstMatch(pem);
      if (match == null) return null;
      final b64 = match.group(1)!.replaceAll(RegExp(r'\s'), '');
      return base64.decode(b64);
    } catch (_) {
      return null;
    }
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
