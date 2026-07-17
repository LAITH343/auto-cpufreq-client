import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../theme/palette.dart';
import 'platform_controller.dart';

/// Theme selection. `system` follows the OS appearance (fallback: light).
enum AppThemeMode { system, light, dark }

/// Language selection. `system` follows the OS language when supported
/// (fallback: English).
const String kLanguageSystem = 'system';

/// App-wide preferences, persisted to disk via [SharedPreferences].
class SettingsState {
  final AppThemeMode themeMode;
  final Color? accent; // null → mode default
  final String languageMode; // 'system' | 'en' | 'ar'
  final String tempUnit; // 'C' | 'F'
  final String chartHistory;
  final bool notifyBatteryStop;
  final bool notifyTemp;
  final int tempLimit;
  final String deviceName;
  final String reconnectBehavior; // 'auto' | 'manual'

  const SettingsState({
    this.themeMode = AppThemeMode.system,
    this.accent,
    this.languageMode = kLanguageSystem,
    this.tempUnit = 'C',
    this.chartHistory = '30m',
    this.notifyBatteryStop = true,
    this.notifyTemp = true,
    this.tempLimit = 85,
    this.deviceName = 'office-workstation',
    this.reconnectBehavior = 'auto',
  });

  SettingsState copyWith({
    AppThemeMode? themeMode,
    Object? accent = _sentinel,
    String? languageMode,
    String? tempUnit,
    String? chartHistory,
    bool? notifyBatteryStop,
    bool? notifyTemp,
    int? tempLimit,
    String? deviceName,
    String? reconnectBehavior,
  }) =>
      SettingsState(
        themeMode: themeMode ?? this.themeMode,
        accent: accent == _sentinel ? this.accent : accent as Color?,
        languageMode: languageMode ?? this.languageMode,
        tempUnit: tempUnit ?? this.tempUnit,
        chartHistory: chartHistory ?? this.chartHistory,
        notifyBatteryStop: notifyBatteryStop ?? this.notifyBatteryStop,
        notifyTemp: notifyTemp ?? this.notifyTemp,
        tempLimit: tempLimit ?? this.tempLimit,
        deviceName: deviceName ?? this.deviceName,
        reconnectBehavior: reconnectBehavior ?? this.reconnectBehavior,
      );

  static const Object _sentinel = Object();
}

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static const _kThemeMode = 'settings.themeMode';
  static const _kAccent = 'settings.accent';
  static const _kLanguageMode = 'settings.languageMode';
  static const _kTempUnit = 'settings.tempUnit';
  static const _kChartHistory = 'settings.chartHistory';
  static const _kNotifyBatteryStop = 'settings.notifyBatteryStop';
  static const _kNotifyTemp = 'settings.notifyTemp';
  static const _kTempLimit = 'settings.tempLimit';
  static const _kDeviceName = 'settings.deviceName';
  static const _kReconnectBehavior = 'settings.reconnectBehavior';

  /// Reads persisted settings, falling back to the [SettingsState] defaults for
  /// any key that has never been written.
  static SettingsState _load(SharedPreferences p) {
    const d = SettingsState();
    final themeIndex = p.getInt(_kThemeMode);
    final accent = p.getInt(_kAccent);
    return SettingsState(
      themeMode: themeIndex != null && themeIndex >= 0 && themeIndex < AppThemeMode.values.length
          ? AppThemeMode.values[themeIndex]
          : d.themeMode,
      accent: accent != null ? Color(accent) : d.accent,
      languageMode: p.getString(_kLanguageMode) ?? d.languageMode,
      tempUnit: p.getString(_kTempUnit) ?? d.tempUnit,
      chartHistory: p.getString(_kChartHistory) ?? d.chartHistory,
      notifyBatteryStop: p.getBool(_kNotifyBatteryStop) ?? d.notifyBatteryStop,
      notifyTemp: p.getBool(_kNotifyTemp) ?? d.notifyTemp,
      tempLimit: p.getInt(_kTempLimit) ?? d.tempLimit,
      deviceName: p.getString(_kDeviceName) ?? d.deviceName,
      reconnectBehavior: p.getString(_kReconnectBehavior) ?? d.reconnectBehavior,
    );
  }

  void _set(SettingsState next) {
    state = next;
    _persist(next);
  }

  void _persist(SettingsState s) {
    _prefs.setInt(_kThemeMode, s.themeMode.index);
    if (s.accent == null) {
      _prefs.remove(_kAccent);
    } else {
      _prefs.setInt(_kAccent, s.accent!.toARGB32());
    }
    _prefs.setString(_kLanguageMode, s.languageMode);
    _prefs.setString(_kTempUnit, s.tempUnit);
    _prefs.setString(_kChartHistory, s.chartHistory);
    _prefs.setBool(_kNotifyBatteryStop, s.notifyBatteryStop);
    _prefs.setBool(_kNotifyTemp, s.notifyTemp);
    _prefs.setInt(_kTempLimit, s.tempLimit);
    _prefs.setString(_kDeviceName, s.deviceName);
    _prefs.setString(_kReconnectBehavior, s.reconnectBehavior);
  }

  void setThemeMode(AppThemeMode mode) => _set(state.copyWith(themeMode: mode));
  void setAccent(Color accent) => _set(state.copyWith(accent: accent));
  void setLanguageMode(String mode) => _set(state.copyWith(languageMode: mode));
  void setTempUnit(String unit) => _set(state.copyWith(tempUnit: unit));
  void setChartHistory(String v) => _set(state.copyWith(chartHistory: v));
  void toggleNotifyBatteryStop() =>
      _set(state.copyWith(notifyBatteryStop: !state.notifyBatteryStop));
  void toggleNotifyTemp() => _set(state.copyWith(notifyTemp: !state.notifyTemp));
  void setDeviceName(String v) => _set(state.copyWith(deviceName: v));
  void setReconnectBehavior(String v) => _set(state.copyWith(reconnectBehavior: v));
}

/// Provides the app-wide [SharedPreferences] instance. Overridden in `main()`
/// with the concrete instance loaded before the app starts.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final settingsProvider = StateNotifierProvider<SettingsController, SettingsState>(
  (ref) => SettingsController(ref.watch(sharedPreferencesProvider)),
);

/// Effective dark/light after resolving "follow system" (fallback: light).
final isDarkProvider = Provider<bool>((ref) {
  final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
  switch (mode) {
    case AppThemeMode.light:
      return false;
    case AppThemeMode.dark:
      return true;
    case AppThemeMode.system:
      return ref.watch(platformProvider.select((p) => p.brightness)) == Brightness.dark;
  }
});

/// Effective language after resolving "follow system" (fallback: en).
final effectiveLangProvider = Provider<String>((ref) {
  final mode = ref.watch(settingsProvider.select((s) => s.languageMode));
  if (mode != kLanguageSystem) return mode;
  final code = ref.watch(platformProvider.select((p) => p.languageCode));
  return AppStrings.supported.contains(code) ? code : 'en';
});

/// Derived color palette for the current effective theme + accent.
final paletteProvider = Provider<Palette>((ref) {
  final dark = ref.watch(isDarkProvider);
  final accent = ref.watch(settingsProvider.select((s) => s.accent)) ?? Palette.defaultAccent(dark);
  return dark ? Palette.dark(accent) : Palette.light(accent);
});

/// Derived string resolver for the current effective language.
final stringsProvider = Provider<AppStrings>((ref) {
  return AppStrings(ref.watch(effectiveLangProvider));
});
