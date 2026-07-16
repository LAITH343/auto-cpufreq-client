/// Plain data models shared across the app. These mirror the shapes the
/// engine (locally over D-Bus, or remotely over the HTTP/S gateway) exposes.
library;

/// Permission access levels for a single feature.
enum Access { none, read, write }

Access accessFromCode(String code) {
  switch (code) {
    case 'rw':
      return Access.write;
    case 'r':
      return Access.read;
    default:
      return Access.none;
  }
}

String accessToCode(Access a) {
  switch (a) {
    case Access.write:
      return 'rw';
    case Access.read:
      return 'r';
    case Access.none:
      return 'none';
  }
}

/// The five permission-controlled features, matching the gateway's matrix.
const List<String> kFeatures = ['stats', 'controls', 'config', 'battery', 'bluetooth'];

/// A user's per-feature permission set. Values are 'none' | 'r' | 'rw'.
class Permissions {
  final Map<String, String> byFeature;
  const Permissions(this.byFeature);

  factory Permissions.all() =>
      Permissions({for (final f in kFeatures) f: 'rw'});

  String codeFor(String feature) => byFeature[feature] ?? 'none';

  bool canRead(String feature) {
    final v = codeFor(feature);
    return v == 'r' || v == 'rw';
  }

  bool canWrite(String feature) => codeFor(feature) == 'rw';

  Permissions copyWith(Map<String, String> overrides) =>
      Permissions({...byFeature, ...overrides});
}

class CoreStat {
  final int id;
  final double usage;
  final double freq;
  final int temp;
  const CoreStat({
    required this.id,
    required this.usage,
    required this.freq,
    required this.temp,
  });

  CoreStat copyWith({double? usage, double? freq, int? temp}) => CoreStat(
        id: id,
        usage: usage ?? this.usage,
        freq: freq ?? this.freq,
        temp: temp ?? this.temp,
      );
}

class CpuStat {
  final double usage;
  final String load;
  final int avgTemp;
  final int fanRpm;
  const CpuStat({
    required this.usage,
    required this.load,
    required this.avgTemp,
    required this.fanRpm,
  });

  CpuStat copyWith({double? usage, String? load, int? avgTemp, int? fanRpm}) =>
      CpuStat(
        usage: usage ?? this.usage,
        load: load ?? this.load,
        avgTemp: avgTemp ?? this.avgTemp,
        fanRpm: fanRpm ?? this.fanRpm,
      );
}

class PowerStat {
  final String source; // 'AC' | 'Battery'
  final int batteryPct;
  final bool charging;
  final double watts;
  const PowerStat({
    required this.source,
    required this.batteryPct,
    required this.charging,
    required this.watts,
  });

  PowerStat copyWith({String? source, int? batteryPct, bool? charging, double? watts}) =>
      PowerStat(
        source: source ?? this.source,
        batteryPct: batteryPct ?? this.batteryPct,
        charging: charging ?? this.charging,
        watts: watts ?? this.watts,
      );
}

/// One sample of usage %, temp °C, and wattage for the history charts.
class HistPoint {
  final int u;
  final int t;
  final double w;
  const HistPoint(this.u, this.t, this.w);
}

/// A single profile's configuration (the Charger or Battery tab).
class ProfileConfig {
  final String governor;
  final String epp;
  final String epb;
  final String platformProfile;
  final String turboMode;
  final int minFreq;
  final int maxFreq;
  final List<String> ignoreList;

  const ProfileConfig({
    required this.governor,
    required this.epp,
    required this.epb,
    required this.platformProfile,
    required this.turboMode,
    required this.minFreq,
    required this.maxFreq,
    required this.ignoreList,
  });

  ProfileConfig copyWith({
    String? governor,
    String? epp,
    String? epb,
    String? platformProfile,
    String? turboMode,
    int? minFreq,
    int? maxFreq,
    List<String>? ignoreList,
  }) =>
      ProfileConfig(
        governor: governor ?? this.governor,
        epp: epp ?? this.epp,
        epb: epb ?? this.epb,
        platformProfile: platformProfile ?? this.platformProfile,
        turboMode: turboMode ?? this.turboMode,
        minFreq: minFreq ?? this.minFreq,
        maxFreq: maxFreq ?? this.maxFreq,
        ignoreList: ignoreList ?? this.ignoreList,
      );

  bool equals(ProfileConfig o) =>
      governor == o.governor &&
      epp == o.epp &&
      epb == o.epb &&
      platformProfile == o.platformProfile &&
      turboMode == o.turboMode &&
      minFreq == o.minFreq &&
      maxFreq == o.maxFreq &&
      _listEq(ignoreList, o.ignoreList);

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class FrequencyLimits {
  final int min;
  final int max;
  const FrequencyLimits(this.min, this.max);
}

class BatteryThreshold {
  final int start;
  final int stop;
  const BatteryThreshold(this.start, this.stop);
  BatteryThreshold copyWith({int? start, int? stop}) =>
      BatteryThreshold(start ?? this.start, stop ?? this.stop);
}

class BatteryInfo {
  final String name;
  final int level;
  final bool charging;
  final String health;
  const BatteryInfo({
    required this.name,
    required this.level,
    required this.charging,
    required this.health,
  });
}

class AppUser {
  final int id;
  final String username;
  final bool enabled;
  final Map<String, String> perms;
  const AppUser({
    required this.id,
    required this.username,
    required this.enabled,
    required this.perms,
  });

  AppUser copyWith({bool? enabled, Map<String, String>? perms}) => AppUser(
        id: id,
        username: username,
        enabled: enabled ?? this.enabled,
        perms: perms ?? this.perms,
      );
}

class SessionInfo {
  final String id;
  final String username;
  final String device;
  final String ip;
  final String since;
  const SessionInfo({
    required this.id,
    required this.username,
    required this.device,
    required this.ip,
    required this.since,
  });
}

enum UpdateCheck { checking, available, upToDate }

enum UpdatePhase { idle, downloading, installing, done }

class UpdateInfo {
  final UpdateCheck check;
  final String latest;
  final UpdatePhase phase;
  final int progress;
  const UpdateInfo({
    required this.check,
    required this.latest,
    required this.phase,
    required this.progress,
  });

  UpdateInfo copyWith({
    UpdateCheck? check,
    String? latest,
    UpdatePhase? phase,
    int? progress,
  }) =>
      UpdateInfo(
        check: check ?? this.check,
        latest: latest ?? this.latest,
        phase: phase ?? this.phase,
        progress: progress ?? this.progress,
      );
}

enum Transport { dbus, https }

class Device {
  final String id;
  final String name;
  final String host;
  final int port;
  final Transport transport;
  final bool online;
  final bool gatewayDisabled;
  const Device({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.transport,
    required this.online,
    this.gatewayDisabled = false,
  });

  String get hostLabel => port > 0 ? '$host:$port' : host;
  String get badge => transport == Transport.dbus ? 'D-Bus' : 'HTTPS';
}

/// Raised by the repository when the engine rejects a config as invalid.
class ConfigValidationError implements Exception {
  final String message;
  ConfigValidationError(this.message);
  @override
  String toString() => message;
}

/// Raised when the server refuses an action for lack of permission.
class PermissionDeniedError implements Exception {
  PermissionDeniedError();
}
