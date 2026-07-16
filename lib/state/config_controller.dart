import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/engine_repository.dart';
import '../models/models.dart';
import 'connection_controller.dart';

class ConfigDraftState {
  final String tab; // 'charger' | 'battery'
  final Map<String, ProfileConfig> draft;
  final String? error;
  const ConfigDraftState({required this.tab, required this.draft, this.error});

  ProfileConfig get current => draft[tab]!;

  ConfigDraftState copyWith({String? tab, Map<String, ProfileConfig>? draft, Object? error = _s}) =>
      ConfigDraftState(
        tab: tab ?? this.tab,
        draft: draft ?? this.draft,
        error: error == _s ? this.error : error as String?,
      );

  static const Object _s = Object();
}

/// Holds the editable configuration draft. Compares against the engine's
/// saved config to drive the Apply/Revert enabled state, and surfaces
/// engine-side validation errors inline.
class ConfigController extends StateNotifier<ConfigDraftState> {
  final EngineRepository? _repo;

  ConfigController(this._repo, EngineSnapshot? initial)
      : super(ConfigDraftState(
          tab: 'charger',
          draft: {
            'charger': initial?.config['charger'] ?? _empty,
            'battery': initial?.config['battery'] ?? _empty,
          },
        ));

  static const ProfileConfig _empty = ProfileConfig(
    governor: 'performance',
    epp: 'balance_performance',
    epb: '6',
    platformProfile: 'balanced',
    turboMode: 'auto',
    minFreq: 800,
    maxFreq: 4200,
    ignoreList: [],
  );

  ProfileConfig savedFor(String tab) => _repo?.snapshot.config[tab] ?? _empty;

  bool get isDirty => !state.current.equals(savedFor(state.tab));

  void setTab(String tab) => state = state.copyWith(tab: tab, error: null);

  void _update(ProfileConfig Function(ProfileConfig) fn) {
    final next = fn(state.current);
    state = state.copyWith(draft: {...state.draft, state.tab: next});
  }

  void setGovernor(String v) => _update((c) => c.copyWith(governor: v));
  void setEpp(String v) => _update((c) => c.copyWith(epp: v));
  void setEpb(String v) => _update((c) => c.copyWith(epb: v));
  void setPlatform(String v) => _update((c) => c.copyWith(platformProfile: v));
  void setTurboMode(String v) => _update((c) => c.copyWith(turboMode: v));
  void setMinFreq(int v) => _update((c) => c.copyWith(minFreq: v));
  void setMaxFreq(int v) => _update((c) => c.copyWith(maxFreq: v));

  void addIgnore(String name) {
    final v = name.trim();
    if (v.isEmpty) return;
    _update((c) => c.copyWith(ignoreList: [...c.ignoreList, v]));
  }

  void removeIgnore(String name) {
    _update((c) => c.copyWith(ignoreList: c.ignoreList.where((x) => x != name).toList()));
  }

  Future<void> apply() async {
    final tab = state.tab;
    try {
      await _repo?.applyConfig(tab, state.current);
      state = state.copyWith(error: null);
    } on ConfigValidationError catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  void revert() {
    state = state.copyWith(
      draft: {...state.draft, state.tab: savedFor(state.tab)},
      error: null,
    );
  }
}

final configControllerProvider =
    StateNotifierProvider.autoDispose<ConfigController, ConfigDraftState>((ref) {
  final repo = ref.watch(engineRepositoryProvider);
  return ConfigController(repo, repo?.snapshot);
});
