import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../state/settings_controller.dart';

/// Remote devices the user has successfully connected to, persisted so they
/// reappear (with their pinned certificate) without re-pairing.
class SavedDevicesController extends StateNotifier<List<Device>> {
  SavedDevicesController(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;
  static const _key = 'devices.saved';

  static List<Device> _load(SharedPreferences p) {
    final raw = p.getString(_key);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Device.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Adds or updates a device keyed by host:port.
  void remember(Device device) {
    final next = [
      device,
      for (final d in state)
        if (d.host != device.host || d.port != device.port) d,
    ];
    _set(next);
  }

  void forget(String id) => _set([
        for (final d in state)
          if (d.id != id) d,
      ]);

  void _set(List<Device> next) {
    state = next;
    _prefs.setString(_key, jsonEncode(next.map((d) => d.toJson()).toList()));
  }
}

final savedDevicesProvider =
    StateNotifierProvider<SavedDevicesController, List<Device>>(
        (ref) => SavedDevicesController(ref.watch(sharedPreferencesProvider)));
