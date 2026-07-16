import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/engine_repository.dart';
import '../models/models.dart';
import '../state/config_controller.dart';
import '../state/connection_controller.dart';
import '../state/settings_controller.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/common.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  final _ignoreCtrl = TextEditingController();

  @override
  void dispose() {
    _ignoreCtrl.dispose();
    super.dispose();
  }

  List<String> _withCurrent(List<String> choices, String current) =>
      choices.contains(current) ? choices : [current, ...choices];

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(paletteProvider);
    final s = ref.watch(stringsProvider);
    final snap = ref.watch(engineControllerProvider);
    final draftState = ref.watch(configControllerProvider);
    final ctrl = ref.read(configControllerProvider.notifier);
    final repo = ref.watch(engineRepositoryProvider);
    final canWrite = ref.watch(connectionProvider.select((c) => c.permissions.canWrite('config')));

    if (snap == null) return const SizedBox.shrink();
    final cfg = draftState.current;
    final dirty = ctrl.isDirty;
    final editable = canWrite;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: SegmentedControl<String>(
                  p: p,
                  expand: false,
                  itemPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  selected: draftState.tab,
                  onChanged: (v) => ctrl.setTab(v),
                  options: [
                    SegmentOption('charger', s.t('tabCharger')),
                    SegmentOption('battery', s.t('tabBattery')),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (!editable) ...[
                LockNote(p, s.t('configReadOnlyNote')),
                const SizedBox(height: 18),
              ],
              if (draftState.error != null) ...[
                _errorBanner(p, draftState.error!),
                const SizedBox(height: 18),
              ],
              Opacity(
                opacity: editable ? 1 : 0.5,
                child: IgnorePointer(
                  ignoring: !editable,
                  child: _configCard(p, s, cfg, ctrl, snap.freqLimits),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  PrimaryButton(
                    p: p,
                    label: s.t('apply'),
                    onPressed: (dirty && editable) ? () => ctrl.apply() : null,
                  ),
                  const SizedBox(width: 10),
                  GhostButton(
                    p: p,
                    label: s.t('revert'),
                    onPressed: (dirty && editable) ? () => ctrl.revert() : null,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _bluetoothCard(p, s, snap.bluetoothBoot, repo, editable),
            ],
          ),
        ),
      ),
    );
  }

  Widget _configCard(Palette p, dynamic s, ProfileConfig cfg, ConfigController ctrl,
      FrequencyLimits limits) {
    Widget field(String label, Widget child) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppFonts.sans(size: 12, weight: FontWeight.w600, color: p.textDim)),
            const SizedBox(height: 6),
            child,
          ],
        );

    final selects = <Widget>[
      field(s.t('governor'),
          AppDropdown<String>(p: p, value: cfg.governor, items: _withCurrent(EngineChoices.governors, cfg.governor), onChanged: (v) => ctrl.setGovernor(v!))),
      field(s.t('epp'),
          AppDropdown<String>(p: p, value: cfg.epp, items: _withCurrent(EngineChoices.epp, cfg.epp), onChanged: (v) => ctrl.setEpp(v!))),
      field(s.t('epb'),
          AppDropdown<String>(p: p, value: cfg.epb, items: _withCurrent(EngineChoices.epb, cfg.epb), onChanged: (v) => ctrl.setEpb(v!))),
      field(s.t('platformProfile'),
          AppDropdown<String>(p: p, value: cfg.platformProfile, items: _withCurrent(EngineChoices.platform, cfg.platformProfile), onChanged: (v) => ctrl.setPlatform(v!))),
      field(s.t('turboMode'),
          AppDropdown<String>(p: p, value: cfg.turboMode, items: _withCurrent(EngineChoices.turboMode, cfg.turboMode), onChanged: (v) => ctrl.setTurboMode(v!))),
    ];

    return AppCard(
      p: p,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      radius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 520 ? 3 : 2;
            final gap = 14.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: 14,
              children: selects.map((e) => SizedBox(width: w, child: e)).toList(),
            );
          }),
          const SizedBox(height: 16),
          _freqRange(p, s, cfg, ctrl, limits),
          const SizedBox(height: 16),
          _ignoreList(p, s, cfg, ctrl),
        ],
      ),
    );
  }

  Widget _freqRange(Palette p, dynamic s, ProfileConfig cfg, ConfigController ctrl,
      FrequencyLimits limits) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(s.t('freqRange'),
                  style: AppFonts.sans(size: 12, weight: FontWeight.w600, color: p.textDim)),
            ),
            Text('${cfg.minFreq} – ${cfg.maxFreq} MHz',
                style: AppFonts.mono(size: 12.5, weight: FontWeight.w700, color: p.text)),
          ],
        ),
        RangeSlider(
          min: limits.min.toDouble(),
          max: limits.max.toDouble(),
          divisions: ((limits.max - limits.min) / 100).round(),
          activeColor: p.accent,
          inactiveColor: p.hover,
          values: RangeValues(
            cfg.minFreq.toDouble().clamp(limits.min.toDouble(), limits.max.toDouble()),
            cfg.maxFreq.toDouble().clamp(limits.min.toDouble(), limits.max.toDouble()),
          ),
          labels: RangeLabels('${cfg.minFreq}', '${cfg.maxFreq}'),
          onChanged: (v) {
            ctrl.setMinFreq(v.start.round());
            ctrl.setMaxFreq(v.end.round());
          },
        ),
        Row(
          children: [
            Expanded(child: Text('${limits.min} MHz', style: AppFonts.mono(size: 11, color: p.textFaint))),
            Text('${limits.max} MHz', style: AppFonts.mono(size: 11, color: p.textFaint)),
          ],
        ),
      ],
    );
  }

  Widget _ignoreList(Palette p, dynamic s, ProfileConfig cfg, ConfigController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.t('ignoreList'),
            style: AppFonts.sans(size: 12, weight: FontWeight.w600, color: p.textDim)),
        const SizedBox(height: 10),
        if (cfg.ignoreList.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cfg.ignoreList
                .map((name) => Container(
                      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                      decoration: BoxDecoration(
                        color: p.surface2,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(name, style: AppFonts.sans(size: 12, weight: FontWeight.w600, color: p.text)),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => ctrl.removeIgnore(name),
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(color: p.hover, shape: BoxShape.circle),
                              child: Icon(Icons.close, size: 12, color: p.textDim),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                p: p,
                controller: _ignoreCtrl,
                hint: s.t('ignorePlaceholder'),
                onChanged: (_) {},
              ),
            ),
            const SizedBox(width: 8),
            GhostButton(
              p: p,
              label: s.t('add'),
              onPressed: () {
                ctrl.addIgnore(_ignoreCtrl.text);
                _ignoreCtrl.clear();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _bluetoothCard(
      Palette p, dynamic s, bool enabled, EngineRepository? repo, bool editable) {
    return AppCard(
      p: p,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      radius: BorderRadius.circular(10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('bluetoothBoot'),
                    style: AppFonts.sans(size: 13.5, weight: FontWeight.w700, color: p.text)),
                const SizedBox(height: 2),
                Text(s.t('bluetoothBootHelp'),
                    style: AppFonts.sans(size: 12, color: p.textDim)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Opacity(
            opacity: editable ? 1 : 0.5,
            child: AppSwitch(
              p: p,
              value: enabled,
              onChanged: editable ? (v) => repo?.setBluetoothBoot(v) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(Palette p, String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: p.dangerSoft,
        border: Border.all(color: p.danger),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(msg, style: AppFonts.sans(size: 12.5, weight: FontWeight.w600, color: p.danger)),
    );
  }
}
