import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../theme/palette.dart';

/// App-wide preferences. In a real build these persist to disk; here they live
/// for the session.
class SettingsState {
  final bool dark;
  final Color? accent; // null → mode default
  final String lang;
  final String tempUnit; // 'C' | 'F'
  final String chartHistory;
  final bool notifyBatteryStop;
  final bool notifyTemp;
  final int tempLimit;
  final String deviceName;
  final String reconnectBehavior; // 'auto' | 'manual'

  const SettingsState({
    this.dark = true,
    this.accent,
    this.lang = 'en',
    this.tempUnit = 'C',
    this.chartHistory = '30m',
    this.notifyBatteryStop = true,
    this.notifyTemp = true,
    this.tempLimit = 85,
    this.deviceName = 'office-workstation',
    this.reconnectBehavior = 'auto',
  });

  Color get effectiveAccent => accent ?? Palette.defaultAccent(dark);

  SettingsState copyWith({
    bool? dark,
    Object? accent = _sentinel,
    String? lang,
    String? tempUnit,
    String? chartHistory,
    bool? notifyBatteryStop,
    bool? notifyTemp,
    int? tempLimit,
    String? deviceName,
    String? reconnectBehavior,
  }) =>
      SettingsState(
        dark: dark ?? this.dark,
        accent: accent == _sentinel ? this.accent : accent as Color?,
        lang: lang ?? this.lang,
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

  void setDark(bool dark) => state = state.copyWith(dark: dark);
  void setAccent(Color accent) => state = state.copyWith(accent: accent);
  void setLang(String lang) => state = state.copyWith(lang: lang);
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

/// Derived color palette for the current theme + accent.
final paletteProvider = Provider<Palette>((ref) {
  final s = ref.watch(settingsProvider);
  return s.dark ? Palette.dark(s.effectiveAccent) : Palette.light(s.effectiveAccent);
});

/// Derived string resolver for the current language.
final stringsProvider = Provider<AppStrings>((ref) {
  final lang = ref.watch(settingsProvider.select((s) => s.lang));
  return AppStrings(lang);
});
