import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../theme/palette.dart';
import 'platform_controller.dart';

/// Theme selection. `system` follows the OS appearance (fallback: light).
enum AppThemeMode { system, light, dark }

/// Language selection. `system` follows the OS language when supported
/// (fallback: English).
const String kLanguageSystem = 'system';

/// App-wide preferences. In a real build these persist to disk; here they live
/// for the session.
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
  SettingsController() : super(const SettingsState());

  void setThemeMode(AppThemeMode mode) => state = state.copyWith(themeMode: mode);
  void setAccent(Color accent) => state = state.copyWith(accent: accent);
  void setLanguageMode(String mode) => state = state.copyWith(languageMode: mode);
  void setTempUnit(String unit) => state = state.copyWith(tempUnit: unit);
  void setChartHistory(String v) => state = state.copyWith(chartHistory: v);
  void toggleNotifyBatteryStop() =>
      state = state.copyWith(notifyBatteryStop: !state.notifyBatteryStop);
  void toggleNotifyTemp() => state = state.copyWith(notifyTemp: !state.notifyTemp);
  void setDeviceName(String v) => state = state.copyWith(deviceName: v);
  void setReconnectBehavior(String v) => state = state.copyWith(reconnectBehavior: v);
}

final settingsProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) => SettingsController());

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
