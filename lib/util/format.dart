import '../data/engine_repository.dart';
import '../l10n/strings.dart';

/// Governor/turbo labels and the "effective" profile derivation, shared by the
/// dashboard and controls screens.
class Labels {
  static String governor(AppStrings s, String code) {
    switch (code) {
      case 'auto':
        return s.t('govAuto');
      case 'performance':
        return s.t('govPerformance');
      case 'powersave':
        return s.t('govPowersave');
      default:
        return code;
    }
  }

  static String turbo(AppStrings s, String code) {
    switch (code) {
      case 'auto':
        return s.t('govAuto');
      case 'always':
        return s.t('turboAlways');
      case 'never':
        return s.t('turboNever');
      default:
        return code;
    }
  }

  static String effectiveGovernor(EngineSnapshot snap) {
    if (snap.governorOverride != 'auto') return snap.governorOverride;
    return snap.power.source == 'AC' ? 'performance' : 'powersave';
  }

  static String effectiveTurbo(EngineSnapshot snap) =>
      snap.turboOverride != 'auto' ? snap.turboOverride : 'auto';

  /// Converts a Celsius temperature to the display unit and formats it.
  static String temp(int celsius, String unit) {
    if (unit == 'F') return '${(celsius * 9 / 5 + 32).round()}°F';
    return '$celsius°C';
  }
}
