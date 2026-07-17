import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current system appearance and language, tracked live so "follow system"
/// theme/language settings react to OS changes at runtime.
class PlatformInfo {
  final Brightness brightness;
  final String languageCode;
  const PlatformInfo(this.brightness, this.languageCode);
}

class PlatformController extends StateNotifier<PlatformInfo>
    with WidgetsBindingObserver {
  PlatformController() : super(_read()) {
    WidgetsBinding.instance.addObserver(this);
  }

  static PlatformInfo _read() {
    final d = WidgetsBinding.instance.platformDispatcher;
    return PlatformInfo(d.platformBrightness, d.locale.languageCode);
  }

  @override
  void didChangePlatformBrightness() => state = _read();

  @override
  void didChangeLocales(List<Locale>? locales) => state = _read();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final platformProvider =
    StateNotifierProvider<PlatformController, PlatformInfo>((ref) => PlatformController());
