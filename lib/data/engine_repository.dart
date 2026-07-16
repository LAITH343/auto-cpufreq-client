import '../models/models.dart';

/// An immutable snapshot of everything the engine currently reports. The
/// repository emits a new snapshot on every live tick and after every
/// successful mutation.
class EngineSnapshot {
  final CpuStat cpu;
  final List<CoreStat> cores;
  final List<HistPoint> history;
  final PowerStat power;

  final String governorOverride; // 'auto' | 'performance' | 'powersave'
  final String turboOverride; // 'auto' | 'always' | 'never'

  /// Saved config keyed by profile ('charger' | 'battery').
  final Map<String, ProfileConfig> config;
  final FrequencyLimits freqLimits;

  final BatteryThreshold batteryThreshold;
  final bool conservationMode;
  final bool bluetoothBoot;
  final List<BatteryInfo> batteries;

  final List<AppUser> users;
  final List<SessionInfo> sessions;

  final UpdateInfo update;
  final String appVersion;
  final String engineVersion;

  const EngineSnapshot({
    required this.cpu,
    required this.cores,
    required this.history,
    required this.power,
    required this.governorOverride,
    required this.turboOverride,
    required this.config,
    required this.freqLimits,
    required this.batteryThreshold,
    required this.conservationMode,
    required this.bluetoothBoot,
    required this.batteries,
    required this.users,
    required this.sessions,
    required this.update,
    required this.appVersion,
    required this.engineVersion,
  });

  EngineSnapshot copyWith({
    CpuStat? cpu,
    List<CoreStat>? cores,
    List<HistPoint>? history,
    PowerStat? power,
    String? governorOverride,
    String? turboOverride,
    Map<String, ProfileConfig>? config,
    BatteryThreshold? batteryThreshold,
    bool? conservationMode,
    bool? bluetoothBoot,
    List<BatteryInfo>? batteries,
    List<AppUser>? users,
    List<SessionInfo>? sessions,
    UpdateInfo? update,
  }) =>
      EngineSnapshot(
        cpu: cpu ?? this.cpu,
        cores: cores ?? this.cores,
        history: history ?? this.history,
        power: power ?? this.power,
        governorOverride: governorOverride ?? this.governorOverride,
        turboOverride: turboOverride ?? this.turboOverride,
        config: config ?? this.config,
        freqLimits: freqLimits,
        batteryThreshold: batteryThreshold ?? this.batteryThreshold,
        conservationMode: conservationMode ?? this.conservationMode,
        bluetoothBoot: bluetoothBoot ?? this.bluetoothBoot,
        batteries: batteries ?? this.batteries,
        users: users ?? this.users,
        sessions: sessions ?? this.sessions,
        update: update ?? this.update,
        appVersion: appVersion,
        engineVersion: engineVersion,
      );
}

/// Choice lists the config screen presents. In a real transport these come
/// from the device's `/v1/meta` and reported capabilities.
class EngineChoices {
  static const governors = ['performance', 'powersave', 'ondemand', 'schedutil'];
  static const epp = ['performance', 'balance_performance', 'balance_power', 'power'];
  static const epb = ['0', '4', '6', '8', '15'];
  static const platform = ['performance', 'balanced', 'low-power', 'quiet'];
  static const turboMode = ['auto', 'always', 'never'];
}

/// What a given connection is allowed to do. D-Bus connections have full
/// access plus user management; HTTP connections carry the logged-in user's
/// permission matrix and never expose user management.
class EngineCapabilities {
  final bool hasUserManagement;
  final Permissions permissions;
  const EngineCapabilities({
    required this.hasUserManagement,
    required this.permissions,
  });
}

/// The single interface every transport implements. Screens only ever talk to
/// this — never to a concrete D-Bus or HTTP client.
abstract class EngineRepository {
  EngineCapabilities get capabilities;
  EngineSnapshot get snapshot;
  Stream<EngineSnapshot> get stream;

  Future<void> setGovernorOverride(String value);
  Future<void> setTurboOverride(String value);

  /// Persists [cfg] for [profile]. Throws [ConfigValidationError] if the
  /// engine rejects it (e.g. min ≥ max frequency).
  Future<void> applyConfig(String profile, ProfileConfig cfg);

  Future<void> setBatteryThreshold(int start, int stop);
  Future<void> setConservationMode(bool enabled);
  Future<void> setBluetoothBoot(bool enabled);

  // User management — only valid when [capabilities.hasUserManagement].
  Future<void> createUser(String username, String password);
  Future<void> deleteUser(int id);
  Future<void> setUserEnabled(int id, bool enabled);
  Future<void> setUserPermission(int id, String feature, String code);
  Future<void> resetPassword(int id);
  Future<void> revokeSession(String id);

  Future<void> checkForUpdate();
  Future<void> startUpdateInstall();

  void dispose();
}
